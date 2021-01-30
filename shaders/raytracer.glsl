#version 430 core
#extension GL_ARB_bindless_texture : enable

layout(local_size_x = 8, local_size_y = 8) in;
layout(rgba32f, binding = 0) uniform image2D framebuffer;

uniform float utime;
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

// Textures
#define SOLID_COLOR 0
#define CHECKERED 1
#define IMAGE 2

#define XY 0
#define XZ 1
#define YZ 2

const int DEPTH = 100, SAMPLES = 10;

float atan2(in float y, in float x)
{
    bool s = (abs(x) > abs(y));
    return mix(PI / 2.0 - atan(x, y), atan(y, x), s);
}

struct Ray
{
    vec3 o, d;
};

struct HitRecord
{
    vec3 p, n;
    float t, u, v;
    bool f;
    uint m;
};

HitRecord set_face_normal(HitRecord rc, Ray r, vec3 n)
{
    rc.f = dot(r.d, n) < 0;
    rc.n = rc.f ? n : -n;
    return rc;
}

struct Texture
{
    uint type; // Texture type
    vec3 albedo; // Color for normal textures

    uint property1; // Texture for odd blocks when checkered or image when image texture
    uint property2; // Texture for even blocks when checkered
};

struct Material
{
    uint type;
    uint texture;
    float property;
};

struct Sphere
{
    vec3 c;
    float r;
    uint m;
};

struct Rect
{
    uint p; // The plane this rectangle is put on (XY, XZ or YZ)
    float x0, x1, y0, y1, k;
    uint m;
};

struct Camera
{
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
    Sphere(vec3(0, 0, -3), 1, 1),
    Sphere(vec3(3, 0, -4), 1, 6),
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
    Texture(SOLID_COLOR, vec3(1, 1, 1), 0, 0),
    Texture(CHECKERED, vec3(0), 2, 3),
    Texture(SOLID_COLOR, vec3(0.9), 0, 0),
    Texture(SOLID_COLOR, vec3(0), 0, 0),
    Texture(IMAGE, vec3(1, 0, 0), 0, 0)
);

Material materials[] = Material[](
    Material(DIFFUSE_LIGHT, 4, 0), // Emission
    Material(DIFFUSE, 1, 0), // Ground
    Material(DIELECTRIC, 0, 1.5), // Scene object 1
    Material(METAL, 0, 0.0), // Scene object 2
    Material(DIFFUSE, 0, 0) // Scene object 3
);

Sphere spheres[] = Sphere[](
    Sphere(vec3(0, -1001, 0), 1000, 1), // Ground
    Sphere(vec3(0, 0, 0), 1, 2), // Scene object 1
    Sphere(vec3(-2, 0, 0), 1, 3), // Scene object 2
    Sphere(vec3(2, 0, 0), 1, 4) // Scene object 3
);

Rect rects[] = Rect[](
    Rect(XY, -7, 7, 0, 10, 3, 0) // Light 1
);

#endif

// Cornell's box
#if 1

Texture textures[] = Texture[](
    Texture(SOLID_COLOR, vec3(0.65, 0.05, 0.05), 0, 0), // Red
    Texture(SOLID_COLOR, vec3(0.12, 0.45, 0.15), 0, 0), // Green
    Texture(SOLID_COLOR, vec3(0.73), 0, 0), // White
    Texture(SOLID_COLOR, vec3(15), 0, 0), // Light
    Texture(IMAGE, vec3(0), 0, 0),
    Texture(IMAGE, vec3(0), 1, 0)
);

Material materials[] = Material[](
    Material(DIFFUSE, 0, 0), // Red wall
    Material(DIFFUSE, 1, 0), // Green wall
    Material(DIFFUSE, 2, 0), // White wall
    Material(DIFFUSE_LIGHT, 3, 0) // Light
);

Sphere spheres[] = Sphere[](
    Sphere(vec3(150, -1001, 273), 100, 4)
);

