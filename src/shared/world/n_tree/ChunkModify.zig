//! Wrapper around NTree that only permits mutation operations on Chunks,
//! or reading the NTree nodes. The nodes/layers cannot be modified.
//! Uses shared locking.
//!
//! # Note
//!
//! Any chunk fetched using `ChunkModify` will also need to be locked accordingly.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const NTree = @import("NTree.zig");
const Inner = NTree.Inner;
const Chunk = @import("../chunk/Chunk.zig");
const TreeLayerIndices = @import("tree_layer_indices.zig");

const Self = @This();

inner: *anyopaque,

/// Fetch the chunk at a given `position` within the `NTree` structure.
/// Returns `null` if the chunk at `position` isn't loaded.
pub fn chunkAt(self: Self, position: TreeLayerIndices) ?Chunk {
    return self.getInner().chunks.find(position);
}

fn getInner(self: Self) *const Inner {
    return @ptrCast(@alignCast(self.inner));
}

fn getInnerMut(self: Self) *Inner {
    return @ptrCast(@alignCast(self.inner));
}
