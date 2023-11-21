# CMakeList.txt : CMake project for CubeUniverseTest, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.12)

add_executable (CubeUniverseTest "main.cpp")

set_property(TARGET CubeUniverseTest PROPERTY CXX_STANDARD 20)


#add_subdirectory ("../dependencies/luau")


#target_link_libraries(CubeUniverse Luau)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

target_link_libraries(CubeUniverseTest CubeUniverseCore)
target_link_libraries(CubeUniverseTest CubeUniverseLib)
target_link_libraries(CubeUniverseTest Luau.VM)
target_link_libraries(CubeUniverseTest Luau.Compiler)
target_link_libraries(CubeUniverseTest gtest_main)