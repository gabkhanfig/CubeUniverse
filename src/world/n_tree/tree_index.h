#pragma once

#include <core.h>
#include <gk_types_lib/option/option.h>

namespace world
{
	constexpr u16 TREE_NODE_LENGTH = 16;
	constexpr u16 TREE_NODES_PER_LAYER = TREE_NODE_LENGTH * TREE_NODE_LENGTH * TREE_NODE_LENGTH;
	constexpr usize TREE_LAYERS = 5;

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
		TreeDepthIndices() : value(0) {}
		TreeDepthIndices(const TreeDepthIndices&) = default;
		TreeDepthIndices(TreeDepthIndices&&) = default;
		TreeDepthIndices& operator = (const TreeDepthIndices&) = default;
		TreeDepthIndices& operator = (TreeDepthIndices&&) = default;

		/**
		* How many layers deep are the indices valid.
		* 
		* @return Value from 0 - 5 (inclusive)
		*/
		u8 len() const;

		/**
		* Gets the specific node index at a given tree layer.
		* Ranges from 0 - 4095 (inclusive). If `depth` is out of range, will be a None option.
		* 
		* @param depth: Node layer as an array index. Value ranging from 0 - 4 (inclusive)
		* @return Some containing the index, or None if the depth is out of range.
		*/
		gk::Option<u16> indexAtDepth(u8 depth) const;

		/**
		* Sets the indices and total depth given a pointer and a range within it.
		* Assumes that indices[count] is a valid index.
		* 
		* @param nodeIndices: Pointer to indices. Every value must be less than world::TREE_NODES_PER_LAYER
		* @param count: Number of elements to read from indices as an array. Must be between 0 - 5.
		*/
		void setIndices(const u16* nodeIndices, usize count);

		/**
		* Forcefully set the length (number of layers referenced) of the tree indices. Assumes that all indices up to `newDepth` are valid.
		*
		* @param newDepth: Value ranging from 0 - 5 (inclusive)
		*/
		void unsafeSetDepth(u8 newDepth);

		/**
		* Forcefully set the index at a given depth. See `unsafeSetDepth()` for manually
		* setting the depth of the tree indices.
		* 
		* @param nodeIndex: Specific node in a tree layer. Value ranging from 0 - 4095 (inclusive)
		* @param depth: Specific layer in the tree as array index. Value ranging from 0 - 4 (inclusive)
		*/
		void unsafeSetIndexAtDepth(u16 nodeIndex, u8 depth);

		/**
		* Get the internal value used to store the indices and depth.
		* 
		* Layout:
		* 
		* Bits 0 - 11 = Layer 0 node index
		* Bits 12 - 23 = Layer 1 node index
		* Bits 24 - 35 = Layer 2 node index
		* Bits 36 - 47 = Layer 3 node index
		* Bits 48 - 59 = Layer 4 node index
		* Bits 60 - 63 = Number of layers stored
		*/
		usize getInternalValue() const { return value; }

		bool operator==(const TreeDepthIndices& other) const {
			return value == other.value;
		}

	private:

		usize value;
	};

} // namespace world