//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const world_transform = @import("../world_transform.zig");
const BlockPosition = world_transform.BlockPosition;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;
const expect = std.testing.expect;

const Self = @This();

const ENUM_MASK: usize = @shlExact(0b11111111, 56);
const PTR_MASK: usize = 0xFFFFFFFFFFFF;

taggedPtr: usize,

pub fn init(allocator: Allocator) Allocator.Error!Self {
    const indexBitWidth = IndexBitWidth.b1;
    const indexBitWidthAsUsize: usize = @intFromEnum(indexBitWidth);
    const indexBitWidthAsTag = @shlExact(indexBitWidthAsUsize, 56);

    const indices = try allocator.create(BlockStateIndices1Bit);

    return Self{ .taggedPtr = @intFromPtr(indices) | indexBitWidthAsTag };
}

pub fn deinit(self: Self, allocator: Allocator) void {
    const maskedEnum = self.taggedPtr & ENUM_MASK;
    const e: IndexBitWidth = @enumFromInt(@shrExact(maskedEnum, 56));
    const ptr: *anyopaque = @ptrFromInt(self.taggedPtr & PTR_MASK);

    switch (e) {
        .b1 => {
            const as1Bit: *BlockStateIndices1Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as1Bit);
        },
        .b2 => {
            const as2Bit: *BlockStateIndices2Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as2Bit);
        },
        .b4 => {
            const as4Bit: *BlockStateIndices4Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as4Bit);
        },
        .b8 => {
            const as8Bit: *BlockStateIndices8Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as8Bit);
        },
        .b16 => {
            const as16Bit: *BlockStateIndices16Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as16Bit);
        },
    }
}

pub fn blockStateIndexAt(self: *const Self, position: BlockPosition) u16 {
    const maskedEnum = self.taggedPtr & ENUM_MASK;
    const e = @as(IndexBitWidth, @shrExact(maskedEnum, 56));
    const ptr = @as(*const anyopaque, self.taggedPtr & PTR_MASK);

    switch (e) {
        .b1 => {
            const as1Bit: *const BlockStateIndices1Bit = @ptrCast(@alignCast(ptr));
            return as1Bit.indexAt(position);
        },
        .b2 => {
            const as2Bit: *const BlockStateIndices2Bit = @ptrCast(@alignCast(ptr));
            return as2Bit.indexAt(position);
        },
        .b4 => {
            const as4Bit: *const BlockStateIndices4Bit = @ptrCast(@alignCast(ptr));
            return as4Bit.indexAt(position);
        },
        .b8 => {
            const as8Bit: *const BlockStateIndices8Bit = @ptrCast(@alignCast(ptr));
            return as8Bit.indexAt(position);
        },
        .b16 => {
            const as16Bit: *const BlockStateIndices16Bit = @ptrCast(@alignCast(ptr));
            return as16Bit.indexAt(position);
        },
    }
}

pub fn setBlockStateIndexAt(self: *Self, index: u16, position: BlockPosition) void {
    const maskedEnum = self.taggedPtr & ENUM_MASK;
    const e = @as(IndexBitWidth, @shrExact(maskedEnum, 56));
    const ptr = @as(*anyopaque, self.taggedPtr & PTR_MASK);

    switch (e) {
        .b1 => {
            const as1Bit: *BlockStateIndices1Bit = @ptrCast(@alignCast(ptr));
            as1Bit.setIndexAt(@intCast(index), position);
        },
        .b2 => {
            const as2Bit: *BlockStateIndices2Bit = @ptrCast(@alignCast(ptr));
            as2Bit.setIndexAt(@intCast(index), position);
        },
        .b4 => {
            const as4Bit: *BlockStateIndices4Bit = @ptrCast(@alignCast(ptr));
            as4Bit.setIndexAt(@intCast(index), position);
        },
        .b8 => {
            const as8Bit: *BlockStateIndices8Bit = @ptrCast(@alignCast(ptr));
            as8Bit.setIndexAt(@intCast(index), position);
        },
        .b16 => {
            const as16Bit: *BlockStateIndices16Bit = @ptrCast(@alignCast(ptr));
            as16Bit.setIndexAt(@intCast(index), position);
        },
    }
}

