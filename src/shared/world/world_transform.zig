const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const TreeLayerIndices = @import("n_tree/TreeLayerIndices.zig");
const TREE_LAYERS = TreeLayerIndices.TREE_LAYERS;
const TREE_NODE_LENGTH = TreeLayerIndices.TREE_NODE_LENGTH;
const TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE = TreeLayerIndices.TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE;

/// Number of blocks long / wide / tall a chunk is.
pub const CHUNK_LENGTH: comptime_int = 32;
/// Number of blocks in a chunk.
pub const CHUNK_SIZE: comptime_int = CHUNK_LENGTH * CHUNK_LENGTH * CHUNK_LENGTH;
/// Total number of blocks long / wide / tall the entire world is.
pub const WORLD_BLOCK_LENGTH: comptime_int = TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE * CHUNK_LENGTH;
/// Maximum position a block can exist at.
pub const WORLD_MAX_BLOCK_POS: comptime_int = WORLD_BLOCK_LENGTH / 2 - 1;
/// Minimum position a block can exist at.
pub const WORLD_MIN_BLOCK_POS: comptime_int = WORLD_MAX_BLOCK_POS - WORLD_BLOCK_LENGTH + 1;

/// Facing direction of a block. Locked to 6 cube faces.
/// Occupies only 1 byte.
pub const BlockFacing = packed struct {
    const Self = @This();

    down: bool,
    up: bool,
    north: bool,
    south: bool,
    east: bool,
    west: bool,

    pub fn opposite(self: Self) Self {
        return BlockFacing{
            .down = !self.down,
            .up = !self.up,
            .north = !self.north,
            .south = !self.south,
            .east = !self.east,
            .west = !self.west,
        };
    }
};

/// Position of a block within a chunk,
/// x has a factor of 1
/// z has a factor of CHUNK_LENGTH
/// y has a factor of CHUNK_LENGTH * CHUNK_LENGTH
pub const BlockPosition = struct {
    const Self = @This();

    /// Index of a block within a chunk's blocks SOA arrays.
    index: u16,

    /// Initialize a BlockPosition given x y z coordinates.
    /// Asserts that `inX`, `inY`, and `inZ` are all less than `CHUNK_LENGTH`.
    pub fn init(inX: u16, inY: u16, inZ: u16) Self {
        assert(inX < CHUNK_LENGTH);
        assert(inY < CHUNK_LENGTH);
        assert(inZ < CHUNK_LENGTH);
        return Self{ .index = inX + (inZ * CHUNK_LENGTH) + (inY * CHUNK_LENGTH * CHUNK_LENGTH) };
    }

    pub fn x(self: Self) u16 {
        return self.index % CHUNK_LENGTH;
    }

    pub fn y(self: Self) u16 {
        return self.index / (CHUNK_LENGTH * CHUNK_LENGTH);
    }

    pub fn z(self: Self) u16 {
        return (self.index % (CHUNK_LENGTH * CHUNK_LENGTH)) / CHUNK_LENGTH;
    }

    pub fn isOnChunkEdge(self: Self) bool {
        const xCoord = self.x();
        const yCoord = self.y();
        const zCoord = self.z();

        const xEdge: bool = (xCoord == 0) or (xCoord == (CHUNK_LENGTH - 1));
        const yEdge: bool = (yCoord == 0) or (yCoord == (CHUNK_LENGTH - 1));
        const zEdge: bool = (zCoord == 0) or (zCoord == (CHUNK_LENGTH - 1));
        return xEdge or yEdge or zEdge;
    }
};

