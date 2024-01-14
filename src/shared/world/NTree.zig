//! Structure representing the entire world state.
//! It's similar to an octree, but instead of being 2x2x2, it's
//! `TREE_NODE_LENGTH` * `TREE_NODE_LENGTH` * `TREE_NODE_LENGTH`.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const RwLock = std.Thread.RwLock;
const TreeLayerIndices = @import("TreeLayerIndices.zig");
const Chunk = @import("chunk/Chunk.zig");
const Atomic = std.atomic.Atomic;
const Ordering = std.atomic.Ordering;

const Self = @This();

/// Tracks the data modify state of the NTree. If `state` is `.chunkModifyOnly`, ONLY the data
/// within a chunk can be modified. Any attempts to modify the nodes themselves, including insertion and deletion
/// will crash the program.
state: Atomic(State),
allocator: *Allocator,
topLayer: Layer,

///
pub fn init(allocator: Allocator) Allocator.Error!*Self {
    const allocator_ptr = try allocator.create(Allocator);
    allocator_ptr.* = allocator;
    const tree: *Self = try allocator_ptr.create(Self);
    tree.state = Atomic(State).init(.treeModify);
    tree.allocator = allocator_ptr;
    tree.topLayer = Layer.init(null, 0, 0, tree);
    return tree;
}

///
/// Asserts that the NTree's `state` is `.treeModify`.
pub fn deinit(self: *Self) void {
    assert(self.state.load(Ordering.Acquire) == .treeModify);
    self.topLayer.deinit();
    self.allocator.destroy(self.allocator);
}

/// Corresponds with Node union to make a tagged union,
/// but with the advantage of Struct of Arrays for SIMD operations on the tags.
const NodeType = enum(i8) {
    empty,
    child,
    chunk,
    colored,
    light,
};

const Node = extern union {
    empty: usize,
    child: *Layer,
    chunk: *Chunk,
    color: usize, // TODO change this
    light: usize, // TODO change this
};

const Layer = struct {
    /// Allows immediately going to the head of the tree,
    /// checking the state, and getting the allocator.
    tree: *Self,
    parent: ?*Layer,
    indexInParent: u16,
    treeLayer: usize,
    /// Do not access
    types: [TreeLayerIndices.TREE_NODES_PER_LAYER]NodeType align(64), // force 64 byte alignment for avx512
    /// Do not access
    elements: [TreeLayerIndices.TREE_NODES_PER_LAYER]Node align(64),

    /// If `parent` is null, `indexInParent` is useless. Use 0.
    fn init(parent: ?*Layer, indexInParent: u16, treeLayer: usize, tree: *Self) Layer {
        return Layer{
            .tree = tree,
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
                    self.elements[i].child.deinit();
                },
                .chunk => {
                    self.elements[i].chunk.deinit();
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

/// Track the state of tree data access
const State = enum(u8) {
    /// Only the data within chunk nodes are allows to be modified, nothing else.
    chunkModifyOnly,
    /// All of the nodes can be modified, including deleting and inserting nodes / layers.
    treeModify,
};