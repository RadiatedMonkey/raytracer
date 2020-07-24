#version 430 core

layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba32f, binding = 0) uniform image2D framebuffer;

#define FOV 90.0
#define WIDTH 800.0
#define HEIGHT 600.0
#define SAMPLES 20
#define DEPTH 20

uniform float utime;

struct Ray {
    vec3 o, d; // Origin, direction
};

struct HitRecord {
    vec3 p, n; // Point, normal, time, front face
    float t;
    bool f;
};

HitRecord SetFaceNormal(HitRecord rc, Ray r, vec3 n)
{
    rc.f = dot(r.d, n) < 0;
    rc.n = rc.f ? n : - n;
    return rc;
}

struct Sphere {
    vec3 c; // Center, radius
    float r;
};

float LengthSquared(vec3 v)
{
    return v.x * v.x + v.y * v.y + v.z * v.z;
}

vec3 RayPointAt(Ray r, float t)
{
    return r.o + r.d * t;
}

uint base_hash(uvec2 p) {
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U * ((p.x) ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

float g_seed = 0;

float hash1(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += 0.1,seed += 0.1)));
    return float(n)/float(0xffffffffU);
}

vec3 hash3(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    uvec3 rz = uvec3(n, n * 16807U, n * 48271U);
    return vec3(rz & uvec3(0x7fffffffU)) / float(0x7fffffff);
}

vec3 RandomInUnitSphere(inout float seed)
{
    vec3 h = hash3(seed) * vec3(2.0, 6.28318530718, 1.0);
    float phi = h.y;
    float r = pow(h.z, 1.0 / 3.0);
    return r * vec3(sqrt(1.0 - h.x * h.x) * vec2(sin(phi), cos(phi)), h.x);
}

bool SphereHit(Sphere s, Ray r, out HitRecord rec, float tMin, float tMax)
{
    vec3 oc = r.o - s.c;
    float a = LengthSquared(r.d);
    float half_b = dot(oc, r.d);
    float c = LengthSquared(oc) - s.r * s.r;
    float d = half_b * half_b - a * c;

    if(d > 0.0) {
        float root = sqrt(d);
        float tmp = (-half_b - root) / a;

        if(tmp < tMax && tmp > tMin) {
            rec.t = tmp;
            rec.p = RayPointAt(r, tmp);
            
            vec3 n = (rec.p - s.c) / s.r;
            rec = SetFaceNormal(rec, r, n);

            return true;
        }

        tmp = (-half_b + root) / a;
        if(tmp < tMax && tmp > tMin) {
            rec.t = tmp;
            rec.p = RayPointAt(r, tmp);
            
            vec3 n = (rec.p - s.c) / s.r;
            rec = SetFaceNormal(rec, r, n);

            return true;
        }
    }

    return false;
}

vec2 ScaleCoordinates(vec2 c)
{
    float u = (WIDTH / HEIGHT) * (2 * c.x / WIDTH - 1);
    float v = (2 * c.y / HEIGHT - 1);
    return vec2(u, v);
}

Ray GetRay(vec2 uv)
{
    float fovFactor = 1.0 / tan(FOV / 2.0);

    vec3 origin = vec3(0, 0, 0);
    vec3 direction = vec3(uv.x, uv.y, fovFactor);

    return Ray(origin, direction);
}

// Sphere sphere = Sphere(vec3(0, 0, sin(utime) + 3), 1.0);

// vec3 RayColor(Ray ray, int bounces)
// {
//     vec3 col = vec3(1, 1, 1);

//     HitRecord r;
//     for(int i = 1; i < bounces + 1; i++) {
//         if(SphereHit(sphere, ray, r, 0.0, 100.0)) {
//             if(i == bounces) {
//                 col *= vec3(0, 0, 0);
//             } else {
//                 col *= 
//             }
//         } else {
//             float t = 0.5 * (normalize(ray.d).y + 1.0);
//             col *= i * ((1.0 - t) * vec3(1, 1, 1) + t * vec3(0.5, 0.7, 1));
//             break;
//         }
//     }

//     // Sky color
//     return col;
// }

