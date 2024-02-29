//! Used to navigate the FatTree structure to find a chunk, or other another node representation.
//! Fundamentally, it's just an array of `TREE_LAYERS` indices.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

/// How many nodes long / wide / tall each layer of the FatTree is.
pub const TREE_NODE_LENGTH = 4;
/// # 64
/// Total amount of nodes per layer within the FatTree.
pub const TREE_NODES_PER_LAYER: comptime_int = TREE_NODE_LENGTH * TREE_NODE_LENGTH * TREE_NODE_LENGTH;
/// Total number of layers within the FatTree structure.
pub const TREE_LAYERS = 15;
/// # 1073741824
/// The amount of nodes required on a single dimension to fit the entire tree structure.
/// Can be thought of as the amount of chunks long/wide/tall the tree is.
pub const TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE = calculateTotalNodeLength();
///
const INDICES_PER_INT = 5;
///
const BITSHIFT_MULTIPLY = 6;
///
const BITMASK_LAYER_INDEX: u32 = 0b111111;

pub const TreeLayerIndices = extern struct {
    const Self = @This();

    pub const Index = TreeLayerIndex;

    /// Bitmask representation of the `TREE_LAYERS` number of indices represented.
    values: [3]u32 = std.mem.zeroes([3]u32),

    /// Creates a new `TreeLayerIndices`, where the bits are set to match `indices`.
    /// This is basically just multiple calls to `setIndexAtLayer()` as one call.
    pub fn init(indices: [TREE_LAYERS]Index) Self {
        var newSelf = Self{};

        for (0..TREE_LAYERS) |i| {
            const asU32: u32 = @intCast(indices[i].index);
            const valueIndex = @mod(i, 3);
            const bitshift: u5 = @intCast(@mod(i, INDICES_PER_INT) * BITSHIFT_MULTIPLY);

            newSelf.values[valueIndex] |= @shlExact(asU32, bitshift);
        }

        return newSelf;
    }

    /// Get the index stored within this `TreeLayerIndices` at a given `layer`.
    /// Asserts that `layer` is less than `TREE_LAYERS`.
    pub fn indexAtLayer(self: Self, layer: usize) Index {
        assert(layer < TREE_LAYERS);

        const valueIndex = @mod(layer, 3);

        const layerTruncate: u5 = @truncate(@mod(layer, INDICES_PER_INT));
        const bitshift = layerTruncate * BITSHIFT_MULTIPLY;

        const valueBitmask = @shlExact(BITMASK_LAYER_INDEX, bitshift);
        const index: u32 = @shrExact(self.values[valueIndex] & valueBitmask, bitshift);
        return .{ .index = @truncate(index) };
    }

    /// Set the node `index` at a specific tree `layer`.
    /// Asserts that `layer` is less than `TREE_LAYERS`.
    pub fn setIndexAtLayer(self: *Self, layer: usize, index: Index) void {
        assert(layer < TREE_LAYERS);

        const valueIndex = @mod(layer, 3);

        const layerTruncate: u5 = @truncate(@mod(layer, INDICES_PER_INT));
        const bitshift = layerTruncate * BITSHIFT_MULTIPLY;

        const mask = ~(@shlExact(BITMASK_LAYER_INDEX, @truncate(bitshift)));

        const indexAsU32: u32 = @intCast(index.index);

        self.values[valueIndex] = (self.values[valueIndex] & mask) | @shlExact(indexAsU32, @truncate(bitshift));
    }

    /// Equality comparison between two `TreeLayerIndices`'s.
    pub fn equal(self: Self, other: Self) bool {
        return self.values[0] == other.values[0] and self.values[1] == other.values[1] and self.values[2] == other.values[2];
    }

    pub fn hash(self: Self) usize {
        return self.values[0]; // TODO better hash
    }
};

/// Similar to `BlockIndex`:
/// - x has a factor of 1
/// - y has a factor of 16
/// - z has a factor of 4
pub const TreeLayerIndex = struct {
    const Self = @This();

    index: u8,

    const Y_SHIFT = 4;
    const Z_SHIFT = 2;
    const X_MASK: u8 = 0b000011;
    const Y_MASK: u8 = 0b110000;
    const Z_MASK: u8 = 0b001100;

    pub fn init(inX: u2, inY: u2, inZ: u2) Self {
        const xAs8: u8 = @intCast(inX);
        const yAs8: u8 = @intCast(inY);
        const zAs8: u8 = @intCast(inZ);
        return Self{ .index = xAs8 | @shlExact(yAs8, Y_SHIFT) | @shlExact(zAs8, Z_SHIFT) };
    }

    pub fn x(self: Self) u2 {
        return @intCast(self.index & X_MASK);
    }

    pub fn y(self: Self) u2 {
        return @intCast(@shrExact(self.index & Y_MASK, Y_SHIFT));
    }

    pub fn z(self: Self) u2 {
        return @intCast(@shrExact(self.index & Z_MASK, Z_SHIFT));
    }

    pub fn setX(self: *Self, inX: u2) void {
        const xAs8: u8 = @intCast(inX);
        self.value = (self.value & ~(self.value & X_MASK)) | xAs8;
    }

    pub fn setY(self: *Self, inY: u2) void {
        const yAs8: u8 = @intCast(inY);
        self.value = (self.value & ~(self.value & Y_MASK)) | @shlExact(yAs8, Y_SHIFT);
    }

    pub fn setZ(self: *Self, inZ: u2) void {
        const zAs8: u8 = @intCast(inZ);
        self.value = (self.value & ~(self.value & Z_MASK)) | @shlExact(zAs8, Z_SHIFT);
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.index == other.index;
    }
};

fn calculateTotalNodeLength() comptime_int {
    var currentVal = 1;
    for (0..TREE_LAYERS) |_| {
        currentVal *= TREE_NODE_LENGTH;
    }
    return currentVal;
}

// Tests

test "tree layer indices size alignment" {
    try expect(@sizeOf(TreeLayerIndices) == 12);
    try expect(@alignOf(TreeLayerIndices) == 4);
}

test "tree layer indices all zeroes" {
    const layers = TreeLayerIndices{};
    for (0..TREE_LAYERS) |i| {
        try expect(layers.indexAtLayer(i).index == 0);
    }
}

test "tree layer indices init" {
    var indices: [TREE_LAYERS]TreeLayerIndex = undefined;
    for (0..TREE_LAYERS) |i| {
        indices[i] = .{ .index = @intCast(i + 1) };
    }
    const layers = TreeLayerIndices.init(indices);
    for (0..TREE_LAYERS) |i| {
        try expect(layers.indexAtLayer(i).index == i + 1);
    }
}