Rect rects[] = Rect[](
    Rect(YZ, 0, 555, 0, 555, 555, 1),
    Rect(YZ, 0, 555, 0, 555, 0, 0),
    Rect(XZ, 100, 455, 100, 455, 554, 3),
    Rect(XZ, 0, 555, 0, 555, 555, 2),
    Rect(XZ, 0, 555, 0, 555, 0, 2),
    Rect(XY, 0, 555, 0, 555, 555, 2),

    // Box 1
    Rect(XY, 130, 295, 0, 165, 230, 2),
    Rect(XY, 130, 295, 0, 165, 65, 2),

    Rect(XZ, 130, 295, 65, 230, 165, 2),
    Rect(XZ, 130, 295, 65, 230, 0, 2),

    Rect(YZ, 0, 165, 65, 230, 295, 2),
    Rect(YZ, 0, 165, 65, 230, 130, 2),

    // Box 2
    Rect(XY, 256, 430, 0, 330, 460, 2),
    Rect(XY, 256, 430, 0, 330, 295, 2),

    Rect(XZ, 265, 430, 295, 460, 330, 2),
    Rect(XZ, 265, 430, 295, 460, 0, 2),

    Rect(YZ, 0, 330, 295, 460, 430, 2),
    Rect(YZ, 0, 330, 295, 460, 265, 2)
);

#endif

void get_sphere_uv(in vec3 p, inout HitRecord rc)
{
    rc.u = 0.5 - atan(-p.z, p.x) / (2 * PI);
    rc.v = 0.5 - asin(-p.y) / PI;
}

