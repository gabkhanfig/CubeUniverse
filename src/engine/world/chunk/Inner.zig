//! Contains the inner data of a chunk.
//! Is wrapped within a `Chunk` structure, providing multithreaded
//! safe access to this inner data.
//! Storing this in a variable with a lifetime exceeding
//! the lifetime of the thread lock is undefined behaviour.
//!
//! Size
//!
//! 104 bytes for the chunk itself, and then a varying size depending
//! on the amount of unique `BlockState`'s in the chunk.
//!
//! - Up to 2 => 4096 bytes
//! - Up to 4 => 8192 bytes
//! - Up to 16 => 16384 bytes
//! - Up to 256 => 32768 bytes
//! - Up to CHUNK_SIZE (max) => 65536 bytes

const std = @import("std");
const world_transform = @import("../world_transform.zig");
const BlockIndex = world_transform.BlockIndex;
const RwLock = std.Thread.RwLock;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const TreeLayerIndices = @import("../fat_tree/tree_layer_indices.zig").TreeLayerIndices;
const FatTree = @import("../fat_tree/FatTree.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const BlockLight = @import("../../types/light.zig").BlockLight;
const BlockStateIndices = @import("BlockStateIndices.zig");

const Chunk = @import("Chunk.zig");
const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;

// TODO use actual future implementation of BlockState type. BlockState will also track the block's break state.
const BlockState = usize;

const Self = @This();

const DEFAULT_BLOCK_STATE_CAPACITY = 4;

/// Do not access directly
_lock: RwLock = .{}, // TODO maybe srwlock?
/// DO NOT MODIFY, but can access directly.
/// Allows immediately going to the head of the tree that owns this chunk,
/// checking the state, and getting the allocator.
tree: *FatTree,
/// DO NOT MODIFY, but can access directly.
/// Position of this chunk within the FatTree.
/// Should not be ever modified.
treePos: TreeLayerIndices,
/// Do not access directly. Will always be a valid pointer of a length of 1 or more.
/// The first entry is the state of an air block, meaning that initializing _blockStateIds to all 0's
/// means the chunk is full of air.
/// NOTE: A chunk that is only air will be eventually cleaned up and replaced with an empty FatTree node.
_blockStatesData: [*]BlockState,
/// Do not access directly. Will always be non-zero
_blockStatesLen: u16 = 1,
/// Do not access directly. Will always be non-zero
_blockStatesCapacity: u16 = DEFAULT_BLOCK_STATE_CAPACITY,

// NOTE there is space for 4 bytes due to padding

/// Holds which index each block in the chunk is using as a reference to it's block state.
/// This allows multiple blocks to reference the same block state.
_blockStateIndices: BlockStateIndices,
/// If no blocks are being broken in the chunk, this is null
/// It's overwhelmingly likely that no block is being broken in
/// any given chunk, so storing the extra data would be a waste of memory.
_breakingProgress: ?*ArrayListUnmanaged(BlockBreakingProgress) = null,

///
pub fn init(tree: *FatTree, treePos: TreeLayerIndices) Allocator.Error!*Self {
    const newSelf = try tree.allocator.create(Self);

    const blockStatesSlice = try tree.allocator.alloc(BlockState, DEFAULT_BLOCK_STATE_CAPACITY);
    const indicesPtr = try BlockStateIndices.init(tree.allocator);

    newSelf.* = Self{
        ._blockStatesData = blockStatesSlice.ptr,
        .tree = tree,
        .treePos = treePos,
        ._blockStateIndices = indicesPtr,
    };

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

fn blockStateIndexAt(self: *const Self, position: BlockIndex) u16 {
    self._blockStateIndices.blockStateIndexAt(position);
}

fn setBlockStateIndexAt(self: *Self, index: u16, position: BlockIndex) void {
    if (index >= self._blockStatesLen) {
        @panic("Index of chunk block states out of range.");
    }

    self._blockStateIndices.setBlockStateIndexAt(index, position);
}

const BlockBreakingProgress = struct {
    progress: f32,
    position: BlockIndex,
};

// Tests

test "Size and Align" {
    //std.log.warn("size of chunk inner: {} bytes\n", .{@sizeOf(Self)});
    //std.log.warn("size of rw lock: {} bytes\n", .{@sizeOf(RwLock)});

    try expect(@alignOf(Self) == 8);

    // const sizeOfBlockStateIds = @sizeOf(u16) * CHUNK_SIZE;
    // const sizeOfLights = @sizeOf(BlockLight) * CHUNK_SIZE;
    try expect(@sizeOf(Self) == 104);
}

test "Init deinit" {
    const tree = try FatTree.init(std.testing.allocator);
    defer tree.deinit();

    const inner = try Self.init(tree, TreeLayerIndices{});
    inner.deinit();
}
