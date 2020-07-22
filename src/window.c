#include "window.h"

#include <stdio.h>

#define OPENGL_VERSION_MAJOR 4
#define OPENGL_VERSION_MINOR 3

GLFWwindow* windowCreate(int width, int height, const char* title, bool isMain)
{
    if(!glfwInit()) {
        const char* glfwErrDesc;
        int glfwErrCode = glfwGetError(&glfwErrDesc);
        fprintf(stderr, "Failed to initialise GLFW: %i (%s)\n", glfwErrCode, glfwErrDesc);
        return 0;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, OPENGL_VERSION_MAJOR);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, OPENGL_VERSION_MINOR);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);

    GLFWwindow* window = glfwCreateWindow(width, height, title, 0, 0);
    if(!window) {
        const char* glfwErrDesc;
        int glfwErrCode = glfwGetError(&glfwErrDesc);
        fprintf(stderr, "Failed to create window: %i (%s)\n", glfwErrCode, glfwErrDesc);
        return 0;
    }

    glfwMakeContextCurrent(window);

    if(!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        fprintf(stderr, "Failed to initialise OpenGL\n");
        return 0;
    }

    return window;
}

void windowFreeResources() {
    glfwTerminate();
}