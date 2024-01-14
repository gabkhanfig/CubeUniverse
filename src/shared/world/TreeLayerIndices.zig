//! Used to navigate the NTree structure to find a chunk, or other another node representation.
//! Fundamentally, it's just an array of `TREE_LAYERS` indices.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

/// How many nodes long / wide / tall each layer of the NTree is.
pub const TREE_NODE_LENGTH = 8;
/// Total amount of nodes per layer within the NTree.
pub const TREE_NODES_PER_LAYER: comptime_int = TREE_NODE_LENGTH * TREE_NODE_LENGTH * TREE_NODE_LENGTH;
/// Total number of layers within the NTree structure.
pub const TREE_LAYERS = 7;
/// The amount of nodes required on a single dimension to fit the entire tree structure.
/// Can be thought of as the amount of chunks long/wide/tall the tree is.
pub const TOTAL_NODES_DEEPEST_LAYER_WHOLE_TREE = calculateTotalNodeLength();

const Self = @This();

const BITSHIFT_MULTIPLY = 9;
const BITMASK_LAYER_INDEX = TREE_NODES_PER_LAYER - 1;

/// Bitmask representation of the `TREE_LAYERS` number of indices represented.
value: usize,

/// Creates a new `TreeLayerIndices` given the argument `indices`.
/// Asserts that each element within `indices` is less than `TREE_NODES_PER_LAYER`.
pub fn init(indices: [TREE_LAYERS]u16) Self {
    var value: usize = 0;
    for (0..TREE_LAYERS) |i| {
        assert(indices[i] < TREE_NODES_PER_LAYER);
        const bitshift = i * BITSHIFT_MULTIPLY;
        value |= @shlExact(@as(usize, indices[i]), @truncate(bitshift));
    }
    return Self{ .value = value };
}

/// Get the index stored within this `TreeLayerIndices` at a given `layer`.
/// Asserts that `layer` is less than `TREE_LAYERS`.
pub fn indexAtLayer(self: Self, layer: usize) u16 {
    assert(layer < TREE_LAYERS);

    const layerTruncate: u6 = @truncate(layer);
    const bitshift = layerTruncate * BITSHIFT_MULTIPLY;
    const valueBitmask = @shlExact(@as(usize, BITMASK_LAYER_INDEX), bitshift);
    const index: usize = @shrExact(self.value & valueBitmask, bitshift);
    return @truncate(index);
}

/// Set the node `index` at a specific tree `layer`.
/// Asserts that `index` is less than `TREE_NODES_PER_LAYER`.
/// Asserts that `layer` is less than `TREE_LAYERS`.
pub fn setIndexAtLayer(self: *Self, index: u16, layer: usize) void {
    assert(index < TREE_NODES_PER_LAYER);
    assert(layer < TREE_LAYERS);

    const layerTruncate: u6 = @truncate(layer);
    const bitshift = layerTruncate * BITSHIFT_MULTIPLY;
    const mask = ~(@shlExact(BITMASK_LAYER_INDEX, @truncate(bitshift)));

    self.value = (self.value & mask) | @shlExact(index, @truncate(bitshift));
}

/// Equality comparison between two `TreeLayerIndices`'s.
pub fn equal(self: Self, other: Self) bool {
    return self.value == other.value;
}

fn calculateTotalNodeLength() comptime_int {
    var currentVal = TREE_NODE_LENGTH;
    for (0..TREE_LAYERS) |_| {
        currentVal *= TREE_NODE_LENGTH;
    }
    return currentVal;
}

// Tests

test "tree layer indices size alignment" {
    try expect(@sizeOf(Self) == 8);
    try expect(@alignOf(Self) == 8);
}

test "tree layer indices all zeroes" {
    const layers = Self.init(.{0} ** Self.TREE_LAYERS);
    try expect(layers.indexAtLayer(0) == 0);
    try expect(layers.indexAtLayer(1) == 0);
    try expect(layers.indexAtLayer(2) == 0);
    try expect(layers.indexAtLayer(3) == 0);
    try expect(layers.indexAtLayer(4) == 0);
    try expect(layers.indexAtLayer(5) == 0);
    try expect(layers.indexAtLayer(6) == 0);
}

test "tree layer indices random" {
    const layers = Self.init(.{ 1, 65, 100, Self.TREE_NODES_PER_LAYER - 1, 10, 40, 50 });
    try expect(layers.indexAtLayer(0) == 1);
    try expect(layers.indexAtLayer(1) == 65);
    //try expect(layers.indexAtLayer(2) == 100);
    // try expect(layers.indexAtLayer(3) == TREE_NODES_PER_LAYER - 1);
    // try expect(layers.indexAtLayer(4) == 10);
    // try expect(layers.indexAtLayer(5) == 40);
    // try expect(layers.indexAtLayer(6) == 50);
}
