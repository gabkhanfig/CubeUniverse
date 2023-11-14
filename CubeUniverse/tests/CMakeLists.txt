# CMakeList.txt : CMake project for CubeUniverseTest, include source and define
# project specific logic here.
#

add_executable (CubeUniverseTest "test_main.cpp")

if (CMAKE_VERSION VERSION_GREATER 3.12)
  set_property(TARGET CubeUniverseTest PROPERTY CXX_STANDARD 20)
endif()

#add_subdirectory ("../dependencies/luau")


#target_link_libraries(CubeUniverse Luau)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

target_link_libraries(CubeUniverseTest Luau.VM)
target_link_libraries(CubeUniverseTest Luau.Compiler)
target_link_libraries(CubeUniverseTest gtest_main)