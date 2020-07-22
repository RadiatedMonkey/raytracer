#version 430 core

#define WIDTH 800.0
#define HEIGHT 600.0
#define CAM_LOCATION vec3(0.0, 0.0, 0.0)
#define FOCAL_LENGTH 1.0

layout(local_size_x = 1, local_size_y = 1) in;
layout(rgba32f, binding = 0) uniform image2D screen;

struct Ray {
    vec3 origin, direction;
};

struct HitRecord {
    vec3 p, normal;
    float t;
    bool frontFace;
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

HitResult HitSphere(Sphere sphere, Ray ray, float tMin, float tMax)
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
            
            vec3 outwardNormal = (rec.p + sphere.center) / sphere.radius;
            rec = SetFaceNormal(rec, ray, outwardNormal);
            
            return HitResult(true, rec);
        }

        temp = (-halfB + root) / a;
        if(temp < tMax && temp > tMin) {
            rec.t = temp;
            rec.p = GetRayPointAt(ray, temp);
            
            vec3 outwardNormal = (rec.p + sphere.center) / sphere.radius;
            rec = SetFaceNormal(rec, ray, outwardNormal);

            return HitResult(true, rec);
        }
    }

    return HitResult(false, rec);
}

const Sphere world[] = Sphere[](
    Sphere(vec3(0, -11, 0), 10.0),
    Sphere(vec3(0, 0, -3), 1)
);

vec3 ComputeRayColor(Ray ray)
{
    // Iterator over all spheres

    bool hitAnything = false;
    float closest = 10000.0;
    HitRecord bestHit;
    for(int i = 0; i < 2; i++) {
        HitResult res = HitSphere(world[i], ray, 0.0, closest);
        if(res.isHit) {
            closest = res.rec.t;
            bestHit = res.rec;
            hitAnything = true;
        }
    }

    if(hitAnything) {
        return 0.5 * (bestHit.normal + vec3(1, 1, 1));
    }

    float t = 0.5 * (normalize(ray.direction).y + 1.0);
    return (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
}

void main()
{
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    float viewportHeight = 2.0;
    float viewportWidth = float(WIDTH) / float(HEIGHT) * viewportHeight;

    vec3 horizontal = vec3(float(viewportWidth), 0.0, 0.0);
    vec3 vertical = vec3(0.0, float(viewportHeight), 0.0);
    vec3 lowerLeftCorner = CAM_LOCATION - horizontal /  2 - vertical / 2 - vec3(0, 0, FOCAL_LENGTH);

    float u = coords.x / (WIDTH - 1);
    float v = coords.y / (HEIGHT - 1);

    Ray ray = Ray(CAM_LOCATION, lowerLeftCorner + u * horizontal + v * vertical - CAM_LOCATION);
    vec4 pixel = vec4(ComputeRayColor(ray), 1.0);

    imageStore(screen, coords, pixel);
}