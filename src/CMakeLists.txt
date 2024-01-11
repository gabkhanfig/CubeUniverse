cmake_minimum_required (VERSION 3.12)

add_executable (CubeUniverse "main.cpp" "world/n_tree/tree_index.cpp" "world/n_tree/tree.cpp" "world/n_tree/tree_layers.cpp" "world/world_transform.cpp" "world/chunk/chunk.cpp" "engine/types/light.cpp")
add_executable (CubeUniverseTest "test.cpp" "world/n_tree/tree_index.cpp" "world/n_tree/tree.cpp" "world/n_tree/tree_layers.cpp" "world/world_transform.cpp" "world/chunk/chunk.cpp" "engine/types/light.cpp")

target_compile_definitions(CubeUniverse PUBLIC
	$<$<CONFIG:Debug>:CUBE_DEBUG GK_TYPES_LIB_DEBUG>
	$<$<CONFIG:RelWithDebInfo>:CUBE_DEBUG GK_TYPES_LIB_DEBUG>
	$<$<CONFIG:Release>:CUBE_SHIPPING GK_TYPES_LIB_SHIPPING>
)

target_compile_definitions(CubeUniverseTest PUBLIC CUBE_UNIVERSE_TEST GK_TYPES_LIB_TEST)

#message(STATUS "Attempting auto locate Vulkan using CMake......")
find_package(Vulkan REQUIRED)

set(TARGET_LIBS 
Luau.VM 
Luau.Compiler 
GkTypesLib 
glm
glfw
Vulkan::Vulkan)

target_link_libraries(CubeUniverse ${TARGET_LIBS})
target_link_libraries(CubeUniverseTest ${TARGET_LIBS})

target_include_directories(CubeUniverse PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_include_directories(CubeUniverseTest PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
