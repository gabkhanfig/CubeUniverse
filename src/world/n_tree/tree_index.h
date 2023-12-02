#pragma once

#include <core.h>
#include <gk_types_lib/option/option.h>

namespace world
{
	constexpr u16 TREE_NODE_LENGTH = 8;
	constexpr u16 TREE_NODES_PER_LAYER = TREE_NODE_LENGTH * TREE_NODE_LENGTH * TREE_NODE_LENGTH;
	constexpr usize TREE_LAYERS = 7;

	namespace internal
	{
		constexpr i32 calculateTotalNodeLength() {
			i32 currentVal = TREE_NODE_LENGTH;

			for (usize i = 1; i < TREE_LAYERS; i++) {
				currentVal *= static_cast<i32>(TREE_NODE_LENGTH);
			}
			return currentVal;
		}
	}

	/**
	* The amount of nodes required on a single dimension to fit the entire tree.
	* Can be thought of as the amount of chunks long/wide/tall the tree is.
	*/
	constexpr i32 TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE = internal::calculateTotalNodeLength();


	struct TreeDepthIndices {
		constexpr TreeDepthIndices() : value(0) {}
		TreeDepthIndices(const TreeDepthIndices&) = default;
		TreeDepthIndices(TreeDepthIndices&&) = default;
		TreeDepthIndices& operator = (const TreeDepthIndices&) = default;
		TreeDepthIndices& operator = (TreeDepthIndices&&) = default;

		/**
		* Gets the specific node index at a given tree layer.
		*
		* @param layer: Node layer as an array index. Value ranging from 0 - 6 (inclusive)
		* @return The index of the node in the tree layer. Ranges from 0 - 511 (inclusive).
		*/
		constexpr u16 indexAtLayer(u8 layer) const {
			check_message(layer < TREE_LAYERS, "depth must be less than world::TREE_LAYERS");

			constexpr usize BITSHIFT_MULTIPLY = 9;
			constexpr usize bitmask = TREE_NODES_PER_LAYER - 1;

			const usize bitShift = static_cast<usize>(layer) * BITSHIFT_MULTIPLY;
			const u16 index = (this->value >> bitShift) & bitmask;
			return  index;
		}

		/**
		* Sets the indices up to `count` given a pointer and a range within it.
		* Assumes that indices[count - 1] is a valid index.
		*
		* @param nodeIndices: Pointer to indices. Every value must be less than world::TREE_NODES_PER_LAYER
		* @param count: Number of elements to read from indices as an array. Must be between 0 - 7.
		*/
		constexpr void setIndices(const u16* nodeIndices, usize count) {
			check_message(count <= TREE_LAYERS, "count must be less than or equal to world::TREE_LAYERS");

			constexpr usize BITSHIFT_MULTIPLY = 9;
			usize newValue = 0;
			for (usize i = 0; i < count; i++) {
				check_message(nodeIndices[i] < TREE_NODES_PER_LAYER, "Tree Index cannot exceed world::TREE_NODES_PER_LAYER");
				const usize bitShift = i * BITSHIFT_MULTIPLY;
				newValue |= static_cast<usize>(nodeIndices[i]) << bitShift;
			}
			this->value = newValue;
		}

		/**
		* Set the index at a given layer.
		*
		* @param index: Which node in a tree layer. Value ranging from 0 - 511 (inclusive)
		* @param layer: Which layer in the tree. Value ranging from 0 - 6 (inclusive)
		*/
		constexpr void setIndexAtLayer(u16 index, u8 layer) {
			check_message(layer < TREE_LAYERS, "depth must be less than world::TREE_LAYERS");
			check_message(index < TREE_NODES_PER_LAYER, "Tree Index cannot exceed world::TREE_NODES_PER_LAYER");

			constexpr usize BITSHIFT_MULTIPLY = 9; 
			const usize bitShift = static_cast<usize>(layer) * BITSHIFT_MULTIPLY;
			const usize mask = ~(static_cast<usize>((TREE_NODES_PER_LAYER - 1)) << bitShift);

			this->value = (this->value & mask) | (static_cast<usize>(index) << bitShift);
		}

		/**
		* Get the internal value used to store the indices and depth.
		* 
		* Layout:
		* 
		* Bits 0 - 8 = Layer 0 node index
		* Bits 9 - 17 = Layer 1 node index
		* Bits 18 - 26 = Layer 2 node index
		* Bits 27 - 35 = Layer 3 node index
		* Bits 36 - 44 = Layer 4 node index
		* Bits 45 - 53 = Layer 5 node index
		* Bits 54 - 62 = Layer 6 node index
		*/
		constexpr usize getInternalValue() const { return value; }

		constexpr bool operator==(const TreeDepthIndices& other) const {
			return value == other.value;
		}

	private:

		usize value;
	};

} // namespace world