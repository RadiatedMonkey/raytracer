#version 430 core
#extension GL_ARB_bindless_texture : enable

layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba32f, binding = 0) uniform image2D framebuffer;

uniform float utime;
uniform int uframe;
uniform float uwidth;
uniform float uheight;

layout(binding = 1) uniform sampler2D texture1;
layout(binding = 2) uniform sampler2D texture2;
layout(binding = 3) uniform sampler2D texture3;

#define FOV 90.0
#define PI 3.1415926

// Materials
#define DIFFUSE 0
#define METAL 1
#define DIELECTRIC 2
#define DIFFUSE_LIGHT 3
#define ISOTROPIC 4

// Textures
#define SOLID_COLOR 0
#define CHECKERED 1
#define IMAGE 2

#define XY 0
#define XZ 1
#define YZ 2

#define SPHERE 0
#define RECT 1

const int DEPTH = 100, SAMPLES = 25;

float atan2(in float y, in float x) {
    bool s = (abs(x) > abs(y));
    return mix(PI / 2.0 - atan(x, y), atan(y, x), s);
}

struct Ray {
    vec3 origin, direction;
};

struct HitRecord {
    vec3 position, normal;
    float t, u, v;
    bool frontFace;
    uint materialIndex;
};

HitRecord SetFaceNormal(HitRecord record, Ray ray, vec3 normal) {
    record.frontFace = dot(ray.direction, normal) < 0;
    record.normal = record.frontFace ? normal : -normal;
    return record;
}

struct Texture {
    uint type; // Texture type
    vec3 albedo; // Color for normal textures

    uint property1; // Texture for odd blocks when checkered or image when image texture
    uint property2; // Texture for even blocks when checkered
};

struct Material {
    uint type;
    uint texture;
    float property;
};

struct Sphere {
    vec3 center;
    float radius;
    uint materialIndex;
};

struct Rect {
    uint plane; // The plane this rectangle is put on (XY, XZ or YZ)
    float x0, x1, y0, y1, k;
    uint materialIndex;
};

struct Camera {
    vec3 origin, lower_left_corner, horizontal, vertical;
};

sampler2D images[] = sampler2D[](
    texture1,
    texture2,
    texture3
);

#if 0

Texture textures[] = Texture[](
    Texture(CHECKERED, vec3(1), 1, 2),
    Texture(SOLID_COLOR, vec3(1.0, 0.75, 0.75), 0, 0),
    Texture(SOLID_COLOR, vec3(0.5, 0.5, 0.75), 0, 0),
    Texture(IMAGE, vec3(1), 0, 0),
    Texture(IMAGE, vec3(1), 1, 0)
);

Material materials[] = Material[](
    Material(DIELECTRIC, 1, 1.5),
    Material(DIFFUSE, 3, 0.0),
    Material(DIFFUSE_LIGHT, 1, 0.25),
    Material(DIFFUSE, 0, 0),
    Material(DIFFUSE_LIGHT, 2, 0),
    Material(METAL, 1, 0.25),
    Material(DIFFUSE, 4, 0),
    Material(DIFFUSE, 1, 0)
);

Sphere spheres[] = Sphere[](
    Sphere(vec3(0, 0, -3), 1, 6),
    Sphere(vec3(3, 0, -4), 1, 1),
    Sphere(vec3(-2, 0, -4), 1, 0),
    Sphere(vec3(2, 0, -2), 1, 5),
    Sphere(vec3(-1.5, 0, -6), 1, 5),
    Sphere(vec3(3, 0, -6), 1, 0),
    Sphere(vec3(-1, 0, -1), 1, 7),
    Sphere(vec3(0.5, 0, -5), 1, 7),
    Sphere(vec3(0, -1001, -3), 1000, 5)
);

Rect rects[] = Rect[](
    Rect(XY, -7, 7, -20, 20, 3, 2),
    Rect(XY, -7, 7, -20, 20, -11, 4)
);

#endif

#if 0

