#include "light.h"

#if CUBE_UNIVERSE_TEST

comptime_test_case(BlockLight, DefaultUnLit, {
	BlockLight light;
	check_eq(light.r(), 0);
	check_eq(light.g(), 0);
	check_eq(light.b(), 0);
});

comptime_test_case(BlockLight, ConstructWithMaxValues, {
	BlockLight light = BlockLight(31, 31, 31);
	check_eq(light.r(), 31);
	check_eq(light.g(), 31);
	check_eq(light.b(), 31);
});

comptime_test_case(BlockLight, ConstructWithMixedValues, {
	BlockLight light = BlockLight(15, 20, 9);
	check_eq(light.r(), 15);
	check_eq(light.g(), 20);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetRedZero, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setRed(0);
	check_eq(light.r(), 0);
	check_eq(light.g(), 20);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetRedMax, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setRed(31);
	check_eq(light.r(), 31);
	check_eq(light.g(), 20);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetRedMixed, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setRed(19);
	check_eq(light.r(), 19);
	check_eq(light.g(), 20);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetGreenZero, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setGreen(0);
	check_eq(light.r(), 15);
	check_eq(light.g(), 0);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetGreenMax, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setGreen(31);
	check_eq(light.r(), 15);
	check_eq(light.g(), 31);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetGreenMixed, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setGreen(19);
	check_eq(light.r(), 15);
	check_eq(light.g(), 19);
	check_eq(light.b(), 9);
});

comptime_test_case(BlockLight, SetBlueZero, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setBlue(0);
	check_eq(light.r(), 15);
	check_eq(light.g(), 20);
	check_eq(light.b(), 0);
});

comptime_test_case(BlockLight, SetBlueMax, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setBlue(31);
	check_eq(light.r(), 15);
	check_eq(light.g(), 20);
	check_eq(light.b(), 31);
});

comptime_test_case(BlockLight, SetBlueMixed, {
	BlockLight light = BlockLight(15, 20, 9);
	light.setBlue(19);
	check_eq(light.r(), 15);
	check_eq(light.g(), 20);
	check_eq(light.b(), 19);
});

#endif