#pragma once

#include <core.h>
#include "chunk/chunk_data.h"
#include "n_tree/tree_index.h"
#include <glm/glm.hpp>

constexpr int floorIntDivide(int dividend, int divisor) {
	int d = dividend / divisor;
	return d * divisor == dividend ? d : d - ((dividend < 0) ^ (divisor < 0));
}

namespace world
{
	/**
	* The amount of blocks long/wide/tall the entire world is.
	*/
	constexpr i32 WORLD_BLOCK_LENGTH = TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE * CHUNK_LENGTH;
	constexpr i32 WORLD_MAX_BLOCK_POS = WORLD_BLOCK_LENGTH / 2 - 1;
	constexpr i32 WORLD_MIN_BLOCK_POS = WORLD_MAX_BLOCK_POS - WORLD_BLOCK_LENGTH + 1;

	namespace internal
	{
		template<u8 layer>
		constexpr inline u16 calculateLayerIndex(i32 xShiftedPositive, i32 yShiftedPositive, i32 zShiftedPositive) {
			static_assert(layer < TREE_LAYERS, "layer cannot exceed TREE_LAYERS");

			if constexpr (layer == 0) {
				const u16 normalizedX = static_cast<u16>((xShiftedPositive * TREE_NODE_LENGTH) / WORLD_BLOCK_LENGTH);
				const u16 normalizedY = static_cast<u16>((yShiftedPositive * TREE_NODE_LENGTH) / WORLD_BLOCK_LENGTH);
				const u16 normalizedZ = static_cast<u16>((zShiftedPositive * TREE_NODE_LENGTH) / WORLD_BLOCK_LENGTH);

				return normalizedX + (normalizedZ * TREE_NODE_LENGTH) + (normalizedY * TREE_NODE_LENGTH * TREE_NODE_LENGTH);
			}
			else {
				constexpr i32 DIV = CHUNK_LENGTH * []() {
					i32 out = 1;
					for (u8 i = 0; i < layer; i++) {
						out *= world::TREE_NODE_LENGTH;
					}
					return out;
				}();

				const u16 normalizedX = static_cast<u16>(((xShiftedPositive % DIV) * TREE_NODE_LENGTH) / DIV);
				const u16 normalizedY = static_cast<u16>(((yShiftedPositive % DIV) * TREE_NODE_LENGTH) / DIV);
				const u16 normalizedZ = static_cast<u16>(((zShiftedPositive % DIV) * TREE_NODE_LENGTH) / DIV);

				return normalizedX + (normalizedZ * TREE_NODE_LENGTH) + (normalizedY * TREE_NODE_LENGTH * TREE_NODE_LENGTH);
			}
		}
	}

	struct BlockFacing
	{
	public:

		enum Direction : u8
		{
			Down = 0b1,
			Up = 0b10,
			North = 0b100,
			South = 0b1000,
			East = 0b10000,
			West = 0b100000
		};

		u8 facing;

		constexpr BlockFacing()
			: facing(0)
		{}

		constexpr BlockFacing(u8 _facing)
			: facing(_facing)
		{}

		constexpr BlockFacing(BlockFacing::Direction direction)
			: facing(direction)
		{}

		constexpr BlockFacing(const BlockFacing& other)
			: facing(other.facing)
		{}

		constexpr void operator = (const u8 bitmask) {
			facing = bitmask;
		}
		
		constexpr void operator = (BlockFacing::Direction direction) {
			facing = direction;
		}

		constexpr void operator = (const BlockFacing& other) {
			facing = other.facing;
		}

		constexpr bool isFacing(u8 direction) const {
			return facing & direction;
		}

		constexpr BlockFacing opposite() const {
			u8 oppositeBits = 0;
			oppositeBits |= (facing & Down) << 1;
			oppositeBits |= (facing & Up) >> 1;
			oppositeBits |= (facing & North) << 1;
			oppositeBits |= (facing & South) >> 1;
			oppositeBits |= (facing & East) << 1;
			oppositeBits |= (facing & West) >> 1;
			return BlockFacing(oppositeBits);
		}
	};

