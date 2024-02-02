//! Contains the inner data of a chunk.
//! Is wrapped within a `Chunk` structure, providing multithreaded
//! safe access to this inner data.
//! Storing this in a variable with a lifetime exceeding
//! the lifetime of the thread lock is undefined behaviour.
//!
//! Size
//!
//! 96 bytes for the chunk itself, and then a varying size depending
//! on the amount of unique `BlockState`'s in the chunk.
//!
//! - Up to 2 => 4096 bytes
//! - Up to 4 => 8192 bytes
//! - Up to 16 => 16384 bytes
//! - Up to 256 => 32768 bytes
//! - Up to CHUNK_SIZE (max) => 65536 bytes

const std = @import("std");
const world_transform = @import("../world_transform.zig");
const BlockPosition = world_transform.BlockPosition;
const RwLock = std.Thread.RwLock;
const ArrayList = std.ArrayList;
const TreeLayerIndices = @import("../n_tree/TreeLayerIndices.zig");
const NTree = @import("../n_tree/NTree.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const BlockLight = @import("../../engine/types/light.zig").BlockLight;
const BlockStateIndices = @import("BlockStateIndices.zig");

const Chunk = @import("Chunk.zig");
const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;

// TODO use actual future implementation of BlockState type. BlockState will also track the block's break state.
const BlockState = usize;

const Self = @This();

const DEFAULT_BLOCK_STATE_CAPACITY = 4;
const BLOCK_STATE_INDICES_ENUM_MASK: usize = @shlExact(0b11111111, 56);
const BLOCK_STATE_INDICES_PTR_MASK: usize = 0xFFFFFFFFFFFF;

/// Do not access directly
_lock: RwLock, // TODO maybe srwlock?
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

// NOTE there is space for 4 bytes due to padding

/// DO NOT MODIFY, but can access directly.
/// Allows immediately going to the head of the tree that owns this chunk,
/// checking the state, and getting the allocator.
tree: *NTree,
/// DO NOT MODIFY, but can access directly.
/// Position of this chunk within the NTree.
/// Should not be ever modified.
treePos: TreeLayerIndices,
/// Do not access directly
//_blockStateIds: [CHUNK_SIZE]u16 align(64),
/// Do not access directly
//_light: [CHUNK_SIZE]BlockLight align(64),
///
_blockStateIndices: BlockStateIndices,

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

    newSelf._blockStateIndices = try BlockStateIndices.init(tree.allocator);

    return newSelf;
}

pub fn deinit(self: *Self) void {
    if (!self._lock.tryLock()) {
        @panic("Cannot deinit Chunk while other threads have RwLock access to it's inner data");
    }

    const allocator = self.tree.allocator;

    var blockStatesSlice: []BlockState = undefined;
    blockStatesSlice.ptr = self._blockStatesData;
    blockStatesSlice.len = self._blockStatesCapacity;
    allocator.free(blockStatesSlice);
    self._blockStateIndices.deinit(allocator);
    self._lock.unlock();

    allocator.destroy(self);
}

fn blockStateIndexAt(self: *const Self, position: BlockPosition) u16 {
    self._blockStateIndices.blockStateIndexAt(position);
}

fn setBlockStateIndexAt(self: *Self, index: u16, position: BlockPosition) void {
    if (index >= self._blockStatesLen) {
        @panic("Index of chunk block states out of range.");
    }

    self._blockStateIndices.setBlockStateIndexAt(index, position);
}

// Tests

test "Size and Align" {
    //std.log.warn("size of chunk inner: {} bytes\n", .{@sizeOf(Self)});
    //std.log.warn("size of rw lock: {} bytes\n", .{@sizeOf(RwLock)});

    try expect(@alignOf(Self) == 8);

    // const sizeOfBlockStateIds = @sizeOf(u16) * CHUNK_SIZE;
    // const sizeOfLights = @sizeOf(BlockLight) * CHUNK_SIZE;
    try expect(@sizeOf(Self) == 96);
}

test "Init deinit" {
    const tree = try NTree.init(std.testing.allocator);
    defer tree.deinit();

    const inner = try Self.init(tree, TreeLayerIndices.init(.{ 0, 0, 0, 0, 0, 0, 0 }));
    inner.deinit();
}
