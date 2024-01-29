//! Contains the inner data of a chunk.
//! Is wrapped within a `Chunk` structure, providing multithreaded
//! safe access to this inner data.

const std = @import("std");
const world_transform = @import("../world_transform.zig");
const BlockPosition = world_transform.BlockPosition;
const RwLock = std.Thread.RwLock;
const ArrayList = std.ArrayList;
const TreeLayerIndices = @import("../TreeLayerIndices.zig");
const NTree = @import("../NTree.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const BlockLight = @import("../../engine/types/light.zig").BlockLight;

const Chunk = @import("chunk.zig").Chunk;
const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;

// TODO use actual future implementation of BlockState type. BlockState will also track the block's break state.
const BlockState = usize;

const Self = @This();
const DEFAULT_BLOCK_STATE_CAPACITY = 4;

/// Do not access directly
_lock: RwLock,
/// Do not access directly. Will always be a valid pointer of a length of 1 or more.
/// The first entry is the state of an air block, meaning that initializing _blockStateIds to all 0's
/// means the chunk is full of air.
///
/// Technical note: A chunk that is only air will be eventually cleaned up and replaced with an empty NTree node.
_blockStatesData: [*]BlockState,
/// Do not access directly. Will always be non-zero
_blockStatesLen: u16,
/// Do not access directly. Will always be non-zero
_blockStatesCapacity: u16,

// there is space for 4 bytes due to padding

/// DO NOT MODIFY, but can access directly.
/// Allows immediately going to the head of the tree that owns this chunk,
/// checking the state, and getting the allocator.
tree: *NTree,
/// DO NOT MODIFY, but can access directly.
/// Position of this chunk within the NTree.
/// Should not be ever modified.
treePos: TreeLayerIndices,
/// Do not access directly
_blockStateIds: [CHUNK_SIZE]u16 align(64),
/// Do not access directly
_light: [CHUNK_SIZE]BlockLight align(64),

pub fn init(tree: *NTree, treePos: TreeLayerIndices) Allocator.Error!*Self {
    const newSelf = try tree.allocator.create(Self);
    newSelf._lock = .{};

    const blockStatesSlice = try tree.allocator.alloc(BlockState, DEFAULT_BLOCK_STATE_CAPACITY);
    newSelf._blockStatesData = blockStatesSlice.ptr;
    newSelf._blockStatesData[0] = 0;
    newSelf._blockStatesLen = 1;
    newSelf._blockStatesCapacity = DEFAULT_BLOCK_STATE_CAPACITY;

    newSelf.tree = tree;
    newSelf.treePos = treePos;

    @memset(&newSelf._blockStateIds, 0); // default to only air
    @memset(&newSelf._light, BlockLight.init(0, 0, 0));

    return newSelf;
}

pub fn deinit(self: *Self) void {
    // During `.chunkModifyOnly`, only the data within the chunk can be modified.
    // The actual tree nodes cannot be deleted.
    const allocator = self.tree.allocator;

    var blockStatesSlice: []BlockState = undefined;
    blockStatesSlice.ptr = self._blockStatesData;
    blockStatesSlice.len = self._blockStatesCapacity;
    allocator.free(blockStatesSlice);
    allocator.destroy(self);
}

const BlockStateIndices1Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 64;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices1Bit, position: BlockPosition) u16 {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const bitIndex: u6 = @intCast(positionIndexCast & 63);
        const bitMask = @shlExact(@as(usize, 1), bitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, bitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices1Bit, index: u1, position: BlockPosition) void {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const bitIndex: u6 = @intCast(positionIndexCast & 63);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, bitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices2Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 32;
    const BIT_INDEX_MASK = 31;
    const BIT_INDEX_MULTIPLIER = 2;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices2Bit, position: BlockPosition) u16 {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const bitMask = @shlExact(@as(usize, 0b11), BIT_INDEX_MULTIPLIER * firstBitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, BIT_INDEX_MULTIPLIER * firstBitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices2Bit, index: u2, position: BlockPosition) void {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, BIT_INDEX_MULTIPLIER * firstBitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices4Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 16;
    const BIT_INDEX_MASK = 15;
    const BIT_INDEX_MULTIPLIER = 4;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices4Bit, position: BlockPosition) u16 {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const bitMask = @shlExact(@as(usize, 0b1111), BIT_INDEX_MULTIPLIER * firstBitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, BIT_INDEX_MULTIPLIER * firstBitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices4Bit, index: u4, position: BlockPosition) void {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, BIT_INDEX_MULTIPLIER * firstBitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices8Bit = struct {
    indices: [CHUNK_SIZE]u8 = .{0} ** CHUNK_SIZE,

    fn indexAt(self: BlockStateIndices8Bit, position: BlockPosition) u16 {
        return self.indices[position.index];
    }

    fn setIndexAt(self: *BlockStateIndices8Bit, index: u8, position: BlockPosition) void {
        self.indices[position.index] = index;
    }
};

const BlockStateIndices16Bit = struct {
    indices: [CHUNK_SIZE]u16 = .{0} ** CHUNK_SIZE,

    fn indexAt(self: BlockStateIndices16Bit, position: BlockPosition) u16 {
        return self.indices[position.index];
    }

    fn setIndexAt(self: *BlockStateIndices16Bit, index: u16, position: BlockPosition) void {
        self.indices[position.index] = index;
    }
};

// Tests

test "Size and Align" {
    //std.log.warn("size of chunk inner: {} bytes\n", .{@sizeOf(Self)});
    //std.log.warn("size of rw lock: {} bytes\n", .{@sizeOf(RwLock)});

    try expect(@alignOf(Self) == 64);

    // const sizeOfBlockStateIds = @sizeOf(u16) * CHUNK_SIZE;
    // const sizeOfLights = @sizeOf(BlockLight) * CHUNK_SIZE;
    try expect(@sizeOf(Self) == 131200);
}

test "BlockStateIndices1Bit" {
    try expect(@sizeOf(BlockStateIndices1Bit) == 4096);

    var indices: BlockStateIndices1Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(1, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(1, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 1);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 1);
}

test "BLockStateIndices2Bit" {
    try expect(@sizeOf(BlockStateIndices2Bit) == 8192);

    var indices: BlockStateIndices2Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(3, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(3, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 3);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 3);
}

test "BLockStateIndices4Bit" {
    try expect(@sizeOf(BlockStateIndices4Bit) == 16384);

    var indices: BlockStateIndices4Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(9, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(9, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 9);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 9);
}

test "BLockStateIndices8Bit" {
    try expect(@sizeOf(BlockStateIndices8Bit) == 32768);

    var indices: BlockStateIndices8Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(199, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(199, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 199);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 199);
}

test "BLockStateIndices16Bit" {
    try expect(@sizeOf(BlockStateIndices16Bit) == 65536);

    var indices: BlockStateIndices16Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(4321, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(4321, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 4321);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 4321);
}

test "Init deinit" {
    const tree = try NTree.init(std.testing.allocator);
    defer tree.deinit();

    const inner = try Self.init(tree, TreeLayerIndices.init(.{ 0, 0, 0, 0, 0, 0, 0 }));
    inner.deinit();
}