	/**
	* Position of a block within a chunk.
	* x has a favtor of 1.
	* z has a factor of world::CHUNK_LENGTH.
	* y has a factor of world::CHUNK_LENGTH ^ 2.
	*/
	struct BlockPos {
		u16 index;

		constexpr BlockPos() : index(0) {}

		constexpr BlockPos(u16 inIndex) 
			: index(inIndex)
		{
			check_message(inIndex < CHUNK_SIZE, "BlockPos index must be less than world::CHUNK_SIZE. index: ", inIndex);
		}

		constexpr BlockPos(u16 inX, u16 inY, u16 inZ) {
			check_message(inX < CHUNK_LENGTH, "BlockPos x coordinate must be less than world::CHUNK_LENGTH. inX: ", inX);
			check_message(inY < CHUNK_LENGTH, "BlockPos y coordinate must be less than world::CHUNK_LENGTH. inY: ", inY);
			check_message(inZ < CHUNK_LENGTH, "BlockPos z coordinate must be less than world::CHUNK_LENGTH. inZ: ", inZ);
			index = inX + (inZ * CHUNK_LENGTH) + (inY * CHUNK_LENGTH * CHUNK_LENGTH);
		}

		constexpr BlockPos(const BlockPos&) = default;
		constexpr BlockPos(BlockPos&&) = default;
		constexpr BlockPos& operator = (const BlockPos&) = default;
		constexpr BlockPos& operator = (BlockPos&&) = default;

		constexpr void operator = (u16 inIndex) {
			check_message(inIndex < CHUNK_SIZE, "BlockPos index must be less than world::CHUNK_SIZE. index: ", inIndex);
			index = inIndex;
		}

		constexpr bool operator == (const BlockPos& other) const {
			return index == other.index;
		}

		constexpr u16 x() const {
			return index % CHUNK_LENGTH;
		}

		constexpr u16 y() const {
			return index / (CHUNK_LENGTH * CHUNK_LENGTH);
		}

		constexpr u16 z() const {
			return (index % (CHUNK_LENGTH * CHUNK_LENGTH)) / CHUNK_LENGTH;
		}

		constexpr bool isOnChunkEdge() const {
			const bool xEdge = x() == 0 || x() == (CHUNK_LENGTH - 1);
			const bool yEdge = y() == 0 || y() == (CHUNK_LENGTH - 1);
			const bool zEdge = z() == 0 || z() == (CHUNK_LENGTH - 1);
			return xEdge || yEdge || zEdge;
		}
		
	};

	/**
	* Integer position within the world bounds.
	* Each component will be between world::WORLD_MIN_BLOCK_POS and world::WORLD_MAX_BLOCK_POS inclusively.
	*/
	struct WorldPos {
		i32 x;
		i32 y;
		i32 z;

		constexpr WorldPos() : x(0), y(0), z(0) {}

		constexpr WorldPos(i32 inX, i32 inY, i32 inZ) 
			: x(inX), y(inY), z(inZ)
		{
			check_message(inX <= WORLD_MAX_BLOCK_POS, "WorldPos x coordinate must be less than or equal to world::WORLD_MAX_BLOCK_POS. x: ", inX);
			check_message(inY <= WORLD_MAX_BLOCK_POS, "WorldPos y coordinate must be less than or equal to world::WORLD_MAX_BLOCK_POS. y: ", inY);
			check_message(inZ <= WORLD_MAX_BLOCK_POS, "WorldPos z coordinate must be less than or equal to world::WORLD_MAX_BLOCK_POS. z: ", inZ);
			check_message(inX >= WORLD_MIN_BLOCK_POS, "WorldPos x coordinate must be greater than or equal to world::WORLD_MIN_BLOCK_POS. x: ", inX);
			check_message(inY >= WORLD_MIN_BLOCK_POS, "WorldPos y coordinate must be greater than or equal to world::WORLD_MIN_BLOCK_POS. y: ", inY);
			check_message(inZ >= WORLD_MIN_BLOCK_POS, "WorldPos z coordinate must be greater than or equal to world::WORLD_MIN_BLOCK_POS. z: ", inZ);
		}

