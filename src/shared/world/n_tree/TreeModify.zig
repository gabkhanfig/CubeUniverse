//! Wrapper around NTree that permits full mutation on the tree structure.
//! Uses exclusive locking.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const NTree = @import("NTree.zig");
const Inner = NTree.Inner;
const Chunk = @import("../chunk/Chunk.zig");
const TreeLayerIndices = @import("TreeLayerIndices.zig");

const Self = @This();

inner: *anyopaque,

/// Fetch the chunk at a given `position` within the `NTree` structure.
/// Returns `null` if the chunk at `position` isn't loaded.
pub fn chunkAt(self: Self, position: TreeLayerIndices) ?Chunk {
    return self.getInner().chunks.find(position);
}

/// Load from disk, or world generation
/// Not yet implemented
pub fn loadChunk(_: *Self, _: TreeLayerIndices) !void {
    @panic("not yet implemented");
}

/// Calls `deinit()` on the chunk, and unloads it, performing any necessary cleanup steps,
/// and saving to disk only if the chunk is flagged as having been
/// modified from world generation.
pub fn unloadChunk(_: *Self, _: TreeLayerIndices) !void {
    @panic("not yet implemented, also need to implement chunk has-been-modified flag");
}

fn getInner(self: Self) *const Inner {
    return @ptrCast(@alignCast(self.inner));
}

fn getInnerMut(self: Self) *Inner {
    return @ptrCast(@alignCast(self.inner));
}
