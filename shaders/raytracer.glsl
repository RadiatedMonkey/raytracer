#version 430 core

layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba32f, binding = 0) uniform image2D framebuffer;

uniform float utime;

#define WIDTH 800.0
#define HEIGHT 600.0
#define FOV 90.0

struct Ray {
    vec3 o, d;
};

struct HitRecord {
    vec3 p, n;
    float t;
    bool frontFace;
};

HitRecord set_face_normal(HitRecord rc, Ray r, vec3 n)
{
    rc.frontFace = dot(r.d, n) < 0;
    rc.n = rc.frontFace ? n : -n;
    return rc;
}

struct Sphere {
    vec3 c;
    float r;
};

float length_squared(vec3 v)
{
    return v.x*v.x+v.y*v.y+v.z*v.z;
}

uint base_hash(uvec2 p) {
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    return h32^(h32 >> 16);
}

float g_seed = 0.;

float hash1(inout float seed) {
    uint n = base_hash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    return float(n)/float(0xffffffffU);
}

vec2 hash2(inout float seed) {
    uint n = base_hash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    uvec2 rz = uvec2(n, n*48271U);
    return vec2(rz.xy & uvec2(0x7fffffffU))/float(0x7fffffff);
}

vec3 hash3(inout float seed) {
    uint n = base_hash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    uvec3 rz = uvec3(n, n*16807U, n*48271U);
    return vec3(rz & uvec3(0x7fffffffU))/float(0x7fffffff);
}

vec3 random_in_unit_sphere(inout float seed) {
    vec3 h = hash3(seed) * vec3(2.,6.28318530718,1.)-vec3(1,0,0);
    float phi = h.y;
    float r = pow(h.z, 1./3.);
	return r * vec3(sqrt(1.-h.x*h.x)*vec2(sin(phi),cos(phi)),h.x);
}

bool hit_sphere(Sphere s, Ray r, float tMin, float tMax, out HitRecord rec)
{
    vec3 oc = r.o - s.c;
    float a = length_squared(r.d);
    float halfB = dot(oc, r.d);
    float c = length_squared(oc) - s.r * s.r;
    float d = halfB * halfB - a * c;

    if(d > 0.) {
        float root = sqrt(d);

        float tmp = (-halfB - root) / a;
        if(tmp < tMax && tmp > tMin) {
            rec.t = tmp;
            rec.p = r.o + r.d * tmp;

            vec3 n = (rec.p - s.c) / s.r;
            rec = set_face_normal(rec, r, n);

            return true;
        }

        tmp = (-halfB + root) / a;
        if(tmp < tMax && tmp > tMin) {
            rec.t = tmp;
            rec.p = r.o + r.d * tmp;
            
            vec3 n = (rec.p - s.c) / s.r;
            rec = set_face_normal(rec, r, n);

            return true;
        }
    }

    return false;
}

Sphere spheres[] = Sphere[](
    Sphere(vec3(0, sin(utime), 2), sin(utime)),
    Sphere(vec3(0, -1001, 0), 1000)
);

bool hit_scene(Ray r, out HitRecord rc) {
    bool hitAnything = false;
    float closest = 10000.0;

    for(int i = 0; i < 2; i++) {
        if(hit_sphere(spheres[i], r, 0.01, closest, rc)) {
            hitAnything = true;
            closest = rc.t;
        }
    }

    return hitAnything;
}

vec3 ray_color(Ray r_in, int depth)
{
    vec3 final = vec3(1);
    Ray r = r_in;

    while(true) {
        HitRecord rc;
        if(depth <= 0) {
            return vec3(0);
        }
        if(hit_scene(r, rc)) {
            vec3 target = rc.p + random_in_unit_sphere(g_seed);
            r = Ray(rc.p, target - rc.p);
            depth--;
            final *= .5;
        } else {
            float t = .5 * (r.d.y + 1.);
            final *= (1. - t) * vec3(1) + t * vec3(.5, .7, 1.);
            return final;
        }
    }

    return final;
}

Ray get_camera_ray(vec2 c)
{
    float u = (WIDTH / HEIGHT) * (2. * c.x / WIDTH - 1);
    float v = (2. * c.y / HEIGHT - 1);

    const float fovFactor = 1. / tan(FOV / 2.);

    return Ray(
        vec3(0), vec3(u, v, fovFactor)
    );
}

vec3 transform_color(vec3 px, int samples)
{
    float scale = 1. / samples;
    px *= sqrt(scale);
    return px;
}

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    g_seed = float(base_hash(floatBitsToUint(vec2(coords))))/float(0xffffffffU)+utime;

    const int DEPTH = 5, SAMPLES = 5;

    vec2 rcoords = vec2(
        coords.x + hash1(g_seed),
        coords.y + hash1(g_seed)
    );
    Ray r = get_camera_ray(rcoords);
    vec4 pixel = vec4(ray_color(r, DEPTH), 1.0);

    for(int i = 0; i < SAMPLES; i++) {
        vec2 ircoords = vec2(
            coords.x + hash1(g_seed),
            coords.y + hash1(g_seed)
        );
        Ray r = get_camera_ray(ircoords);
        pixel += vec4(
            transform_color(ray_color(r, DEPTH), SAMPLES), 5.
        );
    }

    // pixel = (pixel + imageLoad(framebuffer, coords)) / 2.;
    pixel /= SAMPLES;
    pixel = (pixel + imageLoad(framebuffer, coords)) / 2.;

    imageStore(framebuffer, coords, pixel);
}