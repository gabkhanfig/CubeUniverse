#define DOCTEST_CONFIG_IMPLEMENT
#include <gk_types_lib/doctest/doctest_proxy.h>

#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>

#define GLM_FORCE_RADIANS
#define GLM_FORCE_DEPTH_ZERO_TO_ONE
#include <glm/vec4.hpp>
#include <glm/mat4x4.hpp>

#include <iostream>

#include <lua.h>
#include <luacode.h>
#include <lualib.h>

//int main() {
//  glfwInit();
//
//  glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
//  GLFWwindow* window = glfwCreateWindow(800, 600, "Vulkan window", nullptr, nullptr);
//
//  uint32_t extensionCount = 0;
//  vkEnumerateInstanceExtensionProperties(nullptr, &extensionCount, nullptr);
//
//  std::cout << extensionCount << " extensions supported\n";
//
//  glm::mat4 matrix;
//  glm::vec4 vec;
//  auto test = matrix * vec;
//
//  while (!glfwWindowShouldClose(window)) {
//    glfwPollEvents();
//  }
//
//  glfwDestroyWindow(window);
//
//  glfwTerminate();
//
//  return 0;
//}

int main() {


	int status, result;
	lua_State* L;
	L = luaL_newstate();

	luaL_openlibs(L);
	size_t bytecodeSize = 0;
	const char* source = "print(\"hello world!\")";
	char* bytecode = luau_compile(source, strlen(source), NULL, &bytecodeSize);
	int loadResult = luau_load(L, "test?", bytecode, bytecodeSize, 0);
	free(bytecode);

	result = lua_pcall(L, 0, 0, 0);


}