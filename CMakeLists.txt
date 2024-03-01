# CMakeList.txt : Top-level CMake project file, do global configuration
# and include sub-projects here.
#
cmake_minimum_required (VERSION 3.12)

set(CMAKE_CXX_STANDARD 20)

# Enable Hot Reload for MSVC compilers if supported.
if (POLICY CMP0141)
  cmake_policy(SET CMP0141 NEW)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project ("CubeUniverse")

# Define ENGINE_SOURCES to be a list of all of the cpp files for the engine
file(GLOB_RECURSE ENGINE_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/*.cpp")
set(GRAPHICS_SOURCES "dependencies/opengl/glad/glad.c")

add_executable(CubeUniverse ${ENGINE_SOURCES} "src/main.cpp" "dependencies/opengl/glad/glad.c")
add_executable(CubeUniverseTest ${ENGINE_SOURCES} "src/test.cpp" "dependencies/opengl/glad/glad.c")

#add_library(CubeUniverseEngine SHARED ${ENGINE_SOURCES} "dependencies/opengl/glad/glad.c")

target_compile_definitions(CubeUniverse PUBLIC
	$<$<CONFIG:Debug>:CUBE_DEBUG GK_TYPES_LIB_DEBUG WITH_TESTS>
	$<$<CONFIG:RelWithDebInfo>:CUBE_DEBUG GK_TYPES_LIB_DEBUG WITH_TESTS>
	$<$<CONFIG:Release>:CUBE_SHIPPING GK_TYPES_LIB_SHIPPING>
)

target_compile_definitions(CubeUniverseTest PUBLIC
	$<$<CONFIG:Debug>:CUBE_DEBUG GK_TYPES_LIB_DEBUG WITH_TESTS>
	$<$<CONFIG:RelWithDebInfo>:CUBE_DEBUG GK_TYPES_LIB_DEBUG WITH_TESTS>
	$<$<CONFIG:Release>:CUBE_SHIPPING GK_TYPES_LIB_SHIPPING WITH_TESTS>
)

#target_compile_definitions(CubeUniverseEngine PUBLIC WITH_TESTS)

set(TARGET_LIBS 
#Luau.VM 
#Luau.Compiler 
GkTypesLib 
glm
glfw
)

target_link_libraries(CubeUniverse ${TARGET_LIBS})
target_link_libraries(CubeUniverseTest ${TARGET_LIBS})

#add_executable(CubeUniverse "src/main.cpp")
#target_link_libraries(CubeUniverse CubeUniverseEngine)


#target_link_libraries(CubeUniverseTest CubeUniverseEngine)


# Dependencies
#add_subdirectory ("dependencies/luau-0.603")
add_subdirectory ("dependencies/gk-types-lib-1.0.1")
add_subdirectory ("dependencies/enet-1.3.17")
add_subdirectory ("dependencies/glm-0.9.9.8/glm")
add_subdirectory ("dependencies/glfw-3.3.8")

include_directories("dependencies/glm-0.9.9.8")
include_directories("dependencies/opengl")




