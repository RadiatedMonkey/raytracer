#include "window.h"

#include <stdbool.h>

#define GLFW_INCLUDE_NONE
#include <glfw/glfw3.h>

int main(int argc, char** argv)
{
    GLFWwindow* window = windowCreate(800, 600, "Window", true);

    while(!glfwWindowShouldClose(window)) {
        glClear(GL_COLOR_BUFFER_BIT);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    windowFreeResources(window);

    return 0;
}