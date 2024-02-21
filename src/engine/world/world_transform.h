#pragma once

#include "../core.h"
#include <glm/glm.hpp>
#include "fat_tree/tree_layer_indices.h"

namespace world {
	namespace internal {
		constexpr u64 calculateLayerMultiplier(const usize layer) {
			u64 out = 1;
			for (usize i = layer; i < TreeLayerIndices::LAYERS; i++) {
				out *= TreeLayerIndices::NODE_LENGTH;
			}
			return out;
		}

		constexpr TreeLayerIndices::Index calculateLayerIndex(const usize layer, const u64 xShifted, const u64 yShifted, const u64 zShifted) {
			check_lt(layer, TreeLayerIndices::LAYERS);

			const u64 div = calculateLayerMultiplier(layer);

			const u8 normalizedX = static_cast<u8>(((xShifted % div) * TreeLayerIndices::NODE_LENGTH) / div);
			const u8 normalizedY = static_cast<u8>(((yShifted % div) * TreeLayerIndices::NODE_LENGTH) / div);
			const u8 normalizedZ = static_cast<u8>(((zShifted % div) * TreeLayerIndices::NODE_LENGTH) / div);

			return TreeLayerIndices::Index::init(normalizedX, normalizedY, normalizedZ);
		}
	}

	/// Number of blocks long / wide / tall a chunk is.
	constexpr i64 CHUNK_LENGTH = 32;
	/// Number of blocks in a chunk.
	constexpr i64 CHUNK_SIZE = CHUNK_LENGTH * CHUNK_LENGTH * CHUNK_LENGTH;
	/// Total number of blocks long / wide / tall the entire world is.
	constexpr i64 WORLD_BLOCK_LENGTH = static_cast<i64>(TreeLayerIndices::TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE) * CHUNK_LENGTH;
	/// Maximum position a block can exist at.
	constexpr i64 WORLD_MAX_BLOCK_POS = WORLD_BLOCK_LENGTH / 2 - 1;
	/// Minimum position a block can exist at.
	constexpr i64 WORLD_MIN_BLOCK_POS = WORLD_MAX_BLOCK_POS - WORLD_BLOCK_LENGTH + 1;

	/// Facing direction of a block. Locked to 6 cube faces.
	/// - Size = 1 byte
	/// - Align = 1 byte
	struct BlockFacing {
		u8 down : 1 = false;
		u8 up : 1 = false;
		u8 north : 1 = false;
		u8 south : 1 = false;
		u8 east : 1 = false;
		u8 west : 1 = false;
	};

	/// Position of a block within a chunk,
	/// x has a factor of 1
	/// z has a factor of world::CHUNK_LENGTH
	/// y has a factor of world::CHUNK_LENGTH * world::CHUNK_LENGTH
	/// - Size = 2 bytes
	/// - Align = 2 bytes
	struct BlockIndex {
		u16 index; // TODO maybe bit shifting will work instead of division?

		constexpr BlockIndex() : index(0) {};

		constexpr BlockIndex(u16 inX, u16 inY, u16 inZ) {
			check_lt(inX, CHUNK_LENGTH);
			check_lt(inY, CHUNK_LENGTH);
			check_lt(inZ, CHUNK_LENGTH);
			this->index = inX + (inZ * CHUNK_LENGTH) + (inY * CHUNK_LENGTH * CHUNK_LENGTH);
		}

		constexpr u16 x() const {
			return this->index % CHUNK_LENGTH;
		}

		constexpr u16 y() const {
			return this->index / (CHUNK_LENGTH * CHUNK_LENGTH);
		}

		constexpr u16 z() const {
			return (this->index % (CHUNK_LENGTH * CHUNK_LENGTH)) / CHUNK_LENGTH;
		}

		constexpr bool isOnChunkEdge() const {
			const u16 xCoord = this->x();
			const u16 yCoord = this->y();
			const u16 zCoord = this->z();

			const bool xEdge = (xCoord == 0) || (xCoord == (CHUNK_LENGTH - 1));
			const bool yEdge = (yCoord == 0) || (yCoord == (CHUNK_LENGTH - 1));
			const bool zEdge = (zCoord == 0) || (zCoord == (CHUNK_LENGTH - 1));
			return xEdge || yEdge || zEdge;
		}
	};

	/// Integer position of a block within the world bounds,
	/// specifying the chunk the block is in, and where within the chunk it is.
	/// Each x y z component will be between world::WORLD_MAX_BLOCK_POS and world::WORLD_MIN_BLOCK_POS.
	/// - Size = 24 bytes
	/// - Align = 8 bytes
	struct BlockPosition {
		i64 x = 0;
		i64 y = 0;
		i64 z = 0;

