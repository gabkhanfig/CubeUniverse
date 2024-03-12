const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const tree_layer_indices = @import("fat_tree/tree_layer_indices.zig");
const TreeLayerIndices = tree_layer_indices.TreeLayerIndices;
const TREE_LAYERS = tree_layer_indices.TREE_LAYERS;
const TREE_NODE_LENGTH = tree_layer_indices.TREE_NODE_LENGTH;
const TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE = tree_layer_indices.TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE;
const vector_types = @import("../math/vector.zig");
const vec3 = vector_types.vec3;
const dvec3 = vector_types.dvec3;

/// Number of blocks long / wide / tall a chunk is.
pub const CHUNK_LENGTH: comptime_int = 32;
/// Number of blocks in a chunk.
pub const CHUNK_SIZE: comptime_int = CHUNK_LENGTH * CHUNK_LENGTH * CHUNK_LENGTH;
/// # 34359738368
/// Total number of blocks long / wide / tall the entire world is.
pub const WORLD_BLOCK_LENGTH: comptime_int = TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE * CHUNK_LENGTH;
/// # 17179869183
/// Maximum position a block can exist at.
pub const WORLD_MAX_BLOCK_POS: comptime_int = WORLD_BLOCK_LENGTH / 2 - 1;
/// # -17179869184
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
pub const BlockIndex = struct { // TODO rename to BlockIndex
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
pub const BlockPosition = extern struct {
    const Self = @This();

    /// X coordinate within the world-space. Must be within the inclusive bounds of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    x: i64,
    /// Y coordinate within the world-space. Must be within the inclusive bounds of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    y: i64,
    /// Z coordinate within the world-space. Must be within the inclusive bounds of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    z: i64,

    /// Convert this `WorldPosition` into it's corresponding `BlockPosition`,
    /// without specifying where in the FatTree structure the block is (doesn't specify which chunk).
    /// Asserts that x y z components are within the inclusive range of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    pub fn asBlockIndex(self: Self) BlockIndex {
        assert(self.x <= WORLD_MAX_BLOCK_POS);
        assert(self.x >= WORLD_MIN_BLOCK_POS);
        assert(self.y <= WORLD_MAX_BLOCK_POS);
        assert(self.y >= WORLD_MIN_BLOCK_POS);
        assert(self.z <= WORLD_MAX_BLOCK_POS);
        assert(self.z >= WORLD_MIN_BLOCK_POS);

        const relativeX = @mod(@mod(self.x, CHUNK_LENGTH + CHUNK_LENGTH), CHUNK_LENGTH);
        const relativeY = @mod(@mod(self.y, CHUNK_LENGTH + CHUNK_LENGTH), CHUNK_LENGTH);
        const relativeZ = @mod(@mod(self.z, CHUNK_LENGTH + CHUNK_LENGTH), CHUNK_LENGTH);

        return BlockIndex.init(@intCast(relativeX), @intCast(relativeY), @intCast(relativeZ));
    }

    /// Convert this `WorldPosition` into the indices of each layer of the FatTree.
    /// Functionally the same as the position of a chunk, without the `BlockIndex`.
    /// Asserts that x y z components are within the inclusive range of `WORLD_MAX_BLOCK_POS` and `WORLD_MIN_BLOCK_POS`.
    pub fn asTreeIndices(self: Self) TreeLayerIndices {
        assert(self.x <= WORLD_MAX_BLOCK_POS);
        assert(self.x >= WORLD_MIN_BLOCK_POS);
        assert(self.y <= WORLD_MAX_BLOCK_POS);
        assert(self.y >= WORLD_MIN_BLOCK_POS);
        assert(self.z <= WORLD_MAX_BLOCK_POS);
        assert(self.z >= WORLD_MIN_BLOCK_POS);

        const xShiftedPositive: i64 = @divTrunc(self.x + WORLD_MAX_BLOCK_POS + 1, CHUNK_LENGTH);
        const yShiftedPositive: i64 = @divTrunc(self.y + WORLD_MAX_BLOCK_POS + 1, CHUNK_LENGTH);
        const zShiftedPositive: i64 = @divTrunc(self.z + WORLD_MAX_BLOCK_POS + 1, CHUNK_LENGTH);

        var indices: [TREE_LAYERS]TreeLayerIndices.Index = undefined;
        inline for (0..TREE_LAYERS) |i| {
            const iAsComptime: comptime_int = i;
            indices[i] = calculateLayerIndex(iAsComptime, xShiftedPositive, yShiftedPositive, zShiftedPositive);
        }

        return TreeLayerIndices.init(indices);
    }

    /// Does not hold any information on which `BlockIndex` is used.
    /// Each component is effectively clamped to increments of `CHUNK_LENGTH`.
    pub fn fromTreeIndices(indices: TreeLayerIndices) Self {

        // Ignore the 4th element. its not needed
        var components = @Vector(4, i64){ 0, 0, 0, 0 };

        inline for (0..TREE_LAYERS) |i| {
            const iAsComptime: comptime_int = i;
            const multiplier: i64 = calculateLayerMultiplier(iAsComptime);

            const index = indices.indexAtLayer(i);

            const indicesVec = @Vector(4, i64){ index.x(), index.y(), index.z(), 0 };
            const scaledMultiplier: @Vector(4, i64) = @splat(multiplier / TREE_NODE_LENGTH);
            components += indicesVec * scaledMultiplier;
        }

        components *= @splat(CHUNK_LENGTH);
        components -= @splat(WORLD_MAX_BLOCK_POS + 1);

        return BlockPosition{ .x = components[0], .y = components[1], .z = components[2] };
    }

    /// Get the position adjacent to this one at a specific direction.
    pub fn adjacent(self: Self, direction: BlockFacing) Self {
        var xOffset: i64 = 0;
        var yOffset: i64 = 0;
        var zOffset: i64 = 0;
        if (direction.east) xOffset -= 1;
        if (direction.west) xOffset += 1;
        if (direction.down) yOffset -= 1;
        if (direction.up) yOffset += 1;
        if (direction.north) zOffset -= 1;
        if (direction.south) zOffset += 1;
        return Self{ .x = self.x + xOffset, .y = self.y + yOffset, .z = self.z + zOffset };
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }
};

