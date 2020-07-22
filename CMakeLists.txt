cmake_minimum_required(VERSION 3.1)
project(gl_skeleton LANGUAGES C)



add_executable(
    ${PROJECT_NAME}

    src/main.c
    src/window.c

    include/window.h
)

add_subdirectory(lib/glfw)
add_subdirectory(lib/glad)

target_include_directories(${PROJECT_NAME} PRIVATE include)
target_include_directories(${PROJECT_NAME} PRIVATE lib/glfw/include)
target_include_directories(${PROJECT_NAME} PRIVATE lib/glad/include)

target_link_libraries(${PROJECT_NAME} glfw)
target_link_libraries(${PROJECT_NAME} glad ${CMAKE_DL_LIBS})



