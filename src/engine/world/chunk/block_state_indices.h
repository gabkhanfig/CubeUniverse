#pragma once

#include "../world_transform.h"

namespace world {
	namespace internal {

		/// Structure containing the indices of different block states within a chunk
		/// Uses custom bit-widths to compress the used memory as aggressively as possible.
		/// Uses more memory for more unique block states that a chunk owns.
		/// Call `reserve()` to be able to hold more block states. All indices are set to 0, to be an empty block state.
		///
		/// The size is 8 bytes for the `BlockStateIndices` itself, and then depending on the number of unique block states:
		/// - Up to 2 => 4096 bytes
		/// - Up to 4 => 8192 bytes
		/// - Up to 16 => 16384 bytes
		/// - Up to 256 => 32768 bytes
		/// - Up to CHUNK_SIZE (max) => 65536 bytes
		struct BlockStateIndices {

			BlockStateIndices();

			~BlockStateIndices();

			BlockStateIndices(const BlockStateIndices&) = delete;
			BlockStateIndices(BlockStateIndices&&) = delete;
			BlockStateIndices& operator = (const BlockStateIndices&) = delete;
			BlockStateIndices& operator = (BlockStateIndices&&) = delete;

			/// Get the index of the block state referenced by the block at `position`.
			u16 indexAt(const BlockIndex position) const;

			/// Set the index of the block state referenced by the block at `position`.
			/// Asserts that the current indices bit width can support `index`.
			/// To change the bit width, see `reserve()`.
			void setIndexAt(const u16 index, const BlockIndex position);

			/// Reserves this `BlockStateIndices` to use the smallest
			/// amount of memory required to fit up to `uniqueBlockStates` as a valid index.
			/// Does not shrink the memory usage. Will copy over the existing indices.
			void reserve(const u16 uniqueBlockStates);

		private:

			enum class IndexBitWidth : usize { b1 = 0, b2 = 1, b4 = 2, b8 = 3, b16 = 4 };

			static constexpr usize PTR_MASK = 0xFFFFFFFFFFFF;
			static constexpr usize ENUM_SHIFT = 48;

			IndexBitWidth getTag() const;

			const void* getIndicesPtr() const;

			void* getIndicesPtrMut();

			IndexBitWidth getRequiredBitWidth(const u16 uniqueBlockStates) const;

			bool shouldReallocate(const u16 uniqueBlockStates) const;

			void reallocate(const u16 uniqueBlockStates);

			usize taggedPtr;

		};

		struct BlockStateIndicesWidth1 {
			static constexpr usize ARRAY_SIZE = CHUNK_SIZE / 64; // 1 bit per block, 2 possible values
			static constexpr u16 MAX_VALUE = 0b1;

			usize indices[ARRAY_SIZE];

			BlockStateIndicesWidth1() : indices{ 0 } {}
			u16 indexAt(const BlockIndex position) const;
			void setIndexAt(const u16 index, const BlockIndex position);
		};

		struct BlockStateIndicesWidth2 {
			static constexpr usize ARRAY_SIZE = CHUNK_SIZE / (64 / 2); // 2 bits per block, 4 possible values
			static constexpr u16 MAX_VALUE = 0b11;
			static constexpr usize BIT_INDEX_MASK = 31;
			static constexpr usize BIT_INDEX_MULTIPLIER = 2;

			usize indices[ARRAY_SIZE];

			BlockStateIndicesWidth2() : indices{ 0 } {}
			u16 indexAt(const BlockIndex position) const;
			void setIndexAt(const u16 index, const BlockIndex position);
		};

		struct BlockStateIndicesWidth4 {
			static constexpr usize ARRAY_SIZE = CHUNK_SIZE / (64 / 4); // 4 bits per block, 16 possible values
			static constexpr u16 MAX_VALUE = 0b1111;
			static constexpr usize BIT_INDEX_MASK = 15;
			static constexpr usize BIT_INDEX_MULTIPLIER = 4;

			usize indices[ARRAY_SIZE];

			BlockStateIndicesWidth4() : indices{ 0 } {}
			u16 indexAt(const BlockIndex position) const;
			void setIndexAt(const u16 index, const BlockIndex position);
		};

		struct BlockStateIndicesWidth8 {
			static constexpr u16 MAX_VALUE = 0b11111111;

			u8 indices[CHUNK_SIZE];

			BlockStateIndicesWidth8() : indices{ 0 } {}
			u16 indexAt(const BlockIndex position) const;
			void setIndexAt(const u16 index, const BlockIndex position);
		};

		struct BlockStateIndicesWidth16 {

			u16 indices[CHUNK_SIZE];

			BlockStateIndicesWidth16() : indices{ 0 } {}
			u16 indexAt(const BlockIndex position) const;
			void setIndexAt(const u16 index, const BlockIndex position);
		};

	} // namespace internal
} // namespace world