//! Structure representing an entire world state.
//! It's similar to an octree, but instead of being 2x2x2, it's
//! `TREE_NODE_LENGTH` * `TREE_NODE_LENGTH` * `TREE_NODE_LENGTH`.
//! FatTree instance's will always have a consistent memory address,
//! so storing a reference to it's allocator is safe, as long as the
//! reference's lifetime does not exceed the lifetime of the FatTree.
//!
//! # Thread-safe access
//!
//! The `FatTree`'s data can be accessed in two distinct ways.
//! - Chunk modification only
//! - Full tree modification
//!
//! With chunk-only modification, chunks/layers/nodes cannot be added,
//! removed, or anything else from the tree. The only thing permitted
//! are read/write operations on the data chunks own. The chunks naturally
//! have to be appropriately locked. This `FatTree` locking mode allows multiple
//! threads to have shared access to the chunks, and reading the state of the tree.
//!
//! With full tree modification, the entire tree can be modified freely through
//! the use of exclusive locking.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const RwLock = std.Thread.RwLock;
const tree_layer_indices = @import("tree_layer_indices.zig");
const TreeLayerIndices = tree_layer_indices.TreeLayerIndices;
const Chunk = @import("../chunk/Chunk.zig");
const Atomic = std.atomic.Value;
const AtomicOrder = std.builtin.AtomicOrder;
const TreeNodeColor = @import("../../types/color.zig").TreeNodeColor;
const LoadedChunksHashMap = @import("LoadedChunksHashMap.zig");

const Self = @This();

/// Has a consistent memory address, so as long as the lifetime of the reference does not live
/// past the lifetime of the FatTree, storing a reference to this allocator is safe.
allocator: Allocator,
_inner: Inner,

/// Allocates a new FatTree object, initializing it, and taking ownership of `allocator`.
pub fn init(allocator: Allocator) Allocator.Error!*Self {
    const newSelf = try allocator.create(Self);
    newSelf.allocator = allocator;
    newSelf._inner = Inner.init(&newSelf.allocator);
    return newSelf;
}

/// Calls deinit on all child nodes, and their children,
/// freeing the memory for all chunks, invalidating everything.
///
/// # Thread safety
///
/// The programmer must ensure no other thread is even trying to access
/// the `FatTree` data. Naturally, any thread awaiting invalid memory
/// is completely unsafe.
pub fn deinit(self: *Self) void {
    self._inner.deinit();
    const allocator = self.allocator;
    allocator.destroy(self);
}

/// Acquires a shared lock to the `FatTree`'s data, returning a `ChunkModify`.
/// Through `ChunkModify`, thread safe access to the chunks within this FatTree is guaranteed.
/// Naturally, the chunks themselves still need to be locked appropriately.
pub fn lockChunkModify(self: *Self) *const Inner {
    self._inner._rwLock.lockShared();
    return &self._inner;
}

/// Tries to acquire a shared lock to the Tree's data, returning a `ChunkModify`,
/// or an error if the `FatTree` is already exclusively locked through `TreeModify`.
/// Through `ChunkModify`, thread safe access to the chunks within this FatTree is guaranteed.
/// Naturally, the chunks themselves still need to be locked appropriately.
pub fn tryLockChunkModify(self: *Self) ?*const Inner {
    if (self._inner._rwLock.tryLockShared()) {
        return &self._inner;
    } else {
        return null;
    }
}

/// Unlocks the shared lock to the `FatTree`'s data.
pub fn unlockChunkModify(self: *Self) void {
    self._inner._rwLock.unlockShared();
}

/// Acquires an exclusive lock to the `FatTree`'s data, returning a `TreeModify`.
/// Through `TreeModify`, thread safe access to mutate the entire tree's data is guaranteed.
pub fn lockTreeModify(self: *Self) *Inner {
    self._inner._rwLock.lock();
    return &self._inner;
}

