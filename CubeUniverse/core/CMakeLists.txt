cmake_minimum_required (VERSION 3.8)

add_library(core STATIC "cube_core/core.cpp")

target_compile_definitions(core PUBLIC
	$<$<CONFIG:Debug>:CUBE_DEBUG>
	$<$<CONFIG:RelWithDebInfo>:CUBE_DEBUG>
	$<$<CONFIG:Release>:CUBE_SHIPPING>
)

target_include_directories(core PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)

#include_directories(.)

#target_include_directories(core PRIVATE .)