#include "shader.h"

#include <stdio.h>
#include <stdlib.h>

// Returns null-terminated string
inline char* fileRead(const char* path)
{
    FILE* f;
    errno_t err = fopen_s(&f, path, "r");

    if(!f) {
        fprintf(stderr, "Failed to read file %s: code %i\n", path, err);
        return 0;
    }

    fseek(f, 0, SEEK_END);
    size_t filesize = (size_t)ftell(f);
    rewind(f);

    char* buffer = (char*)calloc(1, filesize + 1);
    if(!buffer) {
        fprintf(stderr, "Failed to allocate buffer for file contents\n");
        fclose(f);
        return 0;
    }

    fread_s(buffer, filesize, filesize, 1, f);
    fclose(f);

    return buffer;
}

GLuint shaderCreate(const char* path, GLenum type)
{       
    char* src = fileRead(path);
    if(!src) {
        return 0;
    }

    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, 0);
    glCompileShader(shader);

    free(src);

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if(!status) {
        GLint loglength;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &loglength);

        GLchar* log = (char*)calloc(1, loglength + 1);
        glGetShaderInfoLog(shader, loglength, 0, log);

        fprintf(stderr, "ERROR: %s\n", log);

        free(log);
        glDeleteShader(shader);
        return 0;
    }

    return shader;
}

GLuint shaderCreateProgram(char shaderCount, GLuint* shaders)
{
    GLuint program = glCreateProgram();
    for(char i = 0; i < shaderCount; i++) {
        glAttachShader(program, shaders[i]);
    }
    glLinkProgram(program);

    for(char i = 0; i < shaderCount; i++) {
        glDeleteShader(shaders[i]);
    }

    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if(!status) {
        GLint loglength;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &loglength);

        GLchar* log = (char*)calloc(1, loglength + 1);
        glGetProgramInfoLog(program, loglength, 0, log);

        fprintf(stderr, "%s\n", log);

        free(log);
        glDeleteProgram(program);
        return 0;
    }

    return program;
}