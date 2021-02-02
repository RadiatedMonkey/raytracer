#include <stdio.h>
#include <stdbool.h>

#define GLFW_INCLUDE_NONE
#include <glfw/glfw3.h>

#include "window.h"
#include "shader.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

struct buffers {
    GLuint vao, vbo;
};

static GLint timeloc;
static GLint widthloc;
static GLint heightloc;
static int frame = 0;
static GLuint screenTexture;
static GLuint texture1;
static GLuint texture2;
static GLuint texture3;
static GLuint computeprogram;

static int windowWidth;
static int windowHeight;

static _Bool windowInFocus = 1;

inline GLuint createScreenTexture(int width, int height)
{
    GLuint screenTexture;
    glGenTextures(1, &screenTexture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, screenTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, 0);
    glBindImageTexture(0, screenTexture, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

    return screenTexture;
}

inline GLuint uploadTexture(const char* filename, GLuint textureID) {
    int width, height, nrChannels;
    unsigned char* data = stbi_load(filename, &width, &height, &nrChannels, 0);
    if(data == NULL) {
        fprintf(stderr, "Failed to load %s\n", filename);
        return 0;
    }

    GLuint texture;
    glGenTextures(1, &texture);
    glActiveTexture(textureID);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data);

    stbi_image_free(data);
    return texture;
}

inline struct buffers createBuffers()
{
    static const GLfloat QUAD_VERTICES[] = {
        +1.0, +1.0, // Top right
        -1.0, +1.0, // Top left
        -1.0, -1.0, // Bottom left

        -1.0, -1.0, // Bottom left
        +1.0, -1.0, // Bottom right
        +1.0, +1.0, // Top right
    };

    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(QUAD_VERTICES), QUAD_VERTICES, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 2, 0);

    struct buffers buf = { vao, vbo };
    return buf;
}

inline void createComputeProgram()
{
    GLuint computeshader = shaderCreate("../../shaders/raytracer.glsl", GL_COMPUTE_SHADER);
    computeprogram = shaderCreateProgram(1, &computeshader);

    timeloc = glGetUniformLocation(computeprogram, "utime");
    widthloc = glGetUniformLocation(computeprogram, "uwidth");
    heightloc = glGetUniformLocation(computeprogram, "uheight");

    glUseProgram(computeprogram);
    glUniform1f(widthloc, (GLfloat)windowWidth);
    glUniform1f(heightloc, (GLfloat)windowHeight);
}

void resizeCallback(GLFWwindow* window, int width, int height)
{
    glViewport(0, 0, width, height);
    glUseProgram(computeprogram);
    glUniform1f(widthloc, (GLfloat)width);
    glUniform1f(heightloc, (GLfloat)height);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, 0);

    windowWidth = width;
    windowHeight = height;
}

void focusCallback(GLFWwindow* window, int focused)
{
    windowInFocus = focused;
}

void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if(key == GLFW_KEY_R && action == GLFW_PRESS) {
        printf("refresh\n");

        glDeleteProgram(computeprogram);
        createComputeProgram();
        frame = 0;
    }
}

int main(void)
{
    GLFWwindow* window = windowCreate(500, 500, "Window", true);

    glfwSetFramebufferSizeCallback(window, resizeCallback);
    glfwSetWindowFocusCallback(window, focusCallback);
    glfwSetKeyCallback(window, keyCallback);
    glfwGetWindowSize(window, &windowWidth, &windowHeight);
    glfwSwapInterval(1);

    createComputeProgram();
    texture1 = uploadTexture("../../textures/texture1.jpg", GL_TEXTURE1);
    if(texture1 == 0) {
        glDeleteProgram(computeprogram);
        glfwTerminate();
        return 1;
    }

    texture2 = uploadTexture("../../textures/texture2.jpg", GL_TEXTURE2);
    if(texture2 == 0) {
        glDeleteProgram(computeprogram);
        glDeleteTextures(1, &texture1);
        glfwTerminate();
        return 1;
    }

    texture3 = uploadTexture("../../textures/texture3.jpg", GL_TEXTURE3);
    if(texture3 == 0) {
        glDeleteProgram(computeprogram);
        glDeleteTextures(1, &texture1);
        glDeleteTextures(1, &texture2);
        glfwTerminate();
        return 1;
    }

    GLuint quadprogram;
    {
        GLuint vertexshader = shaderCreate("../../shaders/vquad.glsl", GL_VERTEX_SHADER);
        GLuint fragmentshader = shaderCreate("../../shaders/fquad.glsl", GL_FRAGMENT_SHADER);

        GLuint shaders[] = { vertexshader, fragmentshader };
        quadprogram = shaderCreateProgram(2, shaders);
    }

    screenTexture = createScreenTexture(windowWidth, windowHeight);
    struct buffers bufs = createBuffers();

    GLuint frameloc = glGetUniformLocation(computeprogram, "uframe");
    while(!glfwWindowShouldClose(window)) {
        if(!windowInFocus) {
            glfwPollEvents();
            glfwSwapBuffers(window);
            continue;
        }

        {
            glUseProgram(computeprogram);
            glUniform1f(timeloc, (float)glfwGetTime());
            glUniform1i(frameloc, frame);
            glDispatchCompute((GLuint)windowWidth, (GLuint)windowHeight, 1);
        }

        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        {  
            glClear(GL_COLOR_BUFFER_BIT);
            glUseProgram(quadprogram);
            glBindVertexArray(bufs.vao);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, screenTexture);
            glDrawArrays(GL_TRIANGLES, 0, 6);
        }

        glfwSwapBuffers(window);
        glfwPollEvents();
        frame++;
    }

    glDeleteVertexArrays(1, &bufs.vao);
    glDeleteBuffers(1, &bufs.vbo);

    GLuint textures[] = { screenTexture, texture1, texture2, texture3 };
    glDeleteTextures(4, textures);

    glDeleteProgram(computeprogram);
    glDeleteProgram(quadprogram);

    glfwDestroyWindow(window);
    windowFreeResources(window);

    return 0;
}