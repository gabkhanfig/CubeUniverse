//! Owns `CHUNK_SIZE` blocks within, and uses an RwLock for multithread access.
//! This struct simply a wrapper around the allocated inner data, which must be accessed through either
//! calling `read()`, `tryRead()`, `write()`, or `tryWrite()`.

const std = @import("std");
const world_transform = @import("../world_transform.zig");
const RwLock = std.Thread.RwLock;
const ArrayList = std.ArrayList;
const TreeLayerIndices = @import("../n_tree/tree_layer_indices.zig").TreeLayerIndices;
const NTree = @import("../n_tree/NTree.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const BlockLight = @import("../../types/light.zig").BlockLight;
const DEBUG = std.debug.runtime_safety;

const Self = @This();

pub const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
pub const CHUNK_SIZE = world_transform.CHUNK_SIZE;

pub const Inner = @import("Inner.zig");

inner: *anyopaque,

/// Create a new Chunk instance using `allocator`.
/// If allocation fails, returns an error.
pub fn init(tree: *NTree, treePos: TreeLayerIndices) Allocator.Error!Self {
    const newInner = try Inner.init(tree, treePos);
    return Self{ .inner = @ptrCast(newInner) };
}

/// # Thread safety
///
/// Only call `deinit()` through the owning `NTree`'s `TreeModify` access.
/// Asserts that no other thread has locked the chunk. If another thread has,
/// that would mean the `NTree` is not exclusively locked.
///
/// The programmer must ensure no other thread is even trying to access
/// the `Chunk` data. Naturally, any thread awaiting invalid memory
/// is completely unsafe.
pub fn deinit(self: *Self) void {
    const innerPtr = self.getInnerPtrMut(); // maybe lock?
    innerPtr.deinit();
}

/// Get read-only access to the chunk's inner data.
/// Will wait until no thread has exclusive access to the lock.
/// Call `unlockRead()` when done.
pub fn read(self: *const Self) *const Inner {
    const innerPtr = self.getInnerPtr();
    innerPtr._lock.lockShared();
    return innerPtr;
}

/// Try to get read-only access to the chunk's inner data.
/// Returns either the chunk data, or an error if another thread has exclusive access to the lock.
/// Call `unlockRead()` when done.
pub fn tryRead(self: *const Self) !*const Inner {
    const innerPtr = self.getInnerPtr();
    if (innerPtr._lock.tryLockShared()) {
        return innerPtr;
    }
    return error{Locked};
}

/// Get read-write access to the chunk's inner data.
/// Will wait until no thread has exclusive or shared access to the lock.
/// Call `unlockWrite()` when done.
pub fn write(self: *Self) *Inner {
    const innerPtr = self.getInnerPtrMut();
    innerPtr._lock.lock();
    return innerPtr;
}

/// Try to get read-write access to the chunk's inner data.
/// Returns either the chunk data, or an error if another thread has exclusive or shared access to the lock.
/// Call `unlockWrite()` when done.
pub fn tryWrite(self: *Self) !*Inner {
    const innerPtr = self.getInnerPtrMut();
    if (innerPtr._lock.tryLock()) {
        return innerPtr;
    }
    return error{Locked};
}

/// Revoke shared access to this chunk's inner data.
/// It is undefined behaviour to continue to access the data after unlocking.
pub fn unlockRead(self: *const Self) void {
    const innerPtr = self.getInnerPtrMut();
    innerPtr._lock.unlockShared();
}

/// Revoke exclusive access to this chunk's inner data.
/// It is undefined behaviour to continue to access the data after unlocking.
pub fn unlockWrite(self: *Self) void {
    const innerPtr = self.getInnerPtrMut();
    innerPtr._lock.unlock();
}

/// Get readonly access to the chunk's inner data in a way that does not require locking.
/// In `Debug` and `ReleaseSafe`, checks that no other thread has exclusive access.
/// Panics if a thread has exclusive access.
/// In `ReleaseFast` and `ReleaseSmall`, these checks are disabled.
pub fn unsafeRead(self: *const Self) *const Inner {
    if (comptime DEBUG) {
        if (self.tryRead()) |chunkInner| {
            defer self.unlockRead();
            return chunkInner;
        } else |_| {
            @panic("Chunk currently has exclusive access. Cannot read without locking.");
        }
    } else {
        return self.getInnerPtr();
    }
}

/// Get the chunk's inner data immutably.
fn getInnerPtr(self: *const Self) *const Inner {
    return @ptrCast(@alignCast(self.inner));
}

/// Get the chunk's inner data mutably.
fn getInnerPtrMut(self: *Self) *Inner {
    return @ptrCast(@alignCast(self.inner));
}
// Tests

test "init deinit chunk inner" {
    const tree = try NTree.init(std.testing.allocator);
    defer tree.deinit();

    var chunk = try Self.init(tree, TreeLayerIndices{});
    defer chunk.deinit();
}