/// Integer position of a block within the world bounds,
/// specifying the chunk the block is in, and where within the chunk it is.
/// Each x y z component will be between WorldPosition.WORLD_MAX_BLOCK_POS and WorldPosition.WORLD_MIN_BLOCK_POS.
const WorldPosition = struct {
    const Self = @This();

    /// X coordinate within the world-space. Must be within the inclusive bounds of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    x: i32,
    /// Y coordinate within the world-space. Must be within the inclusive bounds of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    y: i32,
    /// Z coordinate within the world-space. Must be within the inclusive bounds of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    z: i32,

    /// Convert this `WorldPosition` into it's corresponding `BlockPosition`,
    /// without specifying where in the NTree structure the block is (doesn't specify which chunk).
    /// Asserts that x y z components are within the inclusive range of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    pub fn toBlockPos(self: Self) BlockPosition {
        assert(self.x <= WORLD_MAX_BLOCK_POS);
        assert(self.x >= WORLD_MIN_BLOCK_POS);
        assert(self.y <= WORLD_MAX_BLOCK_POS);
        assert(self.y >= WORLD_MIN_BLOCK_POS);
        assert(self.z <= WORLD_MAX_BLOCK_POS);
        assert(self.z >= WORLD_MIN_BLOCK_POS);

        const relativeX = @mod(@mod(self.x, CHUNK_LENGTH + CHUNK_LENGTH), CHUNK_LENGTH);
        const relativeY = @mod(@mod(self.y, CHUNK_LENGTH + CHUNK_LENGTH), CHUNK_LENGTH);
        const relativeZ = @mod(@mod(self.z, CHUNK_LENGTH + CHUNK_LENGTH), CHUNK_LENGTH);

        return BlockPosition.init(@intCast(relativeX), @intCast(relativeY), @intCast(relativeZ));
    }

    /// Convert this `WorldPosition` into the indices of each layer of the NTree.
    /// Functionally the same as the position of a chunk, without the BlockPosition.
    /// Asserts that x y z components are within the inclusive range of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    pub fn toTreeIndices(self: Self) TreeLayerIndices {
        assert(self.x <= WORLD_MAX_BLOCK_POS);
        assert(self.x >= WORLD_MIN_BLOCK_POS);
        assert(self.y <= WORLD_MAX_BLOCK_POS);
        assert(self.y >= WORLD_MIN_BLOCK_POS);
        assert(self.z <= WORLD_MAX_BLOCK_POS);
        assert(self.z >= WORLD_MIN_BLOCK_POS);

        const xShiftedPositive = self.x + WORLD_MAX_BLOCK_POS + 1;
        const yShiftedPositive = self.y + WORLD_MAX_BLOCK_POS + 1;
        const ZShiftedPositive = self.z + WORLD_MAX_BLOCK_POS + 1;

        const indices: [TREE_LAYERS]u16 = .{
            calculateLayerIndex(0, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
            calculateLayerIndex(1, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
            calculateLayerIndex(2, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
            calculateLayerIndex(3, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
            calculateLayerIndex(4, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
            calculateLayerIndex(5, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
            calculateLayerIndex(6, xShiftedPositive, yShiftedPositive, ZShiftedPositive),
        };

        return TreeLayerIndices.init(indices);
    }

    /// Get the position adjacent to this one at a specific direction.
    pub fn adjacent(self: Self, direction: BlockFacing) Self {
        var xOffset: i32 = 0;
        var yOffset: i32 = 0;
        var zOffset: i32 = 0;
        if (direction.east) xOffset -= 1;
        if (direction.west) xOffset += 1;
        if (direction.down) yOffset -= 1;
        if (direction.up) yOffset += 1;
        if (direction.north) zOffset -= 1;
        if (direction.south) zOffset += 1;
        return Self{ .x = self.x + xOffset, .y = self.y + yOffset, .z = self.z + zOffset };
    }
};

fn calculateLayerIndex(layer: comptime_int, xShiftedPositive: i32, yShiftedPositive: i32, zShiftedPositive: i32) u16 {
    if (layer >= TREE_LAYERS) {
        @compileError("layer cannot exceed TREE_LAYERS");
    }

    if (layer == 0) {
        const normalizedX: u16 = @intCast((xShiftedPositive * TREE_NODE_LENGTH) / WORLD_BLOCK_LENGTH);
        const normalizedY: u16 = @intCast((yShiftedPositive * TREE_NODE_LENGTH) / WORLD_BLOCK_LENGTH);
        const normalizedZ: u16 = @intCast((zShiftedPositive * TREE_NODE_LENGTH) / WORLD_BLOCK_LENGTH);

        return normalizedX + (normalizedZ * TREE_NODE_LENGTH) + (normalizedY * TREE_NODE_LENGTH * TREE_NODE_LENGTH);
    } else {
        const DIV = comptime (calculateLayerDiv(layer));

        const normalizedX: u16 = @intCast(((xShiftedPositive % DIV) * TREE_NODE_LENGTH) / DIV);
        const normalizedY: u16 = @intCast(((yShiftedPositive % DIV) * TREE_NODE_LENGTH) / DIV);
        const normalizedZ: u16 = @intCast(((zShiftedPositive % DIV) * TREE_NODE_LENGTH) / DIV);

        return normalizedX + (normalizedZ * TREE_NODE_LENGTH) + (normalizedY * TREE_NODE_LENGTH * TREE_NODE_LENGTH);
    }
}

fn calculateLayerDiv(layer: comptime_int) comptime_int {
    var out = 1;
    for (0..layer) |_| {
        out *= TREE_NODE_LENGTH;
    }
}

// Tests

test "BlockPosition init components" {
    const bpos = BlockPosition.init(0, 8, 31);
    try expect(bpos.x() == 0);
    try expect(bpos.y() == 8);
    try expect(bpos.z() == 31);
}

test "BlockPosition is on chunk edge 0, 0, 0" {
    const bpos = BlockPosition.init(0, 0, 0);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is on chunk edge 0, 1, 1" {
    const bpos = BlockPosition.init(0, 1, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is on chunk edge 1, 0, 1" {
    const bpos = BlockPosition.init(1, 0, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is on chunk edge 1, 1, 0" {
    const bpos = BlockPosition.init(1, 1, 0);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is on chunk edge CHUNK_LENGTH - 1, 1, 1" {
    const bpos = BlockPosition.init(CHUNK_LENGTH - 1, 1, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is on chunk edge 1, CHUNK_LENGTH - 1, 1" {
    const bpos = BlockPosition.init(1, CHUNK_LENGTH - 1, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is on chunk edge 1, 1, CHUNK_LENGTH - 1" {
    const bpos = BlockPosition.init(1, 1, CHUNK_LENGTH - 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockPosition is not on chunk edge" {
    const bpos = BlockPosition.init(15, 15, 15);
    try expect(!bpos.isOnChunkEdge());
}

test "BlockFacing size align" {
    try expect(@sizeOf(BlockFacing) == 1);
    try expect(@alignOf(BlockFacing) == 1);
}

test "WorldPosition to block pos coordinates 0, 0, 0" {
    const pos = WorldPosition{ .x = 0, .y = 0, .z = 0 };
    const bpos = pos.toBlockPos();
    try expect(bpos.x() == 0);
    try expect(bpos.y() == 0);
    try expect(bpos.z() == 0);
}

test "WorldPosition to block pos coordinates 1, 1, 1" {
    const pos = WorldPosition{ .x = 1, .y = 1, .z = 1 };
    const bpos = pos.toBlockPos();
    try expect(bpos.x() == 1);
    try expect(bpos.y() == 1);
    try expect(bpos.z() == 1);
}

test "WorldPosition to block pos coordinates -1, -1, -1" {
    const pos = WorldPosition{ .x = -1, .y = -1, .z = -1 };
    const bpos = pos.toBlockPos();
    try expect(bpos.x() == CHUNK_LENGTH - 1);
    try expect(bpos.y() == CHUNK_LENGTH - 1);
    try expect(bpos.z() == CHUNK_LENGTH - 1);
}
