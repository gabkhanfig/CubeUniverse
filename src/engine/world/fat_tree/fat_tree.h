#pragma once

#include "../../core.h"
#include "../world_transform.h"
#include <gk_types_lib/sync/rw_lock.h>
#include <gk_types_lib/allocator/allocator.h>
#include <gk_types_lib/hash/hashmap.h>
#include "../../types/color.h"

namespace world {

	struct Chunk;
	struct FatTreeLayer;
	struct FatTreeNoodle;

	struct FatTreeNode {
	private:

		static constexpr usize PTR_MASK = 0x0000FFFFFFFFFFFF;
		static constexpr usize TYPE_MASK = 0xFFFF000000000000;
		static constexpr usize TYPE_SHIFT = 48;

	public: 

		enum class Type : usize {
			empty = 0,
			childLayer = 1ULL << TYPE_SHIFT,
			noodleLayer = 2ULL << TYPE_SHIFT,
			chunk = 3ULL << TYPE_SHIFT,
		};

		/// Basically just destructor but explicit and allow removing chunks from the
		/// loaded chunks hashmap.
		void deinit();

		Type nodeType() const;

		/// Asserts that `nodeType() == Type::childLayer`.
		FatTreeLayer& childLayer();

		/// Asserts that `nodeType() == Type::childLayer`.
		const FatTreeLayer& childLayer() const;

		/// This is const qualified because the chunk itself has specific 
		/// thread safe access to it's data.
		/// Asserts that `nodeType() == Type::chunk`.
		Chunk& chunk() const;

		/// Asserts that `nodeType() == Type::noodleLayer`.
		FatTreeNoodle& noodleLayer();

		/// Asserts that `nodeType() == Type::noodleLayer`.
		const FatTreeNoodle& noodleLayer() const;

	private:

		usize value = static_cast<usize>(Type::empty);

	};

	/// Structure representing an entire world state.
	/// It's similar to an octree, but instead of being 2x2x2, it's 4x4x4.
	/// `FatTree` instance's will always have a consistent memory address,
	/// so storing a reference to it is safe as long as the object's lifetime is
	/// guaranteed to never exceed the lifetime of the `FatTree`.
	///
	/// The `FatTree`'s data can be accessed in two distinct ways.
	/// - Chunk modification only
	/// - Full tree modification
	///
	/// With chunk-only modification, chunks/layers/nodes cannot be added,
	/// removed, or anything else from the tree. The only thing permitted
	/// are read/write operations on the data chunks own. The chunks naturally
	/// have to be appropriately locked. This `FatTree` locking mode allows multiple
	/// threads to have shared access to the chunks, and reading the state of the tree.
	///
	/// With full tree modification, the entire tree can be modified freely through
	/// the use of exclusive locking.
	struct FatTree {

		struct Inner {

			Inner() = default;

			~Inner();

			/// This is const qualified because the chunk itself has specific 
			/// thread safe access to it's data.
			gk::Option<Chunk&> chunkAt(const TreeLayerIndices position) const;

		private:

			FatTreeNode topNode;
			gk::HashMap<TreeLayerIndices, Chunk*> chunks;
		};

		/// Wrapper around `FatTree` that only permits mutation operations on Chunks,
		/// and reading the state of the `FatTree`. The nodes/layers cannot be modified.
		/// Uses shared locking. In order to mutate a chunk, it will also need to have it's
		/// lock acquired accordingly.
		using ChunkModifyGuard = gk::LockedReader<Inner>;

		/// Wrapper around `FatTree` that permits full mutation on the tree structure.
		/// Uses exclusive locking.
		using TreeModifyGuard = gk::LockedWriter<Inner>;

		/// Acquire a shared lock that permits only mutations on chunks,
		/// not the `FatTree` itself. Chunks will naturally need to be locked accordingly.
		/// @return An acquired shared lock
		ChunkModifyGuard lockChunkModify() const;

		/// Try to acquire a shared lock that permits only mutations on chunks,
		/// not the `FatTree` itself. Chunks will naturally need to be locked accordingly.
		/// @return An acquired shared lock, or nothing if it couldn't be locked.
		gk::Option<ChunkModifyGuard> tryLockChunkModify() const;

		/// Acquire an exclusive lock that permits full mutation on the `FatTree`.
		/// Chunks will naturally need to be locked accordingly.
		/// @return An acquired exclusive lock
		TreeModifyGuard lockTreeModify();

		/// Acquire an exclusive lock that permits full mutation on the `FatTree`.
		/// Chunks will naturally need to be locked accordingly.
		/// @return An acquired exclusive lock, or nothing if it couldn't be locked.
		gk::Option<TreeModifyGuard> tryLockTreeModify();

	private:

		gk::RwLock<Inner> inner;

	};

	struct FatTreeLayer {

		static FatTreeNoodle init(gk::AllocatorRef inAllocator, const u8 inLayer);

		void deinit();

	private:

		gk::AllocatorRef allocator;
		u8 treeLayer;
		FatTreeNode nodes[TreeLayerIndices::NODES_PER_LAYER];
	};

	/// Wraps a fat tree layer that's more than 1 layer deeper than the owning layer.
	/// Works similar to a DAG, allowing drastically less memory accesses.
	struct FatTreeNoodle {

		static FatTreeNoodle init(gk::AllocatorRef allocator, const TreeLayerIndices indices, const u8 layerStart, const u8 layerEnd);

		void deinit();

	private:

		/// Size = 16 bytes, align = 1 byte
		struct NoodleJump {
			/// Corresponds to TreeLayerIndices::Index
			TreeLayerIndices::Index indices[TreeLayerIndices::LAYERS] = { 0 };
			/// 0 - 15 for all tree layers
			u8 jumpStart : 4 = 0;
			/// 0 - 15 for all tree layers
			u8 jumpEnd : 4 = 0;
		};

		FatTreeLayer layer;
		NoodleJump jump;

	};
}