		/// Convert this `BlockPosition` into it's corresponding `BlockIndex`,
		/// without specifying where in the FatTree structure the block is (doesn't specify which chunk).
		/// Asserts that x y z components are within the inclusive range of `world::WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
		constexpr BlockIndex asBlockIndex() const {
			this->validateSelf();
			
			// positive modulo
			const u16 relativeX = static_cast<u16>((this->x % CHUNK_LENGTH + CHUNK_LENGTH) % CHUNK_LENGTH);
			const u16 relativeY = static_cast<u16>((this->y % CHUNK_LENGTH + CHUNK_LENGTH) % CHUNK_LENGTH);
			const u16 relativeZ = static_cast<u16>((this->z % CHUNK_LENGTH + CHUNK_LENGTH) % CHUNK_LENGTH);

			return BlockIndex(relativeX, relativeY, relativeZ);
		}

		/// Convert this `BlockPosition` into the indices of each layer of the FatTree.
		/// Functionally the same as the position of a chunk, without the `BlockIndex`.
		/// Asserts that x y z components are within the inclusive range of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
		constexpr TreeLayerIndices asTreeIndices() const {
			this->validateSelf();

			if (std::is_constant_evaluated()) {
				const u64 normalizedX = static_cast<u64>(this->x + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH;
				const u64 normalizedY = static_cast<u64>(this->y + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH;
				const u64 normalizedZ = static_cast<u64>(this->z + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH;

				TreeLayerIndices indices;
				for (usize i = 0; i < TreeLayerIndices::LAYERS; i++) {
					indices.setIndexAtLayer(i, internal::calculateLayerIndex(i, normalizedX, normalizedY, normalizedZ));
				}
				return indices;
			}
			else {
				return asTreeIndicesRuntime();
			}	
		}

		/// Does not hold any information on which `BlockIndex` is used.
		/// Each component is effectively clamped to increments of `world::CHUNK_LENGTH`.
		static constexpr BlockPosition fromTreeIndices(const TreeLayerIndices indices) {
			if (std::is_constant_evaluated()) {
				BlockPosition pos;
				for (usize i = 0; i < TreeLayerIndices::LAYERS; i++) {
					const i64 multiplier = internal::calculateLayerMultiplier(i) / TreeLayerIndices::NODE_LENGTH;
					const auto index = indices.indexAtLayer(i);

					pos.x += (multiplier * index.x());
					pos.y += (multiplier * index.y());
					pos.z += (multiplier * index.z());
				}
				
				pos.x *= CHUNK_LENGTH;
				pos.y *= CHUNK_LENGTH;
				pos.z *= CHUNK_LENGTH;

				pos.x -= WORLD_MAX_BLOCK_POS + 1;
				pos.y -= WORLD_MAX_BLOCK_POS + 1;
				pos.z -= WORLD_MAX_BLOCK_POS + 1;

				return pos;
			}
			else {
				return fromTreeIndicesRuntime(indices);
			}
		}

		/// Gets this `BlockPosition` as a vector of 64 bit float coordinates
		constexpr glm::dvec3 asVector() const {
			return glm::dvec3(static_cast<double>(this->x), static_cast<double>(this->y), static_cast<double>(this->z));
		}

		/// Convert a vector of 64 bit float coordinates to a `BlockPosition`.
		static constexpr BlockPosition fromVector(const glm::dvec3 vec) {
			return BlockPosition{ .x = static_cast<i64>(vec.x), .y = static_cast<i64>(vec.y), .z = static_cast<i64>(vec.z) };
		}

		/// Get the position adjacent to this one at a specific direction.
		constexpr BlockPosition adjacent(const BlockFacing direction) const {
			BlockPosition newPos = *this;
			if (direction.down) newPos.y -= 1;
			if (direction.up) newPos.y += 1;
			if (direction.north) newPos.z -= 1;
			if (direction.south) newPos.z += 1;
			if (direction.east) newPos.x -= 1;
			if (direction.south) newPos.x += 1;
			return newPos;
		}

		constexpr bool operator==(const BlockPosition& other) const {
			return this->x == other.x && this->y == other.y && this->z == other.z;
		}

	private:

		friend struct WorldPosition;

		constexpr void validateSelf() const {
			check_le(this->x, WORLD_MAX_BLOCK_POS);
			check_ge(this->x, WORLD_MIN_BLOCK_POS);
			check_le(this->y, WORLD_MAX_BLOCK_POS);
			check_ge(this->y, WORLD_MIN_BLOCK_POS);
			check_le(this->z, WORLD_MAX_BLOCK_POS);
			check_ge(this->z, WORLD_MIN_BLOCK_POS);
		}

		TreeLayerIndices asTreeIndicesRuntime() const;

		static BlockPosition fromTreeIndicesRuntime(const TreeLayerIndices indices);

};

	/// Position of anything within the `FatTree` structure.
	/// Internally uses `TreeLayerIndices` to specify which chunk it is in,
	/// and then a 32 bit 3 component float `vec3` for where within the chunk.
	/// This structure can be used on the GPU.
	/// - Size = 24 bytes
	/// - Align = 4 bytes
	/// - field `treePosition` byte offset = 0
	/// - field `offset` byte offset = 12
	struct WorldPosition {
		TreeLayerIndices treePosition;
		/// Represents the offset within a chunk, on the same scale as a block. Every 1 unit is 1 block.
		/// Each component of the vector must be between the range of `component >= 0` and `component < CHUNK_LENGTH`
		/// (0 is inclusive, and `CHUNK_LENGTH` is exclusive).
		glm::vec3 offset;

		constexpr WorldPosition() : offset(glm::vec3(0, 0, 0)) {
			constexpr BlockPosition bposZeroes = BlockPosition{ .x = 0, .y = 0, .z = 0 };
			constexpr TreeLayerIndices treePos = bposZeroes.asTreeIndices();
			this->treePosition = treePos;
		}

		/// Get the index of a block in a chunk that this `WorldPosition` is at. Uses flooring.
		constexpr BlockIndex asBlockIndex() const {
			this->validateSelf();

			return BlockIndex(static_cast<u16>(this->offset.x), static_cast<u16>(this->offset.y), static_cast<u16>(this->offset.z));
		}

		/// Convert the position of a block to a `WorldPosition`
		static constexpr WorldPosition fromBlockPosition(const BlockPosition& pos) {
			pos.validateSelf();

			const auto treePos = pos.asTreeIndices();
			const auto blockIndex = pos.asBlockIndex();
			const auto blockOffset = glm::vec3(static_cast<float>(blockIndex.x()), static_cast<float>(blockIndex.y()), static_cast<float>(blockIndex.z()));

			WorldPosition wpos;
			wpos.treePosition = treePos;
			wpos.offset = blockOffset;
			return wpos;
		}

		/// Get the position of a block that this `WorldPosition` is at.  Floors the `offset`.
		constexpr BlockPosition asBlockPosition() const {
			this->validateSelf();

			BlockPosition asbpos = BlockPosition::fromTreeIndices(this->treePosition);
			asbpos.x += static_cast<i64>(this->offset.x);
			asbpos.y += static_cast<i64>(this->offset.y);
			asbpos.z += static_cast<i64>(this->offset.z);
			return asbpos;
		}

		/// Convert a vector of 64 bit float coordinates to a `WorldPosition`.
		static constexpr WorldPosition fromVector(const glm::dvec3 pos) {
			// less than +1 to go to the edge of the block
			check_lt(pos.x, WORLD_MAX_BLOCK_POS + 1); 
			check_ge(pos.x, WORLD_MIN_BLOCK_POS);
			check_lt(pos.y, WORLD_MAX_BLOCK_POS + 1); 
			check_ge(pos.y, WORLD_MIN_BLOCK_POS);
			check_lt(pos.z, WORLD_MAX_BLOCK_POS + 1); 
			check_ge(pos.z, WORLD_MIN_BLOCK_POS);

			WorldPosition wpos;
			wpos.treePosition = BlockPosition::fromVector(pos).asTreeIndices();;
			wpos.offset = glm::vec3(static_cast<float>(pos.x), static_cast<float>(pos.y), static_cast<float>(pos.z));;
			return wpos;
		}

		/// Gets this `WorldPosition` as a vector of 64 bit float coordinates
		constexpr glm::dvec3 asVector() const {
			this->validateSelf();

			const BlockPosition asbpos = BlockPosition::fromTreeIndices(this->treePosition);
			glm::dvec3 treePosVec = asbpos.asVector();

			treePosVec.x += static_cast<double>(this->offset.x);
			treePosVec.y += static_cast<double>(this->offset.y);
			treePosVec.z += static_cast<double>(this->offset.z);
			return treePosVec;
		}

		constexpr bool operator==(const WorldPosition& other) const {
			return this->treePosition == other.treePosition && this->offset == other.offset;
		}

	private:

		constexpr void validateSelf() const {
			check_lt(this->offset.x, CHUNK_LENGTH);
			check_ge(this->offset.x, 0.0);
			check_lt(this->offset.y, CHUNK_LENGTH);
			check_ge(this->offset.y, 0.0);
			check_lt(this->offset.z, CHUNK_LENGTH);
			check_ge(this->offset.z, 0.0);
		}

		
	};


} // namespace world