		constexpr WorldPos(glm::dvec3 pos)
			: x(static_cast<i32>(pos.x)), y(static_cast<i32>(pos.y)), z(static_cast<i32>(pos.z))
		{
			check_message(x <= WORLD_MAX_BLOCK_POS, "WorldPos x coordinate must be less than or equal to world::WORLD_MAX_BLOCK_POS. x: ", x);
			check_message(y <= WORLD_MAX_BLOCK_POS, "WorldPos y coordinate must be less than or equal to world::WORLD_MAX_BLOCK_POS. y: ", y);
			check_message(z <= WORLD_MAX_BLOCK_POS, "WorldPos z coordinate must be less than or equal to world::WORLD_MAX_BLOCK_POS. z: ", z);
			check_message(x >= WORLD_MIN_BLOCK_POS, "WorldPos x coordinate must be greater than or equal to world::WORLD_MIN_BLOCK_POS. x: ", x);
			check_message(y >= WORLD_MIN_BLOCK_POS, "WorldPos y coordinate must be greater than or equal to world::WORLD_MIN_BLOCK_POS. y: ", y);
			check_message(z >= WORLD_MIN_BLOCK_POS, "WorldPos z coordinate must be greater than or equal to world::WORLD_MIN_BLOCK_POS. z: ", z);
		}

		constexpr WorldPos(const WorldPos&) = default;
		constexpr WorldPos(WorldPos&&) = default;
		constexpr WorldPos& operator = (const WorldPos&) = default;
		constexpr WorldPos& operator = (WorldPos&&) = default;

		constexpr bool operator == (const WorldPos& other) const {
			return x == other.x && y == other.y && z == other.z;
		}

		/**
		* @return The position of a block within the chunk referenced by this WorldPos.
		*/
		constexpr BlockPos toBlockPos() const {
			return BlockPos( // Positive modulo
				(x % CHUNK_LENGTH + CHUNK_LENGTH) % CHUNK_LENGTH,
				(y % CHUNK_LENGTH + CHUNK_LENGTH) % CHUNK_LENGTH,
				(z % CHUNK_LENGTH + CHUNK_LENGTH) % CHUNK_LENGTH
			);
		}

		/**
		* @return The indices of each layer of the NTree referenced by this WorldPos.
		* Does not include the block position within a chunk.
		*/
		constexpr TreeDepthIndices toTreeIndices() const {
			const i32 xShiftedPositive = this->x + WORLD_MAX_BLOCK_POS + 1;
			const i32 yShiftedPositive = this->y + WORLD_MAX_BLOCK_POS + 1;
			const i32 zShiftedPositive = this->z + WORLD_MAX_BLOCK_POS + 1;

			u16 indices[TREE_LAYERS] = { 
				internal::calculateLayerIndex<0>(xShiftedPositive, yShiftedPositive, zShiftedPositive),
				internal::calculateLayerIndex<1>(xShiftedPositive, yShiftedPositive, zShiftedPositive),
				internal::calculateLayerIndex<2>(xShiftedPositive, yShiftedPositive, zShiftedPositive),
				internal::calculateLayerIndex<3>(xShiftedPositive, yShiftedPositive, zShiftedPositive),
				internal::calculateLayerIndex<4>(xShiftedPositive, yShiftedPositive, zShiftedPositive),
				internal::calculateLayerIndex<5>(xShiftedPositive, yShiftedPositive, zShiftedPositive),
				internal::calculateLayerIndex<6>(xShiftedPositive, yShiftedPositive, zShiftedPositive)
			};

			TreeDepthIndices treeIndices;
			treeIndices.setIndices(indices, TREE_LAYERS);
			return treeIndices;
		}

		constexpr WorldPos adjacent(BlockFacing adjacentDirection) const {
			const i32 xOffset = (-1 * i32(adjacentDirection.isFacing(BlockFacing::East))) + (i32(adjacentDirection.isFacing(BlockFacing::West)));
			const i32 yOffset = (-1 * i32(adjacentDirection.isFacing(BlockFacing::Down))) + (i32(adjacentDirection.isFacing(BlockFacing::Up)));
			const i32 zOffset = (-1 * i32(adjacentDirection.isFacing(BlockFacing::North))) + (i32(adjacentDirection.isFacing(BlockFacing::South)));
			return WorldPos(x + xOffset, y + yOffset, z + zOffset);
		}

	};

}