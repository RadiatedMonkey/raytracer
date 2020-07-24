#version 430 core

layout(location = 0) in vec2 position;

out vec2 texcoords;

void main()
{
    gl_Position = vec4(position, 0.0, 1.0);
    texcoords = position;
}