#include <iostream>

#include <luau/Compiler.h>
#include <luacode.h>

struct lua_CompileOptions options;

int main() {
	size_t binarySize;
	luau_compile("print(\"e\")", 11, &options, &binarySize);
	std::cout << "hello cmake!\n";
	return 0;
}
