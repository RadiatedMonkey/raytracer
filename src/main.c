#include <stdbool.h>

#define GLFW_INCLUDE_NONE
#include <glfw/glfw3.h>

#include "window.h"
#include "shader.h"

struct buffers {
    GLuint vao, vbo;
};

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

int main(int argc, char** argv)
{
    GLFWwindow* window = windowCreate(800, 600, "Window", true);

    GLuint computeprogram;
    {
        GLuint computeshader = shaderCreate("../shaders/raytracer.glsl", GL_COMPUTE_SHADER);

        computeprogram = shaderCreateProgram(1, &computeshader);
    }

    GLuint quadprogram;
    {
        GLuint vertexshader = shaderCreate("../shaders/vquad.glsl", GL_VERTEX_SHADER);
        GLuint fragmentshader = shaderCreate("../shaders/fquad.glsl", GL_FRAGMENT_SHADER);

        GLuint shaders[] = { vertexshader, fragmentshader };
        quadprogram = shaderCreateProgram(2, shaders);
    }

    int windowWidth, windowHeight;
    glfwGetWindowSize(window, &windowWidth, &windowHeight);

    glUseProgram(quadprogram);

    GLuint screenTexture = createScreenTexture(windowWidth, windowHeight);
    struct buffers bufs = createBuffers();

    while(!glfwWindowShouldClose(window)) {
        {
            glUseProgram(computeprogram);
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
    }

    glDeleteVertexArrays(1, &bufs.vao);
    glDeleteBuffers(1, &bufs.vbo);

    glDeleteProgram(computeprogram);
    glDeleteProgram(quadprogram);

    glfwDestroyWindow(window);
    windowFreeResources(window);

    return 0;
}