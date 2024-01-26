//! Contains the inner data of a chunk.

const std = @import("std");
const world_transform = @import("../world_transform.zig");
const RwLock = std.Thread.RwLock;
const ArrayList = std.ArrayList;
const TreeLayerIndices = @import("../TreeLayerIndices.zig");
const NTree = @import("../NTree.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const BlockLight = @import("../../engine/types/light.zig").BlockLight;

const Chunk = @import("chunk.zig").Chunk;
const CHUNK_LENGTH = Chunk.CHUNK_LENGTH;
const CHUNK_SIZE = Chunk.CHUNK_SIZE;

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

/// Do not access directly
//_blockStates: ArrayList(usize),
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
    assert(self.tree.state() == .treeModify);
    const allocator = self.tree.allocator;

    var blockStatesSlice: []BlockState = undefined;
    blockStatesSlice.ptr = self._blockStatesData;
    blockStatesSlice.len = self._blockStatesCapacity;
    allocator.free(blockStatesSlice);
    //self._blockStates.deinit();
    allocator.destroy(self);
}

// Tests

test "Size and Align" {
    //std.log.warn("size of chunk inner: {} bytes\n", .{@sizeOf(Self)});
    //std.log.warn("size of rw lock: {} bytes\n", .{@sizeOf(RwLock)});

    try expect(@alignOf(Self) == 64);

    // const sizeOfBlockStateIds = @sizeOf(u16) * CHUNK_SIZE;
    // const sizeOfLights = @sizeOf(BlockLight) * CHUNK_SIZE;
    try expect(@sizeOf(Self) == 131200);
}