/// Tries to acquire an exclusive lock to the `FatTree`'s data, returning a `TreeModify`,
/// or an error if the `FatTree` is already shared locked through `ChunkModify`.
/// Through `TreeModify`, thread safe access to mutate the entire tree's data is guaranteed.
pub fn tryLockTreeModify(self: *Self) ?*Inner {
    if (self._inner._rwLock.tryLock()) {
        return &self._inner;
    } else {
        return null;
    }
}

/// Unlocks the exclusive lock to the `FatTree`'s data.
pub fn unlockTreeModify(self: *Self) void {
    self._inner._rwLock.unlock();
}

pub const Inner = struct {
    _rwLock: RwLock,
    topNode: Node,
    chunks: LoadedChunksHashMap,
    allocator: *Allocator,

    fn init(allocator: *Allocator) Inner {
        return Inner{
            ._rwLock = .{},
            .topNode = Node.init(),
            .chunks = LoadedChunksHashMap.init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *Inner) void {
        if (!self._rwLock.tryLock()) {
            @panic("Cannot deinit FatTree while other threads have RwLock access to it's inner data");
        }

        // Free all owned stuff.
        self.topNode.deinit();
        self.chunks.deinit();

        self._rwLock.unlock();
    }

    pub fn chunkAt(self: *const Inner, position: TreeLayerIndices) ?Chunk {
        return self.chunks.find(position);
    }
};

/// Corresponds with `NodeType` enum to make a tagged union,
/// but with the advantage of Struct of Arrays for SIMD operations on the tags.
const Node = struct { // TODO store LOD data inline?
    const POINTER_MASK: usize = 0x0000FFFFFFFFFFFF;
    const TYPE_MASK: usize = 0xF000000000000000;
    const TYPE_SHIFT: u6 = 48;

    pub const Type = enum(usize) {
        empty = 0,
        childLayer = @shlExact(1, TYPE_SHIFT),
        noodleLayer = @shlExact(2, TYPE_SHIFT),
        chunk = @shlExact(3, TYPE_SHIFT),
    };

    value: usize,

    pub fn init() Node {
        return Node{ .value = 0 };
    }

    /// Calls `deinit()` on the chunk or child layer,
    /// depending on if this node is either.
    pub fn deinit(self: *Node) void {
        switch (self.nodeType()) {
            .empty => {},
            .childLayer => {
                var c = self.childLayer();
                c.deinit();
            },
            .noodleLayer => {
                var c = self.noodleLayer();
                c.deinit();
            },
            .chunk => {
                var c = self.chunk();
                c.deinit();
            },
        }
    }

    pub fn nodeType(self: Node) Type {
        const maskedTag = self.value & TYPE_MASK;
        return @enumFromInt(maskedTag);
    }

    /// Asserts that this node is a child layer node.
    /// Get the child layer data of this node.
    pub fn childLayer(self: Node) *Layer {
        assert(self.nodeType() == .childLayer);
        return @ptrFromInt(self.value & POINTER_MASK);
    }

    pub fn noodleLayer(self: Node) *NoodleLayer {
        assert(self.nodeType() == .noodleLayer);
        return @ptrFromInt(self.value & POINTER_MASK);
    }

    /// Asserts that this node is a chunk node.
    /// Get the chunk data of this node.
    pub fn chunk(self: Node) Chunk {
        assert(self.nodeType() == .chunk);
        return Chunk{ .inner = @ptrFromInt(self.value & POINTER_MASK) };
    }

    /// Calls `deinit()`.
    /// Sets this node to hold no data.
    pub fn setEmpty(self: *Node) void {
        self.deinit();
        self.value = 0;
    }

    /// Calls `deinit()`.
    /// Sets this node to hold a `Chunk`.
    pub fn setChunk(self: *Node, newChunk: Chunk) void {
        self.deinit();
        const chunkAsUSize: usize = @bitCast(newChunk);

        self.value = @intFromEnum(Type.chunk) | chunkAsUSize;
    }

    /// Calls `deinit()`.
    /// Sets this node to hold a `Layer`, taking ownership of `newLayer`.
    pub fn setChildLayer(self: *Node, newLayer: *Layer) void {
        self.deinit();
        const layerAsUSize: usize = @intFromPtr(newLayer);

        self.value = @intFromEnum(Type.childLayer) | layerAsUSize;
    }

    /// Calls `deinit()` on self.
    /// Set this node to hold a `NoodleLayer`, taking ownership of `newNoodle`.
    pub fn setNoodleLayer(self: *Node, newNoodle: *NoodleLayer) void {
        self.deinit();
        const noodleAsUsize: usize = @intFromPtr(newNoodle);

        self.value = @intFromEnum(Type.childLayer) | noodleAsUsize;
    }
};

const Layer = struct {
    /// This is the allocator used by the tree.
    allocator: *Allocator,
    /// DO NOT MODIFY
    treeLayer: u8,
    nodes: [tree_layer_indices.TREE_NODES_PER_LAYER]Node align(64),

    /// If `parent` is null, `indexInParent` is useless. Use 0.
    pub fn init(allocator: *Allocator, treeLayer: u8) Allocator.Error!*Layer {
        const self = try allocator.create(Layer);
        self.* = Layer.create(allocator, treeLayer);
        return self;
    }

    /// Frees the memory associated with `self`. Assumes this `self` was
    /// created using `init()`, and thus was allocated using an allocator, not in-place.
    pub fn deinit(self: *Layer) void {
        self.deinitWithoutFree();
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    /// Does not free the memory associated with `self`.
    pub fn deinitWithoutFree(self: *Layer) void {
        for (0..tree_layer_indices.TREE_NODES_PER_LAYER) |i| {
            self.nodes[i].deinit();
        }
    }

    fn create(allocator: *Allocator, treeLayer: u8) Layer {
        assert(treeLayer < tree_layer_indices.TREE_LAYERS);

        return Layer{
            //.tree = tree,
            .allocator = allocator,
            .treeLayer = treeLayer,
            .nodes = .{Node.init()} ** tree_layer_indices.TREE_NODES_PER_LAYER,
        };
    }

    pub fn isAllEmpty(self: Layer) bool { // TODO optimize with avx512
        for (0..tree_layer_indices.TREE_NODES_PER_LAYER) |i| {
            if (self.nodes[i].nodeType() == .empty) return false;
        }
        return true;
    }
};

const NoodleLayer = struct {
    indices: [tree_layer_indices.TREE_LAYERS]TreeLayerIndices.Index,
    jumpStart: u4 = 0,
    jumpEnd: u4 = 0,
    layer: Layer,

    /// Creates a new instance of `NoodleLayer`.
    /// `indices` specifies the indices that are being skipped over, ranging from `layerStart` to `layerEnd` inclusively.
    /// `layerEnd` will be the resulting layer's `treeLayer`.
    pub fn init(allocator: *Allocator, indices: TreeLayerIndices, layerStart: u4, layerEnd: u4) Allocator.Error!*NoodleLayer {
        var self = try allocator.create(NoodleLayer);
        self.* = NoodleLayer{
            .indices = TreeLayerIndices.Index{ .index = 255 } ** tree_layer_indices.TREE_LAYERS, // Enforce invalid indices for the layers this Noodle does not cover.
            .jumpStart = layerStart,
            .jumpEnd = layerEnd,
            .layer = Layer.create(allocator, layerEnd),
        };

        for (layerStart..(layerEnd + 1)) |i| {
            self.indices[i] = indices.indexAtLayer(i);
        }

        return self;
    }

    /// Frees self.
    pub fn deinit(self: *NoodleLayer) void {
        self.layer.deinitWithoutFree();
        const allocator = self.layer.allocator;
        allocator.destroy(self);
    }
};

test "Node size and align" {
    try expect(@sizeOf(Node) == 8);
    try expect(@alignOf(Node) == 8);
}

test "Layer NoodleLayer align" {
    // There will be a lot of multithreaded tomfoolery going on
    try expect(@alignOf(Layer) == 64);
    try expect(@alignOf(NoodleLayer) == 64);
}

test "init deinit FatTree" {
    var tree = try Self.init(std.testing.allocator);
    tree.deinit();
}