vec3 get_texture_color_value(in Texture texture, in float u, in float v, in vec3 p) {
    if(texture.type == SOLID_COLOR) {
        return texture.albedo;
    } else if(texture.type == CHECKERED) {
        float sines = sin(10 * p.x) * sin(10 * p.y) * sin(10 * p.z);
        if (sines < 0) {
            if (textures[texture.property1].type == SOLID_COLOR) {
                return textures[texture.property1].albedo;
            } else if(textures[texture.property1].type == IMAGE) {
                u = 1.0 - clamp(u, 0, 1);
                v = 1.0 - clamp(v, 0, 1);

                return texture2D(images[textures[texture.property1].property1], vec2(u, v)).xyz;
            } else {
                return vec3(0);
            }
        } else {
            if (textures[texture.property2].type == SOLID_COLOR) {
                return textures[texture.property2].albedo;
            } else if(textures[texture.property2].type == IMAGE) {
                u = 1.0 - clamp(u, 0, 1);
                v = 1.0 - clamp(v, 0, 1);

                return texture2D(images[textures[texture.property2].property1], vec2(u, v)).xyz;
            } else {
                return vec3(0);
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

float length_squared(vec3 v)
{
    return v.x * v.x + v.y * v.y + v.z * v.z;
}

uint base_hash(uvec2 p) {
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U * ((p.x) ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

float g_seed = 0.0;

float hash1(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    return float(n) / float(0xffffffffU);
}

vec2 hash2(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    uvec2 rz = uvec2(n, n * 48271U);
    return vec2(rz.xy & uvec2(0x7fffffffU)) / float(0x7fffffff);
}

vec3 hash3(inout float seed)
{
    uint n = base_hash(floatBitsToUint(vec2(seed += 0.1, seed += 0.1)));
    uvec3 rz = uvec3(n, n * 16807U, n * 48271U);
    return vec3(rz & uvec3(0x7fffffffU)) / float(0x7fffffff);
}

vec3 random_in_unit_sphere(inout float seed)
{
    vec3 h = hash3(seed) * vec3(2.0, 6.28318530718, 1.0) - vec3(1,0,0);
    float phi = h.y;
    float r = pow(h.z, 1.0 / 3.0);
	return r * vec3(sqrt(1.0 - h.x * h.x) * vec2(sin(phi), cos(phi)), h.x);
}

vec3 random_unit_vector(inout float seed)
{
    float a = hash1(seed) * 2 * PI;
    float z = hash1(seed) * 2 - 1;
    float r = sqrt(1 - z * z);
    return vec3(r * cos(a), r * sin(a), z);
}

vec3 random_in_hemisphere(inout float seed, vec3 normal)
{
    vec3 in_unit_sphere = random_in_unit_sphere(seed);
    if(dot(in_unit_sphere, normal) > 0.0) {
        return in_unit_sphere;
    } else {
        return -in_unit_sphere;
    }
}

vec3 random_in_unit_disk(inout float seed)
{
    while(true) {
        vec3 p = vec3(hash1(seed) * 2 - 1, hash1(seed) * 2 - 1, 0);
        if(length_squared(p) >= 1) continue;
        return p;
    }

    return vec3(0);
}

bool near_zero(in vec3 point)
{
    const float s = 1e-8;
    return (abs(point.x) < s) && (abs(point.y) < s) && (abs(point.z) < s);
}

bool hit_sphere(Sphere sp, Ray r, float tmin, float tmax, out HitRecord rc)
{
    vec3 oc = r.o - sp.c;
    float a = length_squared(r.d);
    float halfB = dot(oc, r.d);
    float c = length_squared(oc) - sp.r * sp.r;
    float d = halfB * halfB - a * c;

    if(d > 0.) {
        float root = sqrt(d);

        float tmp = (-halfB - root) / a;
        if(tmp < tmax && tmp > tmin) {
            rc.t = tmp;
            rc.p = r.o + r.d * tmp;
            rc.m = sp.m;

            vec3 n = (rc.p - sp.c) / sp.r;
            rc = set_face_normal(rc, r, n);
            get_sphere_uv(n, rc);

            return true;
        }

        tmp = (-halfB + root) / a;
        if(tmp < tmax && tmp > tmin) {
            rc.t = tmp;
            rc.p = r.o + r.d * tmp;
            rc.m = sp.m;
            
            vec3 n = (rc.p - sp.c) / sp.r;
            rc = set_face_normal(rc, r, n);
            get_sphere_uv(n, rc);

            return true;
        }
    }

    return false;
}

bool hit_rect(in Rect rt, in Ray r, float tmin, float tmax, inout HitRecord rc) {
    if(rt.p == XY) {
        float t = (rt.k - r.o.z) / r.d.z;
        if(t < tmin || t > tmax) return false;

        float x = r.o.x + t * r.d.x;
        float y = r.o.y + t * r.d.y;
        if(x < rt.x0 || x > rt.x1 || y < rt.y0 || y > rt.y1) return false;

        rc.u = (x - rt.x0) / (rt.x1 - rt.x0);
        rc.v = (y - rt.y0) / (rt.y1 - rt.y0);
        rc.t = t;

        vec3 n = vec3(0, 0, 1);
        set_face_normal(rc, r, n);
        rc.m = rt.m;
        rc.p = r.o + r.d * t;
        return true;
    } else if(rt.p == XZ) {
        float t = (rt.k - r.o.y) / r.d.y;
        if(t < tmin || t > tmax) return false;

        float x = r.o.x + t * r.d.x;
        float z = r.o.z + t * r.d.z;
        if(x < rt.x0 || x > rt.x1 || z < rt.y0 || z > rt.y1) return false;

        rc.u = (x - rt.x0) / (rt.x1 - rt.x0);
        rc.v = (z - rt.y0) / (rt.y1 - rt.y0);
        rc.t = t;

        vec3 n = vec3(0, 1, 0);
        set_face_normal(rc, r, n);
        rc.m = rt.m;
        rc.p = r.o + r.d * t;
        return true;
    } else {
        float t = (rt.k - r.o.x) / r.d.x;
        if(t < tmin || t > tmax) return false;

        float y = r.o.y + t * r.d.y;
        float z = r.o.z + t * r.d.z;
        if(y < rt.x0 || y > rt.x1 || z < rt.y0 || z > rt.y1) return false;

        rc.u = (y - rt.x0) / (rt.x1 - rt.x0);
        rc.v = (z - rt.y0) / (rt.y1 - rt.y0);
        rc.t = t;

        vec3 n = vec3(1, 0, 0);
        set_face_normal(rc, r, n);
        rc.m = rt.m;
        rc.p = r.o + r.d * t;
        return true;
    }
}

bool hit_scene(Ray r, out HitRecord rc)
{
    bool hit_anything = false;
    float closest = 10000.0;

    for(int i = 0; i < spheres.length(); i++) {
        if(hit_sphere(spheres[i], r, 0.001, closest, rc)) {
            hit_anything = true;
            closest = rc.t;
        }
    }

    for(int i = 0; i < rects.length(); i++) {
        if(hit_rect(rects[i], r, 0.001, closest, rc)) {
            hit_anything = true;
            closest = rc.t;
        }
    }

    return hit_anything;
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
    vec3 r_out_parallel = -sqrt(abs(1.0 - length_squared(r_out_perp))) * n;
    return r_out_perp + r_out_parallel;
}

vec3 emitted(in Material material, float u, float v, in vec3 p) {
    if(material.type == DIFFUSE_LIGHT) {
        return get_texture_color_value(textures[material.texture], u, v, p);
    } else {
        return vec3(0);
    }
}

bool scatter(Ray r, HitRecord rc, out vec3 attenuation, out Ray scattered)
{
    if(near_zero(r.d)) {
        return false;
    }

    if(materials[rc.m].type == DIFFUSE) {
        vec3 scatter_direction = rc.n + random_unit_vector(g_seed);
        scattered = Ray(rc.p, scatter_direction);
        attenuation = get_texture_color_value(textures[materials[rc.m].texture], rc.u, rc.v, rc.p);
        return true;
    } else if(materials[rc.m].type == METAL) {
        vec3 reflected = reflect(normalize(r.d), rc.n);
        scattered = Ray(rc.p, reflected + materials[rc.m].property * random_in_unit_sphere(g_seed));
        attenuation = get_texture_color_value(textures[materials[rc.m].texture], rc.u, rc.v, rc.p);
        return dot(scattered.d, rc.n) > 0;
    } else if(materials[rc.m].type == DIELECTRIC) {
        attenuation = vec3(1);
        float etai_over_etat = rc.f ? (1. / materials[rc.m].property) : materials[rc.m].property;

        float cos_theta = min(dot(-normalize(r.d), rc.n), 1.);
        float sin_theta = sqrt(1. - cos_theta * cos_theta);
        if(etai_over_etat * sin_theta > 1) {
            vec3 reflected = reflect(normalize(r.d), rc.n);
            scattered = Ray(rc.p, reflected);
            return true;
        }

        float reflect_prob = schlick(cos_theta, etai_over_etat);
        if(hash1(g_seed) < reflect_prob) {
            vec3 reflected = reflect(normalize(r.d), rc.n);
            scattered = Ray(rc.p, reflected);
            return true;
        }

        vec3 refracted = refract(normalize(r.d), rc.n, etai_over_etat);
        scattered = Ray(rc.p, refracted);
        return true;
    } else if(materials[rc.m].type == DIFFUSE_LIGHT) {
        return false;
    }
}

vec3 ray_color(Ray r_in, vec3 background, int depth)
{
    vec3 final = vec3(1);
    Ray r = r_in;

    while(true) {
        HitRecord rc;
        if(depth <= 0) {
            return vec3(0);
        }

        if(!hit_scene(r, rc)) {
            return background;
        }

        Ray scattered;
        vec3 attenuation;
        vec3 emitted = emitted(materials[rc.m], rc.u, rc.v, rc.p);

        if(!scatter(r, rc, attenuation, scattered)) {
            return final * emitted;
        }

        r = scattered;
        depth--;
        final *= emitted + attenuation;
    }

    return vec3(0);
}

Camera new_camera(
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

Ray get_camera_ray(Camera c, vec2 uv)
{
    return Ray(
        c.origin,
        c.lower_left_corner + uv.x * c.horizontal + uv.y * c.vertical - c.origin
    );
}

void gamma_correct(inout vec4 px, int samples)
{
    float scale = 1.0 / samples;
    px.x = sqrt(clamp(scale * px.x, 0, 1));
    px.y = sqrt(clamp(scale * px.y, 0, 1));
    px.z = sqrt(clamp(scale * px.z, 0, 1));
}

void main()
{
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    vec3 lookfrom = vec3(278, 278, -800);
    vec3 lookat = vec3(278, 278, 0);
//    vec3 lookat = vec3(150, 101, 273);
    vec3 background = vec3(0);

    Camera cam = new_camera(
        lookfrom, lookat,
        vec3(0, 1, 0),    
        40, uwidth / uheight
    );

    g_seed = float(base_hash(floatBitsToUint(vec2(coords))))/float(0xffffffffU)+utime;
    
    vec3 pixel;
    for(int i = 0; i < SAMPLES; i++) {
        vec2 uv = (coords + hash2(g_seed)) / vec2(uwidth, uheight);
        Ray r = get_camera_ray(cam, uv);
        pixel += vec3(
            ray_color(r, background, DEPTH)
        );
    }

    vec4 final = vec4(pixel, 1);
    gamma_correct(final, SAMPLES);

    final = final * 0.01 + imageLoad(framebuffer, coords) * 0.99;

    imageStore(framebuffer, coords, final);
}