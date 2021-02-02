// Copyright (c) 2021 Pathfinders
// This file is part of rt.
//
// rt is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// rt is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with rt.  If not, see <https://www.gnu.org/licenses/>.

#ifndef RT_SCENE_H
#define RT_SCENE_H

enum TextureType {
    SOLID_COLOR,
    CHECKERED,
    IMAGE
};

enum MaterialType {
    DIFFUSE,
    METAL,
    DIELECTRIC,
    DIFFUSE_LIGHT
};

enum Plane {
    XY,
    XZ,
    YZ
};

struct Texture {
    enum TextureType type;
    float albedo[3];
    unsigned int property1;
    unsigned int property2;
};

struct Material {
    enum MaterialType type;
    unsigned int texture;
    float property;
};

struct Sphere {
    float center[3];
    float radius;
    unsigned int material;
};

struct Rect {
    enum Plane plane;
    float x0, x1, y0, y1, k;
    unsigned int material;
    float rotation;
};

struct Scene {
    unsigned int textureCount;
    struct Texture* textures;

    unsigned int materialCount;
    struct Material* materials;

    unsigned int sphereCount;
    struct Sphere* spheres;

    unsigned int rectCount;
    struct Rect* rects;
};

struct Scene* createScene();
_Bool uploadScene(struct Scene* scene);
void freeScene(struct Scene* scene);

#endif //RT_SCENE_H
