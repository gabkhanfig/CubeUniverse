#pragma once

#include <core.h>

struct Color
{
	u8 r;
	u8 g;
	u8 b;

	constexpr Color() : r(0), g(0), b(0) {}

	constexpr Color(u8 inR, u8 inG, u8 inB) : r(inR), g(inG), b(inB) {}
};