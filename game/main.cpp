#include <iostream>

#include <luau/Compiler.h>
#include <luacode.h>
#include <windows.h>

#include <core/core.h>

struct lua_CompileOptions options;


#if CUBE_DEBUG
int main() {
	size_t binarySize;
	luau_compile("print(\"e\")", 11, &options, &binarySize);
	std::cout << "hello cmake!\n";
	printMultiply(5, 6);
	return 0;
}
#elif CUBE_SHIPPING
int main() {
	size_t binarySize;
	luau_compile("print(\"e\")", 11, &options, &binarySize);
	printMultiply(10, 6);
	std::cout << "whoa... cmake!\n";
	return 0;
}
#endif
