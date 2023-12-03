#pragma once

#include <core.h>

/**
* Stores the RGB light leve of a given transparent/semi-transparent block.
* Each RGB component can range from 0-31, and all components are stored in a 16 bit integer.
*/
struct BlockLight
{
	static constexpr u16 RED_BITMASK = 0b11111;
	static constexpr u16 GREEN_BITMASK = 0b11111 << 5;
	static constexpr u16 BLUE_BITMASK = 0b11111 << 10;
	static constexpr u8 MAX_LIGHT_LEVEL = 31;

	constexpr BlockLight() : mask(0) {}

	constexpr BlockLight(u8 inR, u8 inG, u8 inB) {
		check_message(inR <= MAX_LIGHT_LEVEL, "Red light level must be less than or equal to BlockLight::MAX_LIGHT_LEVEL");
		check_message(inG <= MAX_LIGHT_LEVEL, "Green light level must be less than or equal to BlockLight::MAX_LIGHT_LEVEL");
		check_message(inB <= MAX_LIGHT_LEVEL, "Blue light level must be less than or equal to BlockLight::MAX_LIGHT_LEVEL");

		mask = static_cast<u16>(inR) | static_cast<u16>(inG << 5) | static_cast<u16>(inB << 10);
	}

	/**
	* Get the red light level.
	*/
	constexpr u8 r() const {
		return mask & RED_BITMASK;
	}

	/**
	* Get the green light level.
	*/
	constexpr u8 g() const {
		return (mask & GREEN_BITMASK) >> 5;
	}

	/**
	* Get the blue light level.
	*/
	constexpr u8 b() const {
		return (mask & BLUE_BITMASK) >> 10;
	}

	/**
	* Get the 16 bit mask of all of the RGB components.
	*/
	constexpr u16 getMask() const {
		return mask;
	}

	/**
	* Manually set the red component.
	* Must be between 0 - 31 inclusively.
	*/
	constexpr void setRed(u8 newR) {
		check_message(newR <= MAX_LIGHT_LEVEL, "Red light level must be less than or equal to BlockLight::MAX_LIGHT_LEVEL");

		mask = (mask & ~RED_BITMASK) | static_cast<u16>(newR);
	}

	/**
	* Manually set the green component.
	* Must be between 0 - 31 inclusively.
	*/
	constexpr void setGreen(u8 newG) {
		check_message(newG <= MAX_LIGHT_LEVEL, "Green light level must be less than or equal to BlockLight::MAX_LIGHT_LEVEL");

		mask = (mask & ~GREEN_BITMASK) | (static_cast<u16>(newG) << 5);
	}

	/**
	* Manually set the blue component.
	* Must be between 0 - 31 inclusively.
	*/
	constexpr void setBlue(u8 newB) {
		check_message(newB <= MAX_LIGHT_LEVEL, "Blue light level must be less than or equal to BlockLight::MAX_LIGHT_LEVEL");

		mask = (mask & ~BLUE_BITMASK) | (static_cast<u16>(newB) << 10);
	}

private:
	u16 mask;
};