#version 430 core

#define WIDTH 800.0
#define HEIGHT 600.0
#define CAM_LOCATION vec3(0.0, 0.0, sin(utime))
#define FOCAL_LENGTH 1.0

layout(local_size_x = 1, local_size_y = 1) in;
layout(rgba32f, binding = 0) uniform image2D screen;

uniform float utime;

uint hash( uint x ) {
    x += ( x << 10u );
    x ^= ( x >>  6u );
    x += ( x <<  3u );
    x ^= ( x >> 11u );
    x += ( x << 15u );
    return x;
}

uint hash( uvec2 v ) { return hash( v.x ^ hash(v.y)                         ); }
uint hash( uvec3 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z)             ); }
uint hash( uvec4 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w) ); }

// Construct a float with half-open range [0:1] using low 23 bits.
// All zeroes yields 0.0, all ones yields the next smallest representable value below 1.0.
float floatConstruct( uint m ) {
    const uint ieeeMantissa = 0x007FFFFFu; // binary32 mantissa bitmask
    const uint ieeeOne      = 0x3F800000u; // 1.0 in IEEE binary32

    m &= ieeeMantissa;                     // Keep only mantissa bits (fractional part)
    m |= ieeeOne;                          // Add fractional part to 1.0

    float  f = uintBitsToFloat( m );       // Range [1:2]
    return f - 1.0;                        // Range [0:1]
}

// Pseudo-random value in half-open range [0:1].
float random( float x ) { return floatConstruct(hash(floatBitsToUint(x))); }
float random( vec2  v ) { return floatConstruct(hash(floatBitsToUint(v))); }
float random( vec3  v ) { return floatConstruct(hash(floatBitsToUint(v))); }
float random( vec4  v ) { return floatConstruct(hash(floatBitsToUint(v))); }

struct Ray {
    vec3 origin, direction;
};

struct HitRecord {
    vec3 p, normal;
    float t;
    bool frontFace;
    vec3 albedo;
};

struct HitResult {
    bool isHit;
    HitRecord rec;
};

HitRecord SetFaceNormal(HitRecord rec, Ray ray, vec3 outwardNormal)
{
    rec.frontFace = dot(ray.direction, outwardNormal) < 0.0;
    rec.normal = rec.frontFace ? outwardNormal : -outwardNormal;
    return rec;
}

struct Sphere {
    vec3 center;
    float radius;
    vec3 albedo;
};

// Get the point the ray is at at a specific time
vec3 GetRayPointAt(Ray ray, float t)
{   
    return ray.origin + ray.direction * t;
}

float SquareLength(vec3 v)
{
    return v.x * v.x + v.y * v.y + v.z * v.z;
}

vec3 RandomInUnitSphere()
{
    float val = utime;
    while(true) {
        vec3 p = vec3(
            random(vec2(val++, gl_GlobalInvocationID.x)) * 2 - 1,
            random(vec2(val++, gl_GlobalInvocationID.y)) * 2 - 1,
            random(vec2(val++, gl_GlobalInvocationID.z)) * 2 - 1
        );
        if(SquareLength(p) >= 1) continue;
        return p;
    }
}

// float HitSphere(Sphere sphere, Ray ray)
// {
//     vec3 oc = ray.origin - sphere.center;
//     float a = dot(ray.direction, ray.direction);
//     float b = 2.0 * dot(oc, ray.direction);
//     float c = dot(oc, oc) - sphere.radius * sphere.radius;
//     float discriminant = b * b - 4 * a * c;
//     if(discriminant < 0.0) {
//         return -1.0;
//     } else {
//         return (-b - sqrt(discriminant)) / (2.0 * a);
//     }
// }

bool HitSphere(Sphere sphere, Ray ray, float tMin, float tMax, out HitRecord rec_out)
{
    vec3 oc = ray.origin - sphere.center;
    float a = SquareLength(ray.direction);
    float halfB = dot(oc, ray.direction);
    float c = SquareLength(oc) - sphere.radius * sphere.radius;
    float disc = halfB * halfB - a * c;

    HitRecord rec;
    if(disc > 0.0) {
        float root = sqrt(disc);

        float temp = (-halfB - root) / a;
        if(temp < tMax && temp > tMin) {
            rec.t = temp;
            rec.p = GetRayPointAt(ray, temp);
            rec.albedo = sphere.albedo;
            
            vec3 outwardNormal = (rec.p + sphere.center) / sphere.radius;
            rec = SetFaceNormal(rec, ray, outwardNormal);

            rec_out = rec;
            return true;
        }

        temp = (-halfB + root) / a;
        if(temp < tMax && temp > tMin) {
            rec.t = temp;
            rec.p = GetRayPointAt(ray, temp);
            rec.albedo = sphere.albedo;
            
            vec3 outwardNormal = (rec.p + sphere.center) / sphere.radius;
            rec = SetFaceNormal(rec, ray, outwardNormal);

            rec_out = rec;
            return true;
        }
    }

    return false;
}

