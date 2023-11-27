cmake_minimum_required (VERSION 3.12)

add_executable (CubeUniverse "main.cpp")
add_executable (CubeUniverseTest "test.cpp")

target_compile_definitions(CubeUniverse PUBLIC
	$<$<CONFIG:Debug>:CUBE_DEBUG GK_TYPES_LIB_DEBUG>
	$<$<CONFIG:RelWithDebInfo>:CUBE_DEBUG GK_TYPES_LIB_DEBUG>
	$<$<CONFIG:Release>:CUBE_SHIPPING GK_TYPES_LIB_SHIPPING>
)

target_compile_definitions(CubeUniverseTest PUBLIC CUBE_UNIVERSE_TEST GK_TYPES_LIB_TEST)

#message(STATUS "Attempting auto locate Vulkan using CMake......")
find_package(Vulkan REQUIRED)
target_link_libraries(CubeUniverse Vulkan::Vulkan)
#target_link_libraries(CubeUniverse ${Vulkan_LIBRARY})
#target_link_directories(CubeUniverse PUBLIC ${Vulkan_INCLUDE_DIR})

#include_directories("$ENV{VULKAN_SDK}/Include")
#target_link_libraries(CubeUniverse "$ENV{VULKAN_SDK}/Lib/vulkan-1.lib")

#include_directories(${Vulkan_INCLUDE_DIRS})
#target_link_libraries(CubeUniverse ${Vulkan_LIBRARIES})

set(TARGET_LIBS 
Luau.VM 
Luau.Compiler 
GkTypesLib 
glm
glfw)

target_link_libraries(CubeUniverse ${TARGET_LIBS})
target_link_libraries(CubeUniverseTest ${TARGET_LIBS})



