#pragma once

#include <core.h>
#include <gk_types_lib/sync/rw_lock.h>
#include "chunk_data.h"
#include <engine/types/light.h>
#include <world/n_tree/tree_index.h>

namespace world
{
	/** 
	* The ACTUAL data of the chunk.
	*/
	struct ChunkInner
	{
		ChunkInner(TreeDepthIndices inTreePos);




	private:
		/**
		* The index into the `blockStates` array corresponding to a specific block within a chunk.
		* Indexing this array should be done using the world::BlockPos struct.
		* Is 64 byte aligned to allow for SIMD operations.
		*/
		alignas(64) u16 _blockStateIds[CHUNK_SIZE];

		/**
		* The light level of a specific block within a chunk.
		* Indexing this array should be done using the world::BlockPos struct.
		* Is 64 byte aligned to allow for SIMD operations.
		*/
		alignas(64) BlockLight _light[CHUNK_SIZE];

		/**
		* The actual different block states within the chunk.
		* Blocks with identical block states will use the same index into this array.
		*/
		gk::ArrayList<void*> _blockStates;

		/**
		* Position within the NTree structure.
		*/
		TreeDepthIndices _treePos;
		
		

		
	};


	/**
	* Thread-safe wrapper around the chunk's data.
	* Uses RwLock internally. 
	* When constructing GPU data, the chunk data will be only read, not written to.
	* Using RwLock makes it extremely easy for multiple threads to create GPU data without conflict.
	*/
	struct Chunk 
	{
		Chunk() = default;
		~Chunk() = default;

		[[nodiscard]] gk::LockedReader<ChunkInner> read() const {
			return inner.read();
		}

		[[nodiscard]] gk::Option<gk::LockedReader<ChunkInner>> tryRead() const {
			return inner.tryRead();
		}

		[[nodiscard]] gk::LockedWriter<ChunkInner> write() {
			return inner.write();
		}

		[[nodiscard]] gk::Option<gk::LockedWriter<ChunkInner>> tryWrite() {
			return inner.tryWrite();
		}

	private:
		gk::RwLock<ChunkInner> inner;
	};


}