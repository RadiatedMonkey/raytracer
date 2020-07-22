#version 430 core

#define WIDTH 800.0
#define HEIGHT 600.0
#define fov 90

layout(local_size_x = 1, local_size_y = 1) in;
layout(rgba32f, binding = 0) uniform image2D screen;



void main()
{
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    vec4 pixel;

    float r = float(coords.x) / (WIDTH - 1.0);
    float g = float(coords.y) / (HEIGHT - 1.0);
    float b = 0.25;

    pixel = vec4(r, g, b, 1.0);

    imageStore(screen, coords, pixel);
}