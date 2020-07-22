#pragma once

#include <stdbool.h>

#include <glad/glad.h>
#define GLFW_INCLUDE_NONE
#include <glfw/glfw3.h>

GLFWwindow* windowCreate(int width, int height, const char* title, bool isMain);
void windowFreeResources();