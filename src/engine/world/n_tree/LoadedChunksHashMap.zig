//! Spatial hashing for the active chunks owned by the `NTree`.
//! Allows extremely fast fetching of chunks, without having
//! to traverse the entire tree structure.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Chunk = @import("../chunk/chunk.zig");
const TreeLayerIndices = @import("tree_layer_indices.zig").TreeLayerIndices;
const NTree = @import("NTree.zig");
const assert = std.debug.assert;
const expect = std.testing.expect;

const Self = @This();

groups: []Group,
chunkCount: usize = 0,
allocator: *Allocator, // NOTE this field may be unnecessary, as the `Inner` owning this has a reference to the same allocator

pub fn init(allocator: *Allocator) Self {
    var slice: []Group = undefined;
    slice.len = 0;
    return Self{ .groups = slice, .allocator = allocator };
}

/// Does not call deinit on the chunks, since this map only stores references to them.
pub fn deinit(self: Self) void {
    if (self.chunkCount == 0) {
        return;
    }

    for (self.groups) |group| {
        group.deinit(self.allocator);
    }
    self.allocator.free(self.groups);
}

pub fn find(self: Self, key: TreeLayerIndices) ?Chunk {
    if (self.chunkCount == 0) {
        return null;
    }

    const hashCode = key.hash();
    const groupBitmask = HashGroupBitmask.init(hashCode);
    const groupIndex = @mod(groupBitmask.value, self.groups.len);

    const found = self.groups[groupIndex].find(key, hashCode);
    if (found == null) {
        return null;
    }

    return self.groups[groupIndex].pairs[found.?].value;
}

/// Trying to add a duplicate entry is strictly not allowed, because it is not allowed by the NTree.
/// Asserts the entry doesn't already exist.
pub fn insert(self: *Self, key: TreeLayerIndices, value: Chunk) Allocator.Error!void {
    if (self.shouldReallocate(self.chunkCount + 1)) {
        try self.reallocate(self.chunkCount + 1);
    }

    const hashCode = key.hash();
    const groupBitmask = HashGroupBitmask.init(hashCode);
    const groupIndex = @mod(groupBitmask.value, self.groups.len);

    try self.groups[groupIndex].insert(key, value, hashCode, self.allocator);
    self.chunkCount += 1;
}

/// Erase a chunk reference entry from the cached map.
/// Asserts that the entry exists.
pub fn erase(self: *Self, key: TreeLayerIndices) void {
    if (self.chunkCount == 0) return;

    const hashCode = key.hash();
    const groupBitmask = HashGroupBitmask.init(hashCode);
    const groupIndex = @mod(groupBitmask.value, self.groups.len);

    const result = self.groups[groupIndex].erase(key, hashCode, self.allocator);
    self.chunkCount -= 1;
    if (result == false) {
        @panic("Cannot erase chunk entry that is not mapped");
    }
}

fn shouldReallocate(self: Self, requiredCapacity: usize) bool {
    if (self.groups.len == 0) {
        return true;
    }

    const loadFactorScaledPairCount = @shrExact(self.chunkCount & ~@as(usize, 0b11), 2) * 3; // multiply by 0.75
    return requiredCapacity > loadFactorScaledPairCount;
}

fn reallocate(self: *Self, requiredCapacity: usize) Allocator.Error!void {
    const newGroupCount = calculateNewGroupCount(requiredCapacity);
    if (newGroupCount <= self.groups.len) {
        return;
    }

    const newGroups = try self.allocator.alloc(Group, newGroupCount);
    for (0..newGroups.len) |i| {
        newGroups[i] = try Group.init(self.allocator);
    }

    for (self.groups) |oldGroup| {
        for (0..oldGroup.capacity) |i| {
            if (oldGroup.hashMasks[i] == 0) {
                continue;
            }

            const pair = oldGroup.pairs[i];
            const hashCode = pair.key.hash();
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, self.groups.len);

            const newGroup = &newGroups[groupIndex];

            if (newGroup.pairCount == newGroup.capacity) {
                try newGroup.reallocate(newGroup.capacity * 2, self.allocator);
            }

            newGroup.hashMasks[newGroup.pairCount] = oldGroup.hashMasks[i];
            newGroup.pairs[newGroup.pairCount] = pair;
            newGroup.pairCount += 1;
        }

        const currentAllocationSize = calculateChunksHashGroupAllocationSize(oldGroup.capacity);

        var allocSlice: []align(64) u8 = undefined;
        allocSlice.ptr = oldGroup.hashMasks;
        allocSlice.len = currentAllocationSize;

        self.allocator.free(allocSlice);
    }

    if (self.groups.len > 0) {
        self.allocator.free(self.groups);
    }

    self.groups = newGroups;
}

fn calculateNewGroupCount(requiredCapacity: usize) usize {
    if (requiredCapacity < Group.GROUP_ALLOC_SIZE) {
        return 1;
    } else {
        const out = requiredCapacity / (Group.GROUP_ALLOC_SIZE / 16);
        return out;
    }
}