// HitResult ComputeRayColorInner(Ray ray)
// {
//     const Sphere world[] = Sphere[](
//         Sphere(vec3(0, -11, 0), 10.0),
//         Sphere(vec3(0, 0, -3), 1)
//     );

//     bool hitAnything = false;
//     float closest = 10000.0;
//     HitRecord bestHit;
//     for(int i = 0; i < 2; i++) {
//         HitResult res = HitSphere(world[i], ray, 0.0, closest);
//         if(res.isHit) {
//             closest = res.rec.t;
//             bestHit = res.rec;
//             hitAnything = true;
//         }
//     }
//     if(hitAnything) {
//         // return 0.5 * (bestHit.normal + vec3(1, 1, 1));
//         vec3 target = bestHit.p + bestHit.normal + RandomInUnitSphere();
//         return 0.5 * ComputeRayColorInner(Ray(bestHit.p, target - bestHit.p));
//     }

//     float t = 0.5 * (normalize(ray.direction).y + 1.0);
//     return (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
// }

const Sphere world[] = Sphere[](
    Sphere(vec3(0, -11, 0), 10.0, vec3(0.5, 0.5, 0.5)),
    Sphere(vec3(0, 0, -3), 1, vec3(0.75, 0.25, 0.25)),
    Sphere(vec3(2, 1, -5), 1.5, vec3(0.2, 0.7, 0.7))
);

// vec3 ComputeRayColor(Ray ray, int bounceLimit)
// {
//     Sphere world[] = Sphere[](
//         Sphere(vec3(0, -11, 0), 10.0),
//         Sphere(vec3(0, 0, -3), 1)
//     );

//     // Iterator over all spheres

//     bool hitAnything = false;
//     float closest = 10000.0;
//     HitRecord bestHit;
//     for(int i = 0; i < 2; i++) {
//         HitResult res = HitSphere(world[i], ray, 0.0, closest);
//         if(res.isHit) {
//             closest = res.rec.t;
//             bestHit = res.rec;
//             hitAnything = true;
//         }
//     }

//     if(hitAnything) {
//         return 0.5 * (bestHit.normal + vec3(1, 1, 1));
//     }

//     float t = 0.5 * (normalize(ray.direction).y + 1.0);
//     return (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
// }

bool ComputeRayHit(Ray ray, out HitRecord rec_out)
{
    bool hitAnything = false;
    float closest = 1000.0;

    HitRecord rec;
    for(int i = 0; i < 3; i++) {
        if(HitSphere(world[i], ray, 0.0, closest, rec)) {
            closest = rec.t;
            hitAnything = true;
        }
    }

    if(hitAnything) {
        rec_out = rec;
    }

    return hitAnything;
}

vec3 Radiance(Ray input_ray, int bounceLimit) {
    vec3 final = vec3(1, 1, 1);

    HitRecord rec;
    Ray ray = input_ray;
    for(int i = 0; i < bounceLimit; i++) {
        if(ComputeRayHit(ray, rec)) {
            vec3 target = rec.p + rec.normal - RandomInUnitSphere();
            ray.origin = rec.p;
            ray.direction = target - rec.p;

                        
        } else {
            float t = 0.5 * (normalize(ray.direction).y + 1.0);
            final *= (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
            break;
        }
    }

    return final;
}

vec3 TransformColor(vec3 pxin, int samples)
{
    vec3 pxout;
    float scale = 1.0 / samples;
    pxout.x = pxin.x * scale;
    pxout.y = pxin.y * scale;
    pxout.z = pxin.z * scale;

    pxout.x = clamp(pxout.x, 0.0, 0.999);
    pxout.y = clamp(pxout.y, 0.0, 0.999);
    pxout.z = clamp(pxout.z, 0.0, 0.999);

    return pxout;
}

void main()
{
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    float viewportHeight = 2.0;
    float viewportWidth = float(WIDTH) / float(HEIGHT) * viewportHeight;

    vec3 horizontal = vec3(float(viewportWidth), 0.0, 0.0);
    vec3 vertical = vec3(0.0, float(viewportHeight), 0.0);
    vec3 lowerLeftCorner = CAM_LOCATION - horizontal /  2 - vertical / 2 - vec3(0, 0, FOCAL_LENGTH);

    const int SAMPLES = 5;

    vec3 pixel = vec3(0, 0, 0);
    for(int i = 0; i < SAMPLES; i++) {
        float u = (coords.x + random(vec2(utime, gl_GlobalInvocationID.x)) / 4) / (WIDTH - 1);
        float v = (coords.y + random(vec2(utime, gl_GlobalInvocationID.y)) / 4) / (HEIGHT - 1);

        Ray ray = Ray(CAM_LOCATION, lowerLeftCorner + u * horizontal + v * vertical - CAM_LOCATION);

        pixel += Radiance(ray, 5);
    }

    pixel = TransformColor(pixel, SAMPLES);

    imageStore(screen, coords, vec4(pixel, 1.0));
}