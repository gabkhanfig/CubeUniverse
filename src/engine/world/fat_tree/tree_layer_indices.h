#pragma once

#include "../../core.h"

namespace world {

	/// Size = 12 bytes. Alignment = 4 bytes.
	struct TreeLayerIndices {
		/// How many nodes long / wide / tall each layer of the FatTree is.
		static constexpr u64 NODE_LENGTH = 4;
		/// Total amount of nodes per layer within the FatTree.
		static constexpr u64 NODES_PER_LAYER = NODE_LENGTH * NODE_LENGTH * NODE_LENGTH;
		/// Total number of layers within the FatTree structure.
		static constexpr usize LAYERS = 15;
		/// The amount of nodes required on a single dimension to fit the entire tree structure.
		/// Can be thought of as the amount of chunks long/wide/tall the tree is. Is equal to `pow(NODE_LENGTH, LAYERS)`.
		static constexpr u64 TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE = 1073741824ULL;
		static constexpr u32 INDICES_PER_INT = 5;
		static constexpr u32 BITSHIFT_MULTIPLY = 6;
		static constexpr u32 BITMASK_LAYER_INDEX = 0b111111;

		/// Similar to `BlockIndex`:
		/// - x has a factor of 1
		/// - y has a factor of 16
		/// - z has a factor of 4
		struct Index {
			u8 value;

			static constexpr u8 Y_SHIFT = 4;
			static constexpr u8 Z_SHIFT = 2;

			/// Each component must be in the range of 0 - 3 inclusive.
			static constexpr Index init(const u8 inX, const u8 inY, const u8 inZ) {
				check_le(inX, 3);
				check_le(inY, 3);
				check_le(inZ, 3);
				const u8 indexMask = inX | (inY << Y_SHIFT) | (inZ << Z_SHIFT);
				return Index{ .value = indexMask };
			}

			constexpr u8 x() const {
				return this->value & 0b11;
			}

			constexpr u8 y() const {
				return (this->value >> Y_SHIFT) & 0b11;
			}

			constexpr u8 z() const {
				return (this->value >> Z_SHIFT) & 0b11;
			}

			/// @param inX: Must be in the range of 0 - 3 inclusive.
			constexpr void setX(const u8 inX) {
				check_le(inX, 3);
				this->value = (this->value & 0b11) | inX;
			}

			/// @param inY: Must be in the range of 0 - 3 inclusive.
			constexpr void setY(const u8 inY) {
				check_le(inY, 3);
				this->value = (this->value & (0b11 << Y_SHIFT)) | (inY << Y_SHIFT);
			}

			/// @param inZ: Must be in the range of 0 - 3 inclusive.
			constexpr void setZ(const u8 inZ) {
				check_le(inZ, 3);
				this->value = (this->value & (0b11 << Z_SHIFT)) | (inZ << Z_SHIFT);
			}

			constexpr bool operator==(const Index& other) const {
				return this->value == other.value;
			}

		}; // struct Index

		constexpr TreeLayerIndices() 
			: values{0} 
		{}

		/// Get the index stored within this `TreeLayerIndices` at a given `layer`.
		/// Asserts that `layer` is less than `TREE_LAYERS`.
		/// @param layer: Uses 0 indexing.
		/// @return The x y z components corresponding to a node on a fat tree layer.
		constexpr Index indexAtLayer(const usize layer) const {
			check_le(layer, LAYERS);

			const usize valueIndex = layer % 3;
			const usize layerIndex = layer % INDICES_PER_INT;
			const usize bitshift = layerIndex * BITSHIFT_MULTIPLY;

			const u8 index = static_cast<u8>((this->values[valueIndex] >> bitshift) & BITMASK_LAYER_INDEX);
			return Index{ .value = index };
		}

		/// Set the node `index` at a specific tree `layer`.
		/// Asserts that `layer` is less than `TREE_LAYERS`.
		/// @param layer: Uses 0 indexing.
		/// @param index: The index corresponding to a node on a fat tree layer.
		constexpr void setIndexAtLayer(const usize layer, const Index index) {
			check_le(layer, LAYERS);


			const usize valueIndex = layer % 3;
			const usize layerIndex = layer % INDICES_PER_INT;
			const usize bitshift = layerIndex * BITSHIFT_MULTIPLY;

			const u32 mask = ~(BITMASK_LAYER_INDEX << bitshift);
			const u32 indexAsU32 = static_cast<u32>(index.value);

			this->values[valueIndex] = (this->values[valueIndex] & mask) | (indexAsU32 << bitshift);
		}

		constexpr bool operator==(const TreeLayerIndices& other) const {
			return this->values[0] == other.values[0] && this->values[1] == other.values[1] && this->values[2] == other.values[2];
		}

		u32 values[3];
		

		
}; // struct TreeLayerIndices
} // namespace world