Texture textures[] = Texture[](
    Texture(IMAGE, vec3(1, 1, 1), 1, 0),
    Texture(CHECKERED, vec3(0), 2, 3),
    Texture(SOLID_COLOR, vec3(0.9), 0, 0),
    Texture(SOLID_COLOR, vec3(0), 0, 0),
    Texture(IMAGE, vec3(1, 0, 0), 0, 0),

    Texture(SOLID_COLOR, vec3(0.73), 0, 0),
    Texture(SOLID_COLOR, vec3(0.73, 0.5, 0.5), 0, 0),
    Texture(SOLID_COLOR, vec3(1), 0, 0)
);

Material materials[] = Material[](
    Material(DIFFUSE_LIGHT, 7, 0), // Emission
    Material(DIFFUSE, 1, 0), // Ground
    Material(DIELECTRIC, 0, 1.5), // Scene object 1
    Material(METAL, 0, 0), // Scene object 2
    Material(DIFFUSE, 0, 0), // Scene object 3
    Material(DIFFUSE, 5, 0),
    Material(DIFFUSE, 6, 0)
);

Sphere spheres[] = Sphere[](
    Sphere(vec3(0, -1001, 0), 1000, 1), // Ground
    Sphere(vec3(0, 0, 0), 1, 2), // Scene object 1
    Sphere(vec3(-2, 0, 0), 1, 4), // Scene object 2
    Sphere(vec3(2, 0, 0), 1, 3) // Scene object 3
);

Rect rects[] = Rect[](
    Rect(XY, -7, 7, 0, 10, 5, 0), // Light 1
    Rect(XY, -7, 7, -1, 10, -3, 5),
    Rect(YZ, -7, 7, -10, 10, -5, 6)
);

#endif

// Cornell's box
#if 1

Texture textures[] = Texture[](
    Texture(SOLID_COLOR, vec3(0.65, 0.05, 0.05), 0, 0), // Red
    Texture(SOLID_COLOR, vec3(0.12, 0.45, 0.15), 0, 0), // Green
    Texture(SOLID_COLOR, vec3(0.73), 0, 0), // White
    Texture(IMAGE, vec3(1), 2, 0)
);

Material materials[] = Material[](
    Material(DIFFUSE, 0, 0), // Red wall
    Material(DIFFUSE, 1, 0), // Green wall
    Material(DIFFUSE, 2, 0), // White wall
    Material(DIFFUSE_LIGHT, 3, 0), // Light
    Material(DIFFUSE, 4, 0),
    Material(DIELECTRIC, 2, 1.5),
    Material(METAL, 2, 0.25)
);

Sphere spheres[] = Sphere[](
    Sphere(vec3(215, 215, 130), 50, 5),
    Sphere(vec3(400, 50, 100), 50, 6)
);

Rect rects[] = Rect[](
    Rect(YZ, 0, 555, 0, 555, 555, 1),
    Rect(YZ, 0, 555, 0, 555, 0, 3),
    Rect(XZ, 0, 555, 0, 555, 555, 2),
    Rect(XZ, 0, 555, 0, 555, 0, 2),
    Rect(XY, 0, 555, 0, 555, 555, 1),

    // Box 1
    Rect(XY, 130, 295, 0, 165, 230, 2),
    Rect(XY, 130, 295, 0, 165, 65, 2),

    Rect(XZ, 130, 295, 65, 230, 165, 2),
    Rect(XZ, 130, 295, 65, 230, 0, 2),

    Rect(YZ, 0, 165, 65, 230, 295, 2),
    Rect(YZ, 0, 165, 65, 230, 130, 2),

    // Box 2
    Rect(XY, 265, 430, 0, 555, 460, 2),
    Rect(XY, 265, 430, 0, 555, 295, 2),

    Rect(XZ, 265, 430, 295, 460, 555, 2),
    Rect(XZ, 265, 430, 295, 460, 0, 2),

    Rect(YZ, 0, 555, 295, 460, 430, 2),
    Rect(YZ, 0, 555, 295, 460, 265, 2)
);

#endif

void GetSphereUV(in vec3 position, inout HitRecord record) {
    record.u = 0.5 - atan(-position.z, position.x) / (2 * PI);
    record.v = 0.5 - asin(-position.y) / PI;
}

