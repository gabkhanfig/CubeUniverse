cmake_minimum_required (VERSION 3.12)

add_library(CubeUniverseCore STATIC "core.cpp")

set_property(TARGET CubeUniverseCore PROPERTY CXX_STANDARD 20)

target_compile_definitions(CubeUniverseCore PUBLIC
	$<$<CONFIG:Debug>:CUBE_DEBUG>
	$<$<CONFIG:RelWithDebInfo>:CUBE_DEBUG>
	$<$<CONFIG:Release>:CUBE_SHIPPING>
)

target_include_directories(CubeUniverseCore PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>/..)

#include_directories(.)

#target_include_directories(core PRIVATE .)