/// Position of anything within the `FatTree` structure.
/// Internally uses `TreeLayerIndices` to specify which chunk it is in,
/// and then a 32 bit 3 component float `vec3` for where within the chunk.
/// This structure can be used in the GLSL.
/// - Size = 24 bytes
/// - Align = 4 bytes
/// - field `treePosition` byte offset = 0
/// - field `offset` byte offset = 12
pub const WorldPosition = extern struct {
    const Self = @This();

    const WORLD_MAX_BLOCK_POS_FLOAT: comptime_float = @floatFromInt(WORLD_MAX_BLOCK_POS);
    const WORLD_MIN_BLOCK_POS_FLOAT: comptime_float = @floatFromInt(WORLD_MIN_BLOCK_POS);
    const CHUNK_LENGTH_FLOAT: comptime_float = @floatFromInt(CHUNK_LENGTH);

    treePosition: TreeLayerIndices = .{},
    /// Represents the offset within a chunk, on the same scale as a block. Every 1 unit is 1 block.
    /// Each component of the vector must be between the range of `component >= 0` and `component < CHUNK_LENGTH`
    /// (0 is inclusive, and `CHUNK_LENGTH` is exclusive).
    offset: vec3 = .{},

    /// Get the index of a block in a chunk that this `WorldPosition` is at.
    /// Uses flooring.
    pub fn asBlockIndex(self: Self) BlockIndex {
        assert(self.offset.x < CHUNK_LENGTH_FLOAT);
        assert(self.offset.x >= 0.0);
        assert(self.offset.y < CHUNK_LENGTH_FLOAT);
        assert(self.offset.y >= 0.0);
        assert(self.offset.z < CHUNK_LENGTH_FLOAT);
        assert(self.offset.z >= 0.0);

        const xAsInt: u16 = @intFromFloat(self.offset.x);
        const yAsInt: u16 = @intFromFloat(self.offset.y);
        const zAsInt: u16 = @intFromFloat(self.offset.z);

        return BlockIndex.init(xAsInt, yAsInt, zAsInt);
    }

    /// Convert the position of a block to a `WorldPosition`
    pub fn fromBlockPosition(pos: BlockPosition) Self {
        assert(pos.x <= WORLD_MAX_BLOCK_POS);
        assert(pos.x >= WORLD_MIN_BLOCK_POS);
        assert(pos.y <= WORLD_MAX_BLOCK_POS);
        assert(pos.y >= WORLD_MIN_BLOCK_POS);
        assert(pos.z <= WORLD_MAX_BLOCK_POS);
        assert(pos.z >= WORLD_MIN_BLOCK_POS);

        const treePos = pos.asTreeIndices();

        const blockIndex = pos.asBlockIndex();
        const blockOffset = vec3{
            .x = @floatFromInt(blockIndex.x()),
            .y = @floatFromInt(blockIndex.y()),
            .z = @floatFromInt(blockIndex.z()),
        };

        return Self{ .treePosition = treePos, .offset = blockOffset };
    }

    /// Get the position of a block that this `WorldPosition` is at.
    /// Floors the `offset`.
    pub fn asBlockPosition(self: Self) BlockPosition {
        assert(self.offset.x < CHUNK_LENGTH_FLOAT);
        assert(self.offset.x >= 0.0);
        assert(self.offset.y < CHUNK_LENGTH_FLOAT);
        assert(self.offset.y >= 0.0);
        assert(self.offset.z < CHUNK_LENGTH_FLOAT);
        assert(self.offset.z >= 0.0);

        const treeAsBlockPos = BlockPosition.fromTreeIndices(self.treePosition);

        const xOffset: i64 = @intFromFloat(self.offset.x);
        const yOffset: i64 = @intFromFloat(self.offset.y);
        const zOffset: i64 = @intFromFloat(self.offset.z);

        return BlockPosition{
            .x = treeAsBlockPos.x + xOffset,
            .y = treeAsBlockPos.y + yOffset,
            .z = treeAsBlockPos.z + zOffset,
        };
    }

    /// Convert a vector of 64 bit float coordinates to a `WorldPosition`.
    pub fn fromVector(pos: dvec3) Self {
        assert(pos.x <= WORLD_MAX_BLOCK_POS_FLOAT);
        assert(pos.x >= WORLD_MIN_BLOCK_POS_FLOAT);
        assert(pos.y <= WORLD_MAX_BLOCK_POS_FLOAT);
        assert(pos.y >= WORLD_MIN_BLOCK_POS_FLOAT);
        assert(pos.z <= WORLD_MAX_BLOCK_POS_FLOAT);
        assert(pos.z >= WORLD_MIN_BLOCK_POS_FLOAT);

        const offset = vec3{
            .x = @floatCast(@mod(pos.x, CHUNK_LENGTH_FLOAT)),
            .y = @floatCast(@mod(pos.y, CHUNK_LENGTH_FLOAT)),
            .z = @floatCast(@mod(pos.z, CHUNK_LENGTH_FLOAT)),
        };

        const bpos = BlockPosition{
            .x = @intFromFloat(pos.x),
            .y = @intFromFloat(pos.y),
            .z = @intFromFloat(pos.z),
        };

        const treePos = bpos.asTreeIndices();

        return Self{ .treePosition = treePos, .offset = offset };
    }

    /// Gets this `WorldPosition` as a vector of 64 bit float coordinates
    pub fn asVector(self: Self) dvec3 {
        assert(self.offset.x < CHUNK_LENGTH_FLOAT);
        assert(self.offset.x >= 0.0);
        assert(self.offset.y < CHUNK_LENGTH_FLOAT);
        assert(self.offset.y >= 0.0);
        assert(self.offset.z < CHUNK_LENGTH_FLOAT);
        assert(self.offset.z >= 0.0);

        const treeAsBlockPos = BlockPosition.fromTreeIndices(self.treePosition);
        const treePosVec = dvec3{
            .x = @floatFromInt(treeAsBlockPos.x),
            .y = @floatFromInt(treeAsBlockPos.y),
            .z = @floatFromInt(treeAsBlockPos.z),
        };

        const xOffset: f64 = @floatCast(self.offset.x);
        const yOffset: f64 = @floatCast(self.offset.y);
        const zOffset: f64 = @floatCast(self.offset.z);

        return dvec3{
            .x = treePosVec.x + xOffset,
            .y = treePosVec.y + yOffset,
            .z = treePosVec.z + zOffset,
        };
    }
};

