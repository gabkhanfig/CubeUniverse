//! Structure representing the entire world state.
//! It's similar to an octree, but instead of being 2x2x2, it's
//! `TREE_NODE_LENGTH` * `TREE_NODE_LENGTH` * `TREE_NODE_LENGTH`.
//! NTree instance's will always have a consistent memory address,
//! so storing a reference to it's allocator is safe, as long as the
//! reference's lifetime does not exceed the lifetime of the NTree.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const RwLock = std.Thread.RwLock;
const TreeLayerIndices = @import("TreeLayerIndices.zig");
const Chunk = @import("../chunk/Chunk.zig");
const Atomic = std.atomic.Value;
const AtomicOrder = std.builtin.AtomicOrder;
const TreeNodeColor = @import("../../engine/types/color.zig").TreeNodeColor;

const Self = @This();

/// Has a consistent memory address, so as long as the lifetime of the reference does not live
/// past the lifetime of the NTree, storing a reference to this allocator is safe.
allocator: Allocator,
_inner: Inner,

/// Allocates a new NTree object, initializing it, and taking ownership of `allocator`.
pub fn init(allocator: Allocator) Allocator.Error!*Self {
    const newSelf = try allocator.create(Self);
    newSelf.allocator = allocator;
    newSelf._inner = Inner{
        ._rwLock = .{},
        .topLayer = Layer.init(&newSelf.allocator, 0, null, 0),
        .allocator = &newSelf.allocator,
    };
    return newSelf;
}

/// Calls deinit on all child nodes, and their children,
/// freeing the memory for all chunks, invalidating everything.
pub fn deinit(self: *Self) void {
    if (!self._inner._rwLock.tryLock()) {
        @panic("Cannot deinit NTree while other threads have RwLock access to it's inner data");
    }
    self._inner.topLayer.deinit();
    self._inner._rwLock.unlock();
    const allocator = self.allocator;
    allocator.destroy(self);
}

/// Acquires a shared lock to the `NTree`'s data, returning a `ChunkModify`.
/// Through `ChunkModify`, thread safe access to the chunks within this NTree is guaranteed.
/// Naturally, the chunks themselves still need to be locked appropriately.
pub fn lockChunkModify(self: *Self) ChunkModify {
    self._inner._rwLock.lockShared();
    return ChunkModify{ .topLayer = &self._inner };
}

/// Tries to acquire a shared lock to the Tree's data, returning a `ChunkModify`,
/// or an error if the `NTree` is already exclusively locked through `TreeModify`.
/// Through `ChunkModify`, thread safe access to the chunks within this NTree is guaranteed.
/// Naturally, the chunks themselves still need to be locked appropriately.
pub fn tryLockChunkModify(self: *Self) !ChunkModify {
    if (self._inner._rwLock.tryLockShared()) {
        return ChunkModify{ .topLayer = &self._inner };
    } else {
        return error{Locked};
    }
}

/// Unlocks the shared lock to the `NTree`'s data.
pub fn unlockChunkModify(self: *Self) void {
    self._inner._rwLock.unlockShared();
}

/// Acquires an exclusive lock to the `NTree`'s data, returning a `TreeModify`.
/// Through `TreeModify`, thread safe access to mutate the entire tree's data is guaranteed.
pub fn lockTreeModify(self: *Self) TreeModify {
    self._inner._rwLock.lock();
    return TreeModify{ .topLayer = &self._inner };
}

/// Tries to acquire an exclusive lock to the `NTree`'s data, returning a `TreeModify`,
/// or an error if the `NTree` is already shared locked through `ChunkModify`.
/// Through `TreeModify`, thread safe access to mutate the entire tree's data is guaranteed.
pub fn tryLockTreeModify(self: *Self) !TreeModify {
    if (self._inner._rwLock.tryLock()) {
        return TreeModify{ .topLayer = &self._inner };
    } else {
        return error{Locked};
    }
}

