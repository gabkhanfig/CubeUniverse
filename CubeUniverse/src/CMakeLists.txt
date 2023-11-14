# CMakeList.txt : CMake project for CubeUniverse, include source and define
# project specific logic here.
#

# Add source to this project's executable.
add_executable (CubeUniverse "main.cpp")

if (CMAKE_VERSION VERSION_GREATER 3.12)
  set_property(TARGET CubeUniverse PROPERTY CXX_STANDARD 20)
endif()

#add_subdirectory ("../dependencies/luau")


#target_link_libraries(CubeUniverse Luau)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

target_link_libraries(CubeUniverse Luau.VM)
target_link_libraries(CubeUniverse Luau.Compiler)
# target_link_libraries(CubeUniverse gtest_main)

# TODO: Add tests and install targets if needed.