fn calculateLayerIndex(comptime layer: comptime_int, xShiftedPositive: i64, yShiftedPositive: i64, zShiftedPositive: i64) TreeLayerIndices.Index {
    if (layer >= TREE_LAYERS) {
        @compileError("layer cannot exceed TREE_LAYERS");
    }

    const DIV = calculateLayerMultiplier(layer);

    const normalizedX: u2 = @intCast(@divTrunc((@mod(xShiftedPositive, DIV) * TREE_NODE_LENGTH), DIV));
    const normalizedY: u2 = @intCast(@divTrunc((@mod(yShiftedPositive, DIV) * TREE_NODE_LENGTH), DIV));
    const normalizedZ: u2 = @intCast(@divTrunc((@mod(zShiftedPositive, DIV) * TREE_NODE_LENGTH), DIV));

    return TreeLayerIndices.Index.init(normalizedX, normalizedY, normalizedZ);
}

fn calculateLayerMultiplier(comptime layer: comptime_int) comptime_int {
    var out = 1;
    for (layer..TREE_LAYERS) |_| {
        out *= TREE_NODE_LENGTH;
    }
    return out;
}

// Tests

test "BlockIndex init components" {
    const bpos = BlockIndex.init(0, 8, 31);
    try expect(bpos.x() == 0);
    try expect(bpos.y() == 8);
    try expect(bpos.z() == 31);
}

