#version 430 core

layout(rgba32f, binding = 0) uniform image2D screen;

in vec2 texcoords;

out vec4 fragcolor;

void main()
{
    fragcolor = imageLoad(screen, ivec2(gl_FragCoord.xy));
}