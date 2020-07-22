#pragma once

#include <glad/glad.h>

GLuint shaderCreate(const char* path, GLenum type);
GLuint shaderCreateProgram(char shaderCount, GLuint* shaders);