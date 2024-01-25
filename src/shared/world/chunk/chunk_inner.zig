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

const Self = @This();

/// Do not access directly
_lock: RwLock,
/// Do not access directly
_blockStateIds: [CHUNK_SIZE]u16 align(64),
/// Do not access directly
_light: [CHUNK_SIZE]BlockLight align(64),
/// Do not access directly
_blockStates: ArrayList(usize),
/// DO NOT MODIFY
/// Allows immediately going to the head of the tree that owns this chunk,
/// checking the state, and getting the allocator.
tree: *NTree,
/// DO NOT MODIFY.
/// Position of this chunk within the NTree.
/// Should not be ever modified.
treePos: TreeLayerIndices,

pub fn deinit(self: *Self) void {
    // During `.chunkModifyOnly`, only the data within the chunk can be modified.
    // The actual tree nodes cannot be deleted.
    assert(self.tree.state() == .treeModify);
    const allocator = self.tree.allocator;
    self._blockStates.deinit();
    allocator.destroy(self);
}