const Group = struct {
    const GROUP_ALLOC_SIZE = 64;
    const INITIAL_ALLOCATION_SIZE = calculateChunksHashGroupAllocationSize(64);
    const ALIGNMENT = 64;

    hashMasks: [*]align(64) u8,
    pairs: [*]*Pair,
    pairCount: usize = 0,
    capacity: usize = GROUP_ALLOC_SIZE,

    fn init(allocator: *Allocator) Allocator.Error!Group {
        const memory = try allocator.alignedAlloc(u8, ALIGNMENT, INITIAL_ALLOCATION_SIZE);
        @memset(memory, 0);

        const hashMasks = memory.ptr;
        const pairs: [*]*Pair = @ptrCast(memory.ptr + GROUP_ALLOC_SIZE);

        return Group{
            .hashMasks = hashMasks,
            .pairs = pairs,
        };
    }

    fn deinit(self: Group, allocator: *Allocator) void {
        for (0..self.capacity) |i| {
            if (self.hashMasks[i] == 0) {
                continue;
            }

            allocator.destroy(self.pairs[i]);
        }

        const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);

        var allocSlice: []align(64) u8 = undefined;
        allocSlice.ptr = self.hashMasks;
        allocSlice.len = currentAllocationSize;

        allocator.free(allocSlice);
    }

    fn find(self: Group, key: TreeLayerIndices, hashCode: usize) ?usize {
        // TODO avx

        //const iterationCount = self.capacity / GROUP_ALLOC_SIZE;

        const mask = HashPairBitmask.init(hashCode);

        for (0..self.capacity) |i| {
            if (self.hashMasks[i] != mask.value) {
                continue;
            }

            if (self.pairs[i].key.equal(key)) {
                return i;
            }
        }

        return null;
    }

    /// Asserts that the entry doesn't exist.
    fn insert(self: *Group, key: TreeLayerIndices, value: Chunk, hashCode: usize, allocator: *Allocator) Allocator.Error!void {
        const mask = HashPairBitmask.init(hashCode);

        if (comptime std.debug.runtime_safety) {
            const existingIndex = self.find(key, hashCode);
            if (existingIndex != null) {
                @panic("Cannot add duplicate chunk entries");
            }
        }

        if (self.pairCount == self.capacity) {
            try self.reallocate(self.capacity * 2, allocator);
        }

        // TODO avx
        for (0..self.capacity) |i| {
            if (self.hashMasks[i] != 0) {
                continue;
            }

            const newPair = try allocator.create(Pair);
            newPair.key = key;
            newPair.value = value;

            self.hashMasks[i] = mask.value;
            self.pairs[i] = newPair;
            self.pairCount += 1;
            return;
        }

        @panic("Unreachable. Insert a mapped NTree chunk failed.");
    }

    fn erase(self: *Group, key: TreeLayerIndices, hashCode: usize, allocator: *Allocator) bool {
        const found = self.find(key, hashCode);

        if (found == null) {
            return false;
        }

        self.hashMasks[found.?] = 0;
        allocator.destroy(self.pairs[found.?]);
        self.pairCount -= 1;
        return true;
    }

    fn reallocate(self: *Group, newCapacity: usize, allocator: *Allocator) Allocator.Error!void {
        assert(newCapacity % 64 == 0);
        assert(newCapacity > self.capacity);

        const memory = try allocator.alignedAlloc(u8, ALIGNMENT, newCapacity);
        @memset(memory, 0);

        const hashMasks = memory.ptr;
        const pairs: [*]*Pair = @ptrCast(@alignCast(memory.ptr + newCapacity));

        var moved: usize = 0;
        for (0..newCapacity) |i| {
            if (self.hashMasks[i] == 0) {
                continue;
            }

            hashMasks[i] = self.hashMasks[i];
            pairs[i] = self.pairs[i];
            moved += 1;
        }

        {
            const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);
            var allocSlice: []align(64) u8 = undefined;
            allocSlice.ptr = self.hashMasks;
            allocSlice.len = currentAllocationSize;

            allocator.free(allocSlice);
        }

        self.hashMasks = hashMasks;
        self.pairs = pairs;
        self.capacity = newCapacity;
    }

    const Pair = struct {
        // NOTE if TreeLayerIndices has a hash function that isn't just returning the internal mask, cache the hash code.
        key: TreeLayerIndices,
        value: Chunk,
    };
};

const HashGroupBitmask = struct {
    const BITMASK = 18446744073709551488; // ~0b1111111 as usize

    value: usize,

    fn init(hashCode: usize) HashGroupBitmask {
        return HashGroupBitmask{ .value = @shrExact(hashCode & BITMASK, 7) };
    }
};

const HashPairBitmask = struct {
    const BITMASK = 127; // 0b1111111
    const SET_FLAG = 0b10000000;

    value: u8,

    fn init(hashCode: usize) HashPairBitmask {
        return HashPairBitmask{ .value = @intCast((hashCode & BITMASK) | SET_FLAG) };
    }
};

fn calculateChunksHashGroupAllocationSize(requiredCapacity: usize) usize {
    assert(requiredCapacity % 64 == 0);

    // number of hash masks + size of pointer * required capacity;
    return requiredCapacity + (@sizeOf(*Self.Group.Pair) * requiredCapacity);
}

test "calculateChunksHashGroupAllocationSize 64" {
    try expect(calculateChunksHashGroupAllocationSize(64) == 576);
}

test "Group size and align" {
    try expect(@sizeOf(Group) == 32);
    try expect(@alignOf(Group) == 8);
}

test "Init deinit" {
    var allocator = std.testing.allocator;

    const map = Self.init(&allocator);
    map.deinit();
}

test "Insert chunk" {
    var allocator = std.testing.allocator;

    const tree = try NTree.init(allocator);
    defer tree.deinit();

    var map = Self.init(&allocator);
    defer map.deinit();

    const indices = TreeLayerIndices{};

    var chunk = try Chunk.init(tree, indices);
    defer chunk.deinit();

    try map.insert(indices, chunk);
}
