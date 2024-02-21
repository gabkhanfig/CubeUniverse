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

	struct BlockFacing;
	struct BlockIndex;
	struct BlockPosition;
	struct WorldPosition;

	struct BlockFacing {
		u8 down : 1 = false;
		u8 up : 1 = false;
		u8 north : 1 = false;
		u8 south : 1 = false;
		u8 east : 1 = false;
		u8 west : 1 = false;
	};

	struct BlockIndex {
		u16 index;

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

	struct BlockPosition {
		i64 x = 0;
		i64 y = 0;
		i64 z = 0;

		constexpr BlockIndex asBlockIndex() const {
			this->validateSelf();

			const u16 relativeX = static_cast<u16>(this->x % CHUNK_LENGTH);
			const u16 relativeY = static_cast<u16>(this->y % CHUNK_LENGTH);
			const u16 relativeZ = static_cast<u16>(this->z % CHUNK_LENGTH);

			return BlockIndex(relativeX, relativeY, relativeZ);
		}

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

		static constexpr BlockPosition fromTreeIndices(const TreeLayerIndices indices) {
			if (std::is_constant_evaluated()) {
				BlockPosition pos;
				for (usize i = 0; i < TreeLayerIndices::LAYERS; i++) {
					const i64 multiplier = internal::calculateLayerMultiplier(i);
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

		constexpr glm::dvec3 asVector() const;

		static constexpr BlockPosition fromVector(const glm::dvec3 vec);

		constexpr BlockPosition adjacent(const BlockFacing direction) const;

	private:

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


} // namespace world