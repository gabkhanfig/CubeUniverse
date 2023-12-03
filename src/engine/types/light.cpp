#include "light.h"

#if CUBE_UNIVERSE_TEST

comptime_test_case(BlockLight, DefaultUnLit, {
	BlockLight light;
	comptimeAssertEq(light.r(), 0);
	comptimeAssertEq(light.g(), 0);
	comptimeAssertEq(light.b(), 0);
});

comptime_test_case(BlockLight, ConstructWithMaxValues, {
	BlockLight light = BlockLight(31, 31, 31);
	comptimeAssertEq(light.r(), 31);
	comptimeAssertEq(light.g(), 31);
	comptimeAssertEq(light.b(), 31);
});

comptime_test_case(BlockLight, ConstructWithMixedValues, {
	BlockLight light = BlockLight(15, 20, 9);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetRedZero, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setRed(0);
	comptimeAssertEq(light.r(), 0);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetRedMax, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setRed(31);
	comptimeAssertEq(light.r(), 31);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetRedMixed, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setRed(19);
	comptimeAssertEq(light.r(), 19);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetGreenZero, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setGreen(0);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 0);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetGreenMax, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setGreen(31);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 31);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetGreenMixed, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setGreen(19);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 19);
	comptimeAssertEq(light.b(), 9);
});

comptime_test_case(BlockLight, SetBlueZero, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setBlue(0);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 0);
});

comptime_test_case(BlockLight, SetBlueMax, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setBlue(31);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 31);
});

comptime_test_case(BlockLight, SetBlueMixed, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setBlue(19);
	comptimeAssertEq(light.r(), 15);
	comptimeAssertEq(light.g(), 20);
	comptimeAssertEq(light.b(), 19);
});

#endif