#pragma once

#include "../core.h"

/// 2-byte, 3-bit component RGBA color structure for use in the NTree.
/// Compressed to 2 bytes to allow aggressive memory usage optimizations within
/// each layer of the NTree. Uses bitmasks to allow usage on the GPU using the same
/// API. The upper 4 bits are unused, and the programmer is free to use them for whatever.
///
/// # Zero value
///
/// If the member variable `mask` is just 0, it can be considered as "empty",
/// because it is RGBA(0, 0, 0, 0);
struct TreeNodeColor {
	static constexpr u16 EXTRACT_BITMASK = 0b111;

	static constexpr u16 GREEN_SHIFT = 3;
	static constexpr u16 BLUE_SHIFT = 6;
	static constexpr u16 ALPHA_SHIFT = 9;

	static constexpr u16 RED_BITMASK = 0b111;
	static constexpr u16 GREEN_BITMASK = 0b111 << GREEN_SHIFT;
	static constexpr u16 BLUE_BITMASK = 0b111 << BLUE_SHIFT;
	static constexpr u16 ALPHA_BITMASK = 0b111 << ALPHA_SHIFT;

	/// Highest 4 bits are unused, and preserved through mutation operations, 
	/// aside from overwriting the mask / instance.
	u16 mask;

	/// All params must be between the range 0 - 7 inclusive.
	constexpr static TreeNodeColor init(const u16 inRed, const u16 inGreen, const u16 inBlue, const u16 inAlpha) {
		check_le(inRed, 0b111);
		check_le(inGreen, 0b111);
		check_le(inBlue, 0b111);
		check_le(inAlpha, 0b111);

		const u16 maskedColor = inRed | (inGreen << GREEN_SHIFT) | (inBlue << BLUE_SHIFT) | (inAlpha << ALPHA_SHIFT);
		return TreeNodeColor{ .mask = maskedColor };
	}

	constexpr u16 red() const {
		return this->mask & EXTRACT_BITMASK;
	}

	constexpr u16 green() const {
		return (this->mask >> GREEN_SHIFT) & EXTRACT_BITMASK;
	}

	constexpr u16 blue() const {
		return (this->mask >> BLUE_SHIFT) & EXTRACT_BITMASK;
	}

	constexpr u16 alpha() const {
		return (this->mask >> ALPHA_SHIFT) & EXTRACT_BITMASK;
	}

	/// @param inRed: Must be in the range 0 - 7 inclusive.
	constexpr void setRed(const u16 inRed) {
		check_le(inRed, 0b111);
		this->mask = (this->mask & ~RED_BITMASK) | inRed;
	}

	/// @param inGreen: Must be in the range 0 - 7 inclusive.
	constexpr void setGreen(const u16 inGreen) {
		check_le(inGreen, 0b111);
		this->mask = (this->mask & ~GREEN_BITMASK) | (inGreen << GREEN_SHIFT);
	}

	/// @param inBlue: Must be in the range 0 - 7 inclusive.
	constexpr void setBlue(const u16 inBlue) {
		check_le(inBlue, 0b111);
		this->mask = (this->mask & ~BLUE_BITMASK) | (inBlue << BLUE_SHIFT);
	}

	/// @param inAlpha: Must be in the range 0 - 7 inclusive.
	constexpr void setAlpha(const u16 inAlpha) {
		check_le(inAlpha, 0b111);
		this->mask = (this->mask & ~ALPHA_BITMASK) | (inAlpha << ALPHA_SHIFT);
	}
};