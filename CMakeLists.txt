cmake_minimum_required(VERSION 3.1)
project(rt LANGUAGES C)

set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

add_executable(
    ${PROJECT_NAME}

    src/main.c
    src/window.c
    src/shader.c

    include/window.h
    include/shader.h
    include/stb_image.h
        src/scene.c include/scene.h)

add_subdirectory(lib/glfw)
add_subdirectory(lib/glad)

target_include_directories(${PROJECT_NAME} PRIVATE include)
target_include_directories(${PROJECT_NAME} PRIVATE lib/glfw/include)
target_include_directories(${PROJECT_NAME} PRIVATE lib/glad/include)

target_link_libraries(${PROJECT_NAME} glfw)
target_link_libraries(${PROJECT_NAME} glad ${CMAKE_DL_LIBS})