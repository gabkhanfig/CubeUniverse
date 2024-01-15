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

pub const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
pub const CHUNK_SIZE = world_transform.CHUNK_SIZE;

const Self = @This();

/// Do not access directly
_lock: RwLock,
/// Do not access directly
_inner: Inner,

/// Create a new Chunk instance using `allocator`.
/// If allocation fails, returns an error.
pub fn init(tree: *NTree, treePos: TreeLayerIndices) Allocator.Error!*Self {
    var chunkMem = try tree.allocator.create(Self);
    chunkMem._lock = .{};
    chunkMem._inner = Inner{
        ._blockStateIds = .{0} ** CHUNK_SIZE,
        ._light = .{BlockLight.init(0, 0, 0)} ** CHUNK_SIZE,
        ._blockStates = ArrayList(usize).init(tree.allocator.*),
        .tree = tree,
        .treePos = treePos,
    };
    try chunkMem._inner._blockStates.append(0);
    return chunkMem;
}

/// Will assert that the owning `NTree`'s state is set to `.treeModify`.
/// Acquire exclusive ownership of this chunk, and free all memory associated with it.
/// It's extremely important that no thread is attempting to get access to this chunk,
/// because it will be completely invalidated.
pub fn deinit(self: *Self) void {
    var lock = self._lock;
    lock.lock(); // TODO is this necessary? Chunks should only be destroyed at specific points with a frame, and may not require thread safety
    defer lock.unlock();

    self._inner._blockStates.deinit();
    self._inner.tree.allocator.destroy(self);
}

/// Get read-only access to the chunk's inner data.
/// Will wait until no thread has exclusive access to the lock.
/// Call `unlockRead()` when done.
pub fn read(self: *const Self) *const Inner {
    self._lock.lockShared();
    return &self._inner;
}

/// Try to get read-only access to the chunk's inner data.
/// Returns either the chunk data, or an error if another thread has exclusive access to the lock.
/// Call `unlockRead()` when done.
pub fn tryRead(self: *const Self) !*const Inner {
    if (self._lock.tryLockShared()) {
        return &self._inner;
    }
    return error{Locked};
}

/// Get read-write access to the chunk's inner data.
/// Will wait until no thread has exclusive or shared access to the lock.
/// Call `unlockWrite()` when done.
pub fn write(self: *Self) *Inner {
    self._lock.lock();
    return &self._inner;
}

/// Try to get read-write access to the chunk's inner data.
/// Returns either the chunk data, or an error if another thread has exclusive or shared access to the lock.
/// Call `unlockWrite()` when done.
pub fn tryWrite(self: *Self) !*Inner {
    if (self._lock.tryLock()) {
        return &self._inner;
    }
    return error{Locked};
}

/// Revoke shared access to this chunk's inner data.
/// It is undefined behaviour to continue to access the data after unlocking.
pub fn unlockRead(self: *const Self) void {
    self._lock.unlockShared();
}

/// Revoke exclusive access to this chunk's inner data.
/// It is undefined behaviour to continue to access the data after unlocking.
pub fn unlockWrite(self: *Self) void {
    self._lock.unlock();
}

pub const Inner = struct {
    /// Do not access directly
    _blockStateIds: [CHUNK_SIZE]u16 align(64),
    /// Do not access directly
    _light: [CHUNK_SIZE]BlockLight align(64),
    /// Do not access directly
    _blockStates: ArrayList(usize),
    /// Allows immediately going to the head of the tree that owns this chunk,
    /// checking the state, and getting the allocator.
    tree: *NTree,
    /// Position of this chunk within the NTree.
    /// Should not be ever modified.
    treePos: TreeLayerIndices,

    fn deinit(self: *Inner) void {
        // During `.chunkModifyOnly`, only the data within the chunk can be modified.
        // The actual tree nodes cannot be deleted.
        assert(self.tree.state.load(std.atomic.Ordering.Acquire) == .treeModify);
        const allocator = self.tree.allocator;
        self._blockStates.deinit();
        allocator.destroy(self);
    }
};

test "init deinit chunk inner" {
    const tree = try NTree.init(std.testing.allocator);
    defer tree.deinit();

    const chunk = try Self.init(tree, TreeLayerIndices.init(.{ 1, 2, 3, 4, 5, 6, 7 }));
    defer chunk.deinit();
}
