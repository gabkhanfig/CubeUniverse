#define DOCTEST_CONFIG_IMPLEMENT
#include <gk_types_lib/doctest/doctest_proxy.h>
#include "core.h"

#ifdef WITH_TESTS

CUBE_API void cue_runUnitTests(int argc, char** argv) {
	doctest::Context context;
	context.applyCommandLine(argc, argv);
	context.setOption("no-breaks", true);
	int res = context.run();
}
#endif