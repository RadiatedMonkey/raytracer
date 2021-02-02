#version 430 core

layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba32f, binding = 0) uniform image2D framebuffer;

uniform float utime;
uniform int uframe;
uniform float uwidth;
uniform float uheight;

#define PI 3.1415926

#define MATERIAL_BLINN 0
#define MATERIAL_METAL 1
#define MATERIAL_ORENNAYAR 2
#define MATERIAL_PHONG 3

float RandomSeed = 0.0f;

struct Ray {
    vec3 origin, direction;
};

struct Camera {
    vec3 origin, lower_left_corner, horizontal, vertical;
};

struct Material {
    vec3 diffuse, specular, emission;
    uint type;
    float roughness, ior;
};

Material materials[] = Material[](
    Material(vec3(0.59), vec3(0.1), vec3(0), MATERIAL_METAL, 0.5, 1.5)
);

uint BaseHash(uvec2 p) {
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U * ((p.x) ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

float Hash1d(inout float seed) {
    uint n = BaseHash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    return float(n) / float(0xffffffffU);
}

vec2 Hash2d(inout float seed) {
    uint n = BaseHash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    uvec2 rz = uvec2(n, n * 48271U);
    return vec2(rz.xy & uvec2(0x7fffffffU)) / float(0x7fffffff);
}

vec3 Hash3d(inout float seed) {
    uint n = BaseHash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    uvec3 rz = uvec3(n, n * 16807U, n * 48271U);
    return vec3(rz & uvec3(0x7fffffffU)) / float(0x7fffffff);
}

Camera NewCamera(
    vec3 lookfrom, vec3 lookat, vec3 vup,  float vfov, float aspect_ratio
) {
    Camera c;

    float theta = vfov * PI / 180.;
    float h = tan(theta / 2.);
    float viewport_height = 2. * h;
    float viewport_width = aspect_ratio * viewport_height;

    vec3 w = normalize(lookfrom - lookat);
    vec3 u = normalize(cross(vup, w));
    vec3 v = cross(w, u);

    c.origin = lookfrom;
    c.horizontal = viewport_width * u;
    c.vertical = viewport_height * v;
    c.lower_left_corner = c.origin - c.horizontal / 2. - c.vertical / 2. - w;

    return c;
}

Ray GetRay(Camera c, vec2 uv) {
    return Ray(
        c.origin, c.lower_left_corner + uv.x * c.horizontal + uv.y * c.vertical - c.origin
    );
}

void GammaCorrect(inout vec4 px, uint samples) {
    float scale = 1.0 / samples;
    px.x = sqrt(clamp(scale * px.x, 0, 1));
    px.y = sqrt(clamp(scale * px.y, 0, 1));
    px.z = sqrt(clamp(scale * px.z, 0, 1));
}

vec3 Radiance(Ray rayIn, Scene scene, uint depth) {
    vec3 radiance = vec3(0);
    vec3 beta = vec3(1);

    Ray ray = rayIn;
    for(uint i = 0; i < depth; i++) {
        IntersectData intersect = Intersect(ray, scene);

        if(!intersect.hit) {
            vec3 value = beta * SampleSky(ray.direction);
            radiance += value;
            break;
        }

        uint material = scene.objects[intersect.objectIndex].materialIndex;
        radiance += beta * scene.materials[material].emission * 50.0f;

        vec3 wi;
        vec3 wo = -ray.direction;
        float pdf = 0.0f;

        vec3 f = SampleBrdf(wo, wi, pfd, intersect.textureCoordinate, intersect.normal, material);
        if(pfd <= 0.0f) break;

        vec3 mul = f * dot(wi, intersect.normal) / pfd;
        beta *= mul;

        ray = GetRay(intersect.position + wi * 0.01f, wi);
    }

    return radiance;
}

void main() {
    const uint SAMPLES = 15, DEPTH = 100;

    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    RandomSeed = float(BaseHash(floatBitsToUint(vec2(coords)))) / float(0xffffffffU) + utime;

    vec3 lookfrom = vec3(273, 273, -800);
    vec3 lookat = vec3(273, 273, 273);

    Camera camera = NewCamera(
        lookfrom, lookat, vec3(0, 1, 0), 40, uwidth / uheight
    );

    vec3 radiance;
    for(int i = 0; i < SAMPLES; i++) {
        vec2 uv = (coords + Hash2d(RandomSeed)) / vec2(uwidth, uheight);
        Ray r = GetRay(camera, uv);
        radiance += vec3(
            Radiance(r, DEPTH)
        );
    }

    vec4 final = vec4(radiance, 1.0);
    GammaCorrect(final, SAMPLES);

    final = final * 0.1 + imageLoad(framebuffer, coords) * 0.9;

    imageStore(framebuffer, coords, final);
}