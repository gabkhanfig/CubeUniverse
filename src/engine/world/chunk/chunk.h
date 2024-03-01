#pragma once

#include "block_state_indices.h"
#include <gk_types_lib/sync/rw_lock.h>
#include <gk_types_lib/array/array_list.h>

namespace world {

	struct BlockBreakingProgress {
		float progress;
		BlockIndex position;
	};

	struct FatTree;

	/// Thread safe wrapper around the actual `Inner` data.
	/// Owns `CHUNK_SIZE` blocks within, and uses an RwLock for multithread access.
	/// Call `read()`, `tryRead()`, `write()`, or `tryWrite()`.
	struct alignas(64) Chunk {
		struct Inner {
		private:

			friend struct Chunk;
			friend struct gk::RwLock<Inner>;

			Inner(FatTree& inTree, TreeLayerIndices inPos);

		public:

			Inner(const Inner&) = delete;
			Inner(Inner&&) = delete;
			Inner& operator = (const Inner&) = delete;
			Inner& operator = (Inner&&) = delete;

			~Inner();
			
		private:

			static constexpr u16 DEFAULT_BLOCK_STATE_CAPACITY = 2;
			using BlockState = usize; // TODO actual block state

			/// Allows immediately going to the head of the tree that owns this chunk.
			/// The lifetime of `_tree` is guaranteed to exceed the lifetime of the chunk
			/// due to the ownership.
			FatTree& _tree;
			/// Will always be a valid pointer of a length of 1 or more.
			/// The first entry is the state of an air block, meaning that initializing _blockStateIds to all 0's
			/// means the chunk is full of air.
			BlockState* _blockStatesData;
			/// Will always be non-zero
			u16 _blockStatesLen = 1;
			/// Will always be non-zero
			u16 _blockStatesCapacity = DEFAULT_BLOCK_STATE_CAPACITY;
			/// Position of this chunk within the FatTree.
			const TreeLayerIndices _treePos;
			/// Holds which index each block in the chunk is using as a reference to it's block state.
			/// This allows multiple blocks to reference the same block state.
			internal::BlockStateIndices _blockStateIds;
			/// CAN BE NULL when no blocks are being broken in the chunk.
			/// It's overwhelmingly likely that no block is being broken in
			/// any given chunk, so storing the extra data would be a waste of memory.
			gk::ArrayList<BlockBreakingProgress>* _breakingProgress = nullptr;

		};

		Chunk(FatTree& inTree, TreeLayerIndices inPos);

		~Chunk();

		/// Get read-only access to the chunk's inner data.
		/// Will wait until no thread has exclusive access to the lock.
		gk::LockedReader<Inner> read() const;

		/// Try to get read-only access to the chunk's inner data.
		/// Returns either the chunk data, or nothing if another thread has exclusive access to the lock.
		gk::Option<gk::LockedReader<Inner>> tryRead() const;

		/// Get read-write access to the chunk's inner data.
		/// Will wait until no thread has exclusive or shared access to the lock.
		gk::LockedWriter<Inner> write();

		/// Try to get read-write access to the chunk's inner data.
		/// Returns either the chunk data, or nothing if another thread has exclusive or shared access to the lock.
		gk::Option<gk::LockedWriter<Inner>> tryWrite();

		/// Get readonly access to the chunk's inner data in a way that does not require locking.
		/// In development builds, asserts that no other thread has exclusive access.
		const Inner* unsafeRead() const;

	private:

		gk::RwLock<Inner> _inner;

	};

} // namespace world