/// Unlocks the exclusive lock to the `NTree`'s data.
pub fn unlockTreeModify(self: *Self) void {
    self._inner._rwLock.unlock();
}

const Inner = struct {
    _rwLock: RwLock,
    topLayer: Layer,
    allocator: *Allocator,
};

/// Corresponds with `Node` union to make a tagged union,
/// but with the advantage of Struct of Arrays for SIMD operations on the tags.
const NodeType = enum(i8) {
    empty,
    child,
    chunk,
    colored,
    light,
};

/// Corresponds with `NodeType` enum to make a tagged union,
/// but with the advantage of Struct of Arrays for SIMD operations on the tags.
const Node = extern union {
    empty: u16,
    child: u16,
    chunk: u16,
    color: TreeNodeColor,
    light: u16, // TODO change this
};
// TODO maybe in future separate the light node into it's own thing?

const Layer = struct {
    // This is the allocator used by the tree.
    allocator: *Allocator,
    parent: ?*Layer,
    indexInParent: u16,
    treeLayer: u8,
    /// Do not access
    types: [TreeLayerIndices.TREE_NODES_PER_LAYER]NodeType align(64), // force 64 byte alignment for avx512
    /// Do not access
    elements: [TreeLayerIndices.TREE_NODES_PER_LAYER]Node align(64),

    _chunks: [*]Chunk = undefined,
    _children: [*]*Layer = undefined,
    _chunksLen: u16 = 0,
    _chunksCapacity: u16 = 0,
    _childrenLen: u16 = 0,
    _childrenCapacity: u16 = 0,

    /// If `parent` is null, `indexInParent` is useless. Use 0.
    fn init(allocator: *Allocator, treeLayer: u8, parent: ?*Layer, indexInParent: u16) Layer {
        assert(treeLayer < TreeLayerIndices.TREE_LAYERS);

        return Layer{
            //.tree = tree,
            .allocator = allocator,
            .parent = parent,
            .indexInParent = indexInParent,
            .treeLayer = treeLayer,
            .types = .{.empty} ** TreeLayerIndices.TREE_NODES_PER_LAYER,
            .elements = .{Node{ .empty = 0 }} ** TreeLayerIndices.TREE_NODES_PER_LAYER,
        };
    }

    fn deinit(self: *Layer) void {
        for (0..TreeLayerIndices.TREE_NODES_PER_LAYER) |i| {
            switch (self.types[i]) {
                .empty => {},
                .child => {
                    //self.elements[i].child.deinit();
                    const index = self.elements[i].child;
                    assert(index < self._childrenLen);
                    self._children[index].deinit();
                },
                .chunk => {
                    //self.elements[i].chunk.deinit();
                    const index = self.elements[i].chunk;
                    assert(index < self._chunksLen);
                    self._chunks[index].deinit();
                },
                .colored => {},
                .light => {},
            }
        }
    }

    pub fn isAllEmpty(self: Layer) bool { // TODO optimize with avx512
        for (0..TreeLayerIndices.TREE_NODES_PER_LAYER) |i| {
            if (self.types[i] != .empty) return false;
        }
        return true;
    }
};

/// Wrapper around NTree that only permits mutation operations on Chunks,
/// or reading the NTree nodes. The nodes cannot be modified.
/// Uses shared locking.
///
/// # Note
///
/// Any chunk fetched using `ChunkModify` will also need to be locked accordingly.
pub const ChunkModify = struct {
    inner: *anyopaque,
};

/// Wrapper around NTree that permits full mutation on the tree structure.
/// Uses exclusive locking.
pub const TreeModify = struct {
    inner: *anyopaque,
};

test "Node size and align" {
    try expect(@sizeOf(Node) == 2);
    try expect(@alignOf(Node) == 2);
}

test "Layer align" {
    try expect(@alignOf(Layer) == 64);
}

test "init deinit NTree" {
    var tree = try Self.init(std.testing.allocator);
    tree.deinit();
}