const Sphere spheres[] = Sphere[](
    Sphere(vec3(0, 0, -20), 1),
    Sphere(vec3(0, -1001, 0), 1000.0),
    Sphere(vec3(0, 1, -10), 0.5),
    Sphere(vec3(2, 0, -21), 1),
    Sphere(vec3(3, 1, -20), 1),
    Sphere(vec3(-1, -1, -20), 1),
    Sphere(vec3(2, 1, -20), 1)
);

vec3 RayColor(Ray ray_input, int depth)
{
    // Ray ray = ray_input;
    // vec3 final = vec3(1, 1, 1);

    // HitRecord record;
    // for(int i = 0; i < depth; i++) {
    //     bool hasHitAnything = false;
    //     float closest = 1000.0;
    //     for(int i = 0; i < 7; i++) {
    //         if(SphereHit(spheres[i], ray, record, 0.001, closest)) {
    //             closest = record.t;
    //             hasHitAnything = true;
    //         }
    //     }

    //     if(hasHitAnything) {
    //         vec3 attenuation;
    //         Ray scattered;

    //         if(ScatterMaterial(ray, record, attenuation, scattered)) {
    //             final *= attenuation;
    //             ray = scattered;
    //         } else {
    //             return vec3(0);
    //         }
    //     } else {
    //         float t = 0.5 * ray.d.y + 0.5;
    //         final *= mix(vec3(1), vec3(0.5, 0.7, 1.0), t);
    //         return final;
    //     }
    // }

    Ray ray = Ray(ray_input.o, ray_input.d);
    vec3 final = vec3(1, 1, 1);

    while(true) {
        if(depth <= 0) {
            return vec3(0, 0, 0);
        }

        HitRecord record;
        bool hasHitAnything = false;
        float closest = 1000.0;
        for(int i = 0; i < 2; i++) {
            if(SphereHit(spheres[i], ray, record, 0.01, closest)) {
                closest = record.t;
                hasHitAnything = true;
            }
        }

        if(hasHitAnything) {
            vec3 target = record.p + RandomInUnitSphere(g_seed);
            ray = Ray(record.p, target - record.p);
            depth--;
            // final *= 0.5;
        } else {
            float t = 0.5 * (ray.d.y + 1.0);
            final *= (1.0 - t) * vec3(1) + t * vec3(0.5, 0.7, 1.0);
            return final;
        }
    }
}

vec3 TransformColor(vec3 pxin, int samples)
{
    vec3 pxout;
    float scale = 1.0 / samples;
    pxout.x = pxin.x * scale;
    pxout.y = pxin.y * scale;
    pxout.z = pxin.z * scale;

    return pxout;
}

void main()
{   
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    g_seed = float(base_hash(floatBitsToUint(coords))) / float(0xffffffffU) + utime;

    vec3 pixel = vec3(1, 1, 1);

    const vec3 ORIGIN = vec3(0, 0, 0);
    const float FOCAL_LENGTH = 10;

    float viewportHeight = 2.0;
    float viewportWidth = float(WIDTH) / float(HEIGHT) * viewportHeight;

    vec3 horizontal = vec3(viewportWidth, 0.0, 0.0);
    vec3 vertical = vec3(0.0, viewportHeight, 0.0);
    vec3 lowerLeftCorner = ORIGIN - horizontal / 2 - vertical / 2 - vec3(0, 0, FOCAL_LENGTH);

    for(int i = 0; i < SAMPLES; i++) {
        float u = (coords.x + hash1(g_seed)) / (WIDTH - 1);
        float v = (coords.y + hash1(g_seed)) / (HEIGHT - 1);

        // Ray ray = GetRay(ScaleCoordinates(vec2(u, v)));
        // pixel += RayColor(ray, DEPTH);
        Ray ray = Ray(ORIGIN, lowerLeftCorner + u * horizontal + v * vertical - ORIGIN);
        pixel += RayColor(ray, DEPTH);
    }

    // Ray ray = GetRay(ScaleCoordinates(coords));
    // pixel = RayColor(ray, DEPTH);
    pixel = TransformColor(pixel, SAMPLES);

    imageStore(framebuffer, coords, vec4(pixel, 1.0));
}