test "BlockIndex is on chunk edge 0, 0, 0" {
    const bpos = BlockIndex.init(0, 0, 0);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is on chunk edge 0, 1, 1" {
    const bpos = BlockIndex.init(0, 1, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is on chunk edge 1, 0, 1" {
    const bpos = BlockIndex.init(1, 0, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is on chunk edge 1, 1, 0" {
    const bpos = BlockIndex.init(1, 1, 0);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is on chunk edge CHUNK_LENGTH - 1, 1, 1" {
    const bpos = BlockIndex.init(CHUNK_LENGTH - 1, 1, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is on chunk edge 1, CHUNK_LENGTH - 1, 1" {
    const bpos = BlockIndex.init(1, CHUNK_LENGTH - 1, 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is on chunk edge 1, 1, CHUNK_LENGTH - 1" {
    const bpos = BlockIndex.init(1, 1, CHUNK_LENGTH - 1);
    try expect(bpos.isOnChunkEdge());
}

test "BlockIndex is not on chunk edge" {
    const bpos = BlockIndex.init(15, 15, 15);
    try expect(!bpos.isOnChunkEdge());
}

test "BlockFacing size align" {
    try expect(@sizeOf(BlockFacing) == 1);
    try expect(@alignOf(BlockFacing) == 1);
}

test "BlockPosition to block pos coordinates 0, 0, 0" {
    const pos = BlockPosition{ .x = 0, .y = 0, .z = 0 };
    const bpos = pos.asBlockIndex();
    try expect(bpos.x() == 0);
    try expect(bpos.y() == 0);
    try expect(bpos.z() == 0);
}

test "BlockPosition to block pos coordinates 1, 1, 1" {
    const pos = BlockPosition{ .x = 1, .y = 1, .z = 1 };
    const bpos = pos.asBlockIndex();
    try expect(bpos.x() == 1);
    try expect(bpos.y() == 1);
    try expect(bpos.z() == 1);
}

test "BlockPosition to block pos coordinates -1, -1, -1" {
    const pos = BlockPosition{ .x = -1, .y = -1, .z = -1 };
    const bpos = pos.asBlockIndex();
    try expect(bpos.x() == CHUNK_LENGTH - 1);
    try expect(bpos.y() == CHUNK_LENGTH - 1);
    try expect(bpos.z() == CHUNK_LENGTH - 1);
}

test "BlockPosition from TreeLayerIndices" {
    var indices: [TREE_LAYERS]TreeLayerIndices.Index = undefined;
    indices[0] = TreeLayerIndices.Index.init(2, 2, 2);
    for (1..TREE_LAYERS) |i| {
        indices[i] = TreeLayerIndices.Index.init(0, 0, 0);
    }
    {
        const treePos = TreeLayerIndices.init(indices);
        const pos = BlockPosition.fromTreeIndices(treePos);
        try expect(pos.x == 0);
        try expect(pos.y == 0);
        try expect(pos.z == 0);
    }
    indices[TREE_LAYERS - 1] = TreeLayerIndices.Index.init(1, 1, 1);
    {
        const treePos = TreeLayerIndices.init(indices);
        const pos = BlockPosition.fromTreeIndices(treePos);
        try expect(pos.x == 32);
        try expect(pos.y == 32);
        try expect(pos.z == 32);
    }
}

test "BlockPosition as TreeLayerIndices" {
    const pos = BlockPosition{ .x = 0, .y = 0, .z = 0 };
    const treeInd = pos.asTreeIndices();
    try expect(treeInd.indexAtLayer(0).eql(TreeLayerIndices.Index.init(2, 2, 2)));
    for (1..TREE_LAYERS) |i| {
        try expect(treeInd.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
    }
}

test "BlockPosition as TreeLayerIndices sanity" {
    { // should still be in same chunk as 0, 0, 0
        const pos = BlockPosition{ .x = 31, .y = 31, .z = 31 };
        const treeInd = pos.asTreeIndices();
        try expect(treeInd.indexAtLayer(0).eql(TreeLayerIndices.Index.init(2, 2, 2)));
        for (1..TREE_LAYERS) |i| {
            try expect(treeInd.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
        }
    }
    { // next chunk over
        const pos = BlockPosition{ .x = 32, .y = 32, .z = 32 };
        const treeInd = pos.asTreeIndices();
        try expect(treeInd.indexAtLayer(0).eql(TreeLayerIndices.Index.init(2, 2, 2)));
        for (1..(TREE_LAYERS - 1)) |i| {
            try expect(treeInd.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
        }
        try expect(treeInd.indexAtLayer(TREE_LAYERS - 1).eql(TreeLayerIndices.Index.init(1, 1, 1)));
    }
    { // Double converstion
        const pos = BlockPosition{ .x = 123456789, .y = -5000000000, .z = WORLD_MAX_BLOCK_POS };
        const treePos = pos.asTreeIndices();
        const convertBack = BlockPosition.fromTreeIndices(treePos);

        // Clamp to increments of CHUNK_LENGTH
        try expect((pos.x - @mod(pos.x, CHUNK_LENGTH)) == convertBack.x);
        try expect((pos.y - @mod(pos.y, CHUNK_LENGTH)) == convertBack.y);
        try expect((pos.z - @mod(pos.z, CHUNK_LENGTH)) == convertBack.z);
    }
}

test "BlockPosition equal" {
    {
        const pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
        const pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
        try expect(pos1.eql(pos2));
    }
    {
        const pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS + 1, .y = 0, .z = WORLD_MAX_BLOCK_POS };
        const pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
        try expect(!pos1.eql(pos2));
    }
    {
        const pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = -1, .z = WORLD_MAX_BLOCK_POS };
        const pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
        try expect(!pos1.eql(pos2));
    }
    {
        const pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS - 1 };
        const pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
        try expect(!pos1.eql(pos2));
    }
}

test "WorldPosition size align offset" {
    try expect(@sizeOf(WorldPosition) == 24);
    try expect(@alignOf(WorldPosition) == 4);
    try expect(@offsetOf(WorldPosition, "treePosition") == 0);
    try expect(@offsetOf(WorldPosition, "offset") == 12);
}

test "WorldPosition as block index" {
    const pos = WorldPosition{ .offset = vec3{ .x = 3.4, .y = 3.2, .z = 3 } };
    const ind = pos.asBlockIndex();
    try expect(ind.x() == 3);
    try expect(ind.y() == 3);
    try expect(ind.z() == 3);
}

test "WorldPosition from BlockPosition" {
    {
        const bpos = BlockPosition{ .x = 36, .y = 37, .z = 38 };
        const pos = WorldPosition.fromBlockPosition(bpos);

        try expect(pos.treePosition.indexAtLayer(0).eql(TreeLayerIndices.Index.init(2, 2, 2)));
        for (1..(TREE_LAYERS - 1)) |i| {
            try expect(pos.treePosition.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
        }
        try expect(pos.treePosition.indexAtLayer(TREE_LAYERS - 1).eql(TreeLayerIndices.Index.init(1, 1, 1)));

        try expect(pos.offset.x == 4);
        try expect(pos.offset.y == 5);
        try expect(pos.offset.z == 6);
    }
    { // negative values
        const bpos = BlockPosition{
            .x = WORLD_MIN_BLOCK_POS + 36,
            .y = WORLD_MIN_BLOCK_POS + 37,
            .z = WORLD_MIN_BLOCK_POS + 38,
        };
        const pos = WorldPosition.fromBlockPosition(bpos);

        for (0..(TREE_LAYERS - 1)) |i| {
            try expect(pos.treePosition.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
        }
        try expect(pos.treePosition.indexAtLayer(TREE_LAYERS - 1).eql(TreeLayerIndices.Index.init(1, 1, 1)));

        try expect(pos.offset.x == 4);
        try expect(pos.offset.y == 5);
        try expect(pos.offset.z == 6);
    }
}

test "WorldPosition as BlockPosition" {
    {
        var indices: [TREE_LAYERS]TreeLayerIndices.Index = undefined;
        indices[0] = TreeLayerIndices.Index.init(2, 2, 2);
        for (1..(TREE_LAYERS - 1)) |i| {
            indices[i] = TreeLayerIndices.Index.init(0, 0, 0);
        }
        indices[TREE_LAYERS - 1] = TreeLayerIndices.Index.init(1, 1, 1);

        const pos = WorldPosition{
            .treePosition = TreeLayerIndices.init(indices),
            .offset = .{ .x = 4, .y = 5, .z = 6 },
        };

        const bpos = pos.asBlockPosition();
        try expect(bpos.x == 36);
        try expect(bpos.y == 37);
        try expect(bpos.z == 38);
    }
    { // negative values
        var indices: [TREE_LAYERS]TreeLayerIndices.Index = undefined;
        for (0..(TREE_LAYERS - 1)) |i| {
            indices[i] = TreeLayerIndices.Index.init(0, 0, 0);
        }
        indices[TREE_LAYERS - 1] = TreeLayerIndices.Index.init(1, 1, 1);

        const pos = WorldPosition{
            .treePosition = TreeLayerIndices.init(indices),
            .offset = .{ .x = 4, .y = 5, .z = 6 },
        };

        const bpos = pos.asBlockPosition();
        try expect(bpos.x == WORLD_MIN_BLOCK_POS + 36);
        try expect(bpos.y == WORLD_MIN_BLOCK_POS + 37);
        try expect(bpos.z == WORLD_MIN_BLOCK_POS + 38);
    }
}

const TEST_EPSILON = 0.0001;

test "WorldPosition from dvec3" {
    {
        const vec = dvec3{ .x = 36.1, .y = 37.5, .z = 38.9 };
        const pos = WorldPosition.fromVector(vec);

        try expect(pos.treePosition.indexAtLayer(0).eql(TreeLayerIndices.Index.init(2, 2, 2)));
        for (1..(TREE_LAYERS - 1)) |i| {
            try expect(pos.treePosition.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
        }
        try expect(pos.treePosition.indexAtLayer(TREE_LAYERS - 1).eql(TreeLayerIndices.Index.init(1, 1, 1)));

        try expect(std.math.approxEqAbs(f32, pos.offset.x, 4.1, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f32, pos.offset.y, 5.5, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f32, pos.offset.z, 6.9, TEST_EPSILON));
    }
    { // negative values
        const vec = dvec3{
            .x = WORLD_MIN_BLOCK_POS + 36.1,
            .y = WORLD_MIN_BLOCK_POS + 37.5,
            .z = WORLD_MIN_BLOCK_POS + 38.9,
        };
        const pos = WorldPosition.fromVector(vec);

        for (0..(TREE_LAYERS - 1)) |i| {
            try expect(pos.treePosition.indexAtLayer(i).eql(TreeLayerIndices.Index.init(0, 0, 0)));
        }
        try expect(pos.treePosition.indexAtLayer(TREE_LAYERS - 1).eql(TreeLayerIndices.Index.init(1, 1, 1)));

        try expect(std.math.approxEqAbs(f32, pos.offset.x, 4.1, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f32, pos.offset.y, 5.5, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f32, pos.offset.z, 6.9, TEST_EPSILON));
    }
}

test "WorldPosition as dvec3" {
    {
        var indices: [TREE_LAYERS]TreeLayerIndices.Index = undefined;
        indices[0] = TreeLayerIndices.Index.init(2, 2, 2);
        for (1..(TREE_LAYERS - 1)) |i| {
            indices[i] = TreeLayerIndices.Index.init(0, 0, 0);
        }
        indices[TREE_LAYERS - 1] = TreeLayerIndices.Index.init(1, 1, 1);

        const pos = WorldPosition{
            .treePosition = TreeLayerIndices.init(indices),
            .offset = .{ .x = 4.9, .y = 5.1, .z = 6.5 },
        };

        const vec = pos.asVector();
        try expect(std.math.approxEqAbs(f64, vec.x, 36.9, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f64, vec.y, 37.1, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f64, vec.z, 38.5, TEST_EPSILON));
    }
    { // negative values
        var indices: [TREE_LAYERS]TreeLayerIndices.Index = undefined;
        for (0..(TREE_LAYERS - 1)) |i| {
            indices[i] = TreeLayerIndices.Index.init(0, 0, 0);
        }
        indices[TREE_LAYERS - 1] = TreeLayerIndices.Index.init(1, 1, 1);

        const pos = WorldPosition{
            .treePosition = TreeLayerIndices.init(indices),
            .offset = .{ .x = 4.9, .y = 5.1, .z = 6.5 },
        };

        const vec = pos.asVector();
        try expect(std.math.approxEqAbs(f64, vec.x, WorldPosition.WORLD_MIN_BLOCK_POS_FLOAT + 36.9, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f64, vec.y, WorldPosition.WORLD_MIN_BLOCK_POS_FLOAT + 37.1, TEST_EPSILON));
        try expect(std.math.approxEqAbs(f64, vec.z, WorldPosition.WORLD_MIN_BLOCK_POS_FLOAT + 38.5, TEST_EPSILON));
    }
}
