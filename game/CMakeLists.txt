# CMakeList.txt : CMake project for CubeUniverse, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.12)

# Add source to this project's executable.
add_executable (CubeUniverse "main.cpp")
add_library (CubeUniverseLib "lib.cpp" "lib.h")


set_property(TARGET CubeUniverse PROPERTY CXX_STANDARD 20)
set_property(TARGET CubeUniverseLib PROPERTY CXX_STANDARD 20)

#add_subdirectory ("../dependencies/luau")


#target_link_libraries(CubeUniverse Luau)
#set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

target_link_libraries(CubeUniverse CubeUniverseCore)
target_link_libraries(CubeUniverse Luau.VM)
target_link_libraries(CubeUniverse Luau.Compiler)

target_link_libraries(CubeUniverseLib CubeUniverseCore)
target_link_libraries(CubeUniverseLib Luau.VM)
target_link_libraries(CubeUniverseLib Luau.Compiler)
# target_link_libraries(CubeUniverse gtest_main)

# TODO: Add tests and install targets if needed.