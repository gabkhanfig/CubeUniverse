#define DOCTEST_CONFIG_IMPLEMENT
#include <gk_types_lib/doctest/doctest_proxy.h>

int main(int argc, char** argv) {
	doctest::Context context;
	context.applyCommandLine(argc, argv);
	context.setOption("no-breaks", true);
	int res = context.run();
}