vec3 GetTextureColor(in Texture texture, in float u, in float v, in vec3 position) {
    if(texture.type == SOLID_COLOR) {
        return texture.albedo;
    } else if(texture.type == CHECKERED) {
        float sines = sin(10 * position.x) * sin(10 * position.y) * sin(10 * position.z);
        if (sines < 0) {
            if (textures[texture.property1].type == SOLID_COLOR) {
                return textures[texture.property1].albedo;
            } else if(textures[texture.property1].type == IMAGE) {
                u = 1.0 - clamp(u, 0, 1);
                v = 1.0 - clamp(v, 0, 1);

                return texture2D(images[textures[texture.property1].property1], vec2(u, v)).xyz * textures[texture.property1].albedo;
            } else {
                return vec3(0);
            }
        } else {
            if (textures[texture.property2].type == SOLID_COLOR) {
                return textures[texture.property2].albedo;
            } else if(textures[texture.property2].type == IMAGE) {
                u = 1.0 - clamp(u, 0, 1);
                v = 1.0 - clamp(v, 0, 1);

                return texture2D(images[textures[texture.property2].property1], vec2(u, v)).xyz * textures[texture.property2].albedo;
            } else {
                return vec3(0, 1, 0);
            }
        }
    } else if(texture.type == IMAGE) {
        u = 1.0 - clamp(u, 0, 1);
        v = 1.0 - clamp(v, 0, 1);

        return texture2D(images[texture.property1], vec2(u, v)).xyz;
   } else {
        return vec3(0);
    }
}

float LengthSquared(vec3 v) {
    return v.x * v.x + v.y * v.y + v.z * v.z;
}

