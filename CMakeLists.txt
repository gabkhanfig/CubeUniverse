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
# Include sub-projects.
add_subdirectory ("src")
# Dependencies
add_subdirectory ("dependencies/luau-0.603")
add_subdirectory ("dependencies/gk_types_lib_0.1")
add_subdirectory ("dependencies/enet-1.3.17")
add_subdirectory ("dependencies/glm-0.9.9.8/glm")
add_subdirectory ("dependencies/glfw-3.3.8")

include_directories("dependencies/glm-0.9.9.8")

include(dependencies/gk_types_lib_0.1/doctest_force_link_static_lib_in_target.cmake)