const IndexBitWidth = enum(u8) {
    b1,
    b2,
    b4,
    b8,
    b16,
};

const BlockStateIndices1Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 64;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices1Bit, position: BlockPosition) u16 {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const bitIndex: u6 = @intCast(positionIndexCast & 63);
        const bitMask = @shlExact(@as(usize, 1), bitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, bitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices1Bit, index: u1, position: BlockPosition) void {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const bitIndex: u6 = @intCast(positionIndexCast & 63);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, bitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices2Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 32;
    const BIT_INDEX_MASK = 31;
    const BIT_INDEX_MULTIPLIER = 2;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices2Bit, position: BlockPosition) u16 {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const bitMask = @shlExact(@as(usize, 0b11), BIT_INDEX_MULTIPLIER * firstBitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, BIT_INDEX_MULTIPLIER * firstBitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices2Bit, index: u2, position: BlockPosition) void {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, BIT_INDEX_MULTIPLIER * firstBitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices4Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 16;
    const BIT_INDEX_MASK = 15;
    const BIT_INDEX_MULTIPLIER = 4;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices4Bit, position: BlockPosition) u16 {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const bitMask = @shlExact(@as(usize, 0b1111), BIT_INDEX_MULTIPLIER * firstBitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, BIT_INDEX_MULTIPLIER * firstBitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices4Bit, index: u4, position: BlockPosition) void {
        const arrayIndex = @mod(position.index, ARRAY_SIZE);
        const positionIndexCast: usize = @intCast(position.index);
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, BIT_INDEX_MULTIPLIER * firstBitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices8Bit = struct {
    indices: [CHUNK_SIZE]u8 = .{0} ** CHUNK_SIZE,

    fn indexAt(self: BlockStateIndices8Bit, position: BlockPosition) u16 {
        return self.indices[position.index];
    }

    fn setIndexAt(self: *BlockStateIndices8Bit, index: u8, position: BlockPosition) void {
        self.indices[position.index] = index;
    }
};

const BlockStateIndices16Bit = struct {
    indices: [CHUNK_SIZE]u16 = .{0} ** CHUNK_SIZE,

    fn indexAt(self: BlockStateIndices16Bit, position: BlockPosition) u16 {
        return self.indices[position.index];
    }

    fn setIndexAt(self: *BlockStateIndices16Bit, index: u16, position: BlockPosition) void {
        self.indices[position.index] = index;
    }
};

// Tests

test "BlockStateIndices1Bit" {
    try expect(@sizeOf(BlockStateIndices1Bit) == 4096);

    var indices: BlockStateIndices1Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(1, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(1, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 1);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 1);
}

test "BlockStateIndices2Bit" {
    try expect(@sizeOf(BlockStateIndices2Bit) == 8192);

    var indices: BlockStateIndices2Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(3, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(3, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 3);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 3);
}

test "BlockStateIndices4Bit" {
    try expect(@sizeOf(BlockStateIndices4Bit) == 16384);

    var indices: BlockStateIndices4Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(9, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(9, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 9);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 9);
}

test "BlockStateIndices8Bit" {
    try expect(@sizeOf(BlockStateIndices8Bit) == 32768);

    var indices: BlockStateIndices8Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(199, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(199, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 199);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 199);
}

test "BlockStateIndices16Bit" {
    try expect(@sizeOf(BlockStateIndices16Bit) == 65536);

    var indices: BlockStateIndices16Bit = .{};

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 0);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 0);

    indices.setIndexAt(4321, BlockPosition.init(0, 0, 0));
    indices.setIndexAt(4321, BlockPosition.init(9, 8, 8));

    try expect(indices.indexAt(BlockPosition.init(0, 0, 0)) == 4321);
    try expect(indices.indexAt(BlockPosition.init(9, 8, 8)) == 4321);
}

test "Init deinit" {
    const allocator = std.testing.allocator;

    const indices = try Self.init(allocator);
    indices.deinit(allocator);
}