uint BaseHash(uvec2 p) {
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U * ((p.x) ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

float RandomSeed = 0.0;

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

vec3 RandomInUnitSphere(inout float seed) {
    vec3 h = Hash3d(seed) * vec3(2.0, 6.28318530718, 1.0) - vec3(1,0,0);
    float phi = h.y;
    float r = pow(h.z, 1.0 / 3.0);
	return r * vec3(sqrt(1.0 - h.x * h.x) * vec2(sin(phi), cos(phi)), h.x);
}

vec3 RandomUnitVector(inout float seed) {
    float a = Hash1d(seed) * 2 * PI;
    float z = Hash1d(seed) * 2 - 1;
    float r = sqrt(1 - z * z);
    return vec3(r * cos(a), r * sin(a), z);
}

bool NearZero(in vec3 point) {
    const float s = 1e-8;
    return (abs(point.x) < s) && (abs(point.y) < s) && (abs(point.z) < s);
}

bool HitSphere(Sphere sphere, Ray ray, float tmin, float tmax, out HitRecord record) {
    vec3 oc = ray.origin - sphere.center;
    float a = LengthSquared(ray.direction);
    float halfB = dot(oc, ray.direction);
    float c = LengthSquared(oc) - sphere.radius * sphere.radius;
    float d = halfB * halfB - a * c;

    if(d > 0.0f) {
        float root = sqrt(d);

        float tmp = (-halfB - root) / a;
        if(tmp < tmax && tmp > tmin) {
            record.t = tmp;
            record.position = ray.origin + ray.direction * tmp;
            record.materialIndex = sphere.materialIndex;

            vec3 normal = (record.position - sphere.center) / sphere.radius;
            record = SetFaceNormal(record, ray, normal);
            GetSphereUV(normal, record);

            return true;
        }

        tmp = (-halfB + root) / a;
        if(tmp < tmax && tmp > tmin) {
            record.t = tmp;
            record.position = ray.origin + ray.direction * tmp;
            record.materialIndex = sphere.materialIndex;
            
            vec3 normal = (record.position - sphere.center) / sphere.radius;
            record = SetFaceNormal(record, ray, normal);
            GetSphereUV(normal, record);

            return true;
        }
    }

    return false;
}

bool HitRect(in Rect rect, in Ray ray, float tmin, float tmax, inout HitRecord record) {
    if(rect.plane == XY) {
        float t = (rect.k - ray.origin.z) / ray.direction.z;
        if(t < tmin || t > tmax) return false;

        float x = ray.origin.x + t * ray.direction.x;
        float y = ray.origin.y + t * ray.direction.y;
        if(x < rect.x0 || x > rect.x1 || y < rect.y0 || y > rect.y1) return false;

        record.u = (x - rect.x0) / (rect.x1 - rect.x0);
        record.v = (y - rect.y0) / (rect.y1 - rect.y0);
        record.t = t;

        vec3 normal = vec3(0, 0, 1);
        SetFaceNormal(record, ray, normal);
        record.materialIndex = rect.materialIndex;
        record.position = ray.origin + ray.direction * t;
        return true;
    } else if(rect.plane == XZ) {
        float t = (rect.k - ray.origin.y) / ray.direction.y;
        if(t < tmin || t > tmax) return false;

        float x = ray.origin.x + t * ray.direction.x;
        float z = ray.origin.z + t * ray.direction.z;
        if(x < rect.x0 || x > rect.x1 || z < rect.y0 || z > rect.y1) return false;

        record.u = (x - rect.x0) / (rect.x1 - rect.x0);
        record.v = (z - rect.y0) / (rect.y1 - rect.y0);
        record.t = t;

        vec3 normal = vec3(0, 1, 0);
        SetFaceNormal(record, ray, normal);
        record.materialIndex = rect.materialIndex;
        record.position = ray.origin + ray.direction * t;
        return true;
    } else {
        float t = (rect.k - ray.origin.x) / ray.direction.x;
        if(t < tmin || t > tmax) return false;

        float y = ray.origin.y + t * ray.direction.y;
        float z = ray.origin.z + t * ray.direction.z;
        if(y < rect.x0 || y > rect.x1 || z < rect.y0 || z > rect.y1) return false;

        record.u = (y - rect.x0) / (rect.x1 - rect.x0);
        record.v = (z - rect.y0) / (rect.y1 - rect.y0);
        record.t = t;

        vec3 normal = vec3(1, 0, 0);
        SetFaceNormal(record, ray, normal);
        record.materialIndex = rect.materialIndex;
        record.position = ray.origin + ray.direction * t;
        return true;
    }
}

struct IntersectData {
    bool hit;
    Ray ray;
    float t;
};

//bool RayBounds(in Bounds3 bounds, in Ray ray, float t) {
//    return false;
//}

bool HitScene(Ray ray, out HitRecord record)
{
    bool hit_anything = false;
    float closest = 10000.0;

    for(int i = 0; i < spheres.length(); i++) {
        if(HitSphere(spheres[i], ray, 0.001, closest, record)) {
            hit_anything = true;
            closest = record.t;
        }
    }

    for(int i = 0; i < rects.length(); i++) {
        if(HitRect(rects[i], ray, 0.001, closest, record)) {
            hit_anything = true;
            closest = record.t;
        }
    }

    return hit_anything;

//    IntersectData intersect;
//    intersect.hit = false;
//    intersect.ray = r;
//    intersect.t = MAX_RENDER_DIST;
//
//    float t;
//    int toVisitOffset = 0, currentNodeIndex = 0;
//    int nodesToVisit[64];
//
//    while(true) {
//
//        if()
//    }
}

float schlick(float cosine, float ref_idx)
{
    float r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1 - r0) * pow((1 - cosine), 5);
}

vec3 reflect(vec3 v, vec3 n)
{
    return v - 2 * dot(v, n) * n;
}

vec3 refract(vec3 uv, vec3 n, float etai_over_etat)
{
    float cos_theta = dot(-uv, n);
    vec3 r_out_perp = etai_over_etat * (uv + cos_theta * n);
    vec3 r_out_parallel = -sqrt(abs(1.0 - LengthSquared(r_out_perp))) * n;
    return r_out_perp + r_out_parallel;
}

vec3 emitted(in Material material, float u, float v, in vec3 p) {
    if(material.type == DIFFUSE_LIGHT) {
        return GetTextureColor(textures[material.texture], u, v, p);
    } else {
        return vec3(0);
    }
}

bool Scatter(Ray ray, HitRecord record, out vec3 attenuation, out Ray scattered)
{
    if(NearZero(ray.direction)) {
        return false;
    }

    if(materials[record.materialIndex].type == DIFFUSE) {
        vec3 scatter_direction = record.normal + RandomUnitVector(RandomSeed);
        scattered = Ray(record.position, scatter_direction);
        attenuation = GetTextureColor(
            textures[materials[record.materialIndex].texture], record.u, record.v, record.position
        );
        return true;
    } else if(materials[record.materialIndex].type == METAL) {
        vec3 reflected = reflect(normalize(ray.direction), record.normal);
        scattered = Ray(
            record.position, reflected + materials[record.materialIndex].property * RandomInUnitSphere(RandomSeed)
        );
        attenuation = GetTextureColor(textures[materials[record.materialIndex].texture], record.u, record.v, record.position);
        return dot(scattered.direction, record.normal) > 0;
    } else if(materials[record.materialIndex].type == DIELECTRIC) {
        attenuation = vec3(1);
        float etai_over_etat = record.frontFace ? (1.0f / materials[record.materialIndex].property) : materials[record.materialIndex].property;

        float cos_theta = min(dot(-normalize(ray.direction), record.normal), 1.0f);
        float sin_theta = sqrt(1.0f - cos_theta * cos_theta);
        if(etai_over_etat * sin_theta > 1) {
            vec3 reflected = reflect(normalize(ray.direction), record.normal);
            scattered = Ray(record.position, reflected);
            return true;
        }

        float reflect_prob = schlick(cos_theta, etai_over_etat);
        if(Hash1d(RandomSeed) < reflect_prob) {
            vec3 reflected = reflect(normalize(ray.direction), record.normal);
            scattered = Ray(record.position, reflected);
            return true;
        }

        vec3 refracted = refract(normalize(ray.direction), record.normal, etai_over_etat);
        scattered = Ray(record.position, refracted);
        return true;
    } else if(materials[record.materialIndex].type == DIFFUSE_LIGHT) {
        return false;
    } else if(materials[record.materialIndex].type == ISOTROPIC) {
        scattered = Ray(record.position, RandomInUnitSphere(RandomSeed));
        attenuation = GetTextureColor(textures[materials[record.materialIndex].texture], record.u, record.v, record.position);
        return true;
    }

    return false;
}

vec3 RayColor(Ray ray_in, vec3 background, int depth)
{
    vec3 final = vec3(1);
    Ray ray = ray_in;

    while(true) {
        HitRecord record;
        if(depth <= 0) {
            return vec3(0);
        }

        if(!HitScene(ray, record)) {
            return background;
        }

        Ray scattered;
        vec3 attenuation;
        vec3 emitted = emitted(materials[record.materialIndex], record.u, record.v, record.position);

        if(!Scatter(ray, record, attenuation, scattered)) {
            return final * emitted;
        }

        ray = scattered;
        depth--;
        final *= emitted + attenuation;
    }

    return vec3(0);
}

Camera NewCamera(
    vec3 lookfrom, vec3 lookat, vec3 vup,
    float vfov, float aspect_ratio
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

Ray GetRay(Camera c, vec2 uv)
{
    return Ray(
        c.origin,
        c.lower_left_corner + uv.x * c.horizontal + uv.y * c.vertical - c.origin
    );
}

void GammaCorrect(inout vec4 px, int samples)
{
    float scale = 1.0 / samples;
    px.x = sqrt(clamp(scale * px.x, 0, 1));
    px.y = sqrt(clamp(scale * px.y, 0, 1));
    px.z = sqrt(clamp(scale * px.z, 0, 1));
}

void main()
{
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    if(uframe == 0) {
        imageStore(framebuffer, coords, vec4(1));
        return;
    }

    vec3 lookfrom = vec3(273, 273, -800);

    vec3 lookat = vec3(273, 273, 273);
    vec3 background = vec3(0);

    Camera cam = NewCamera(
        lookfrom, lookat,
        vec3(0, 1, 0),    
        40, uwidth / uheight
    );

    RandomSeed = float(BaseHash(floatBitsToUint(vec2(coords))))/float(0xffffffffU)+utime;
    
    vec3 pixel;
    for(int i = 0; i < SAMPLES; i++) {
        vec2 uv = (coords + Hash2d(RandomSeed)) / vec2(uwidth, uheight);
        Ray r = GetRay(cam, uv);
        pixel += vec3(
            RayColor(r, background, DEPTH)
        );
    }

    vec4 final = vec4(pixel, 1.0);
    GammaCorrect(final, SAMPLES);

    final = final * 0.1 + imageLoad(framebuffer, coords) * 0.9;

    imageStore(framebuffer, coords, final);
}