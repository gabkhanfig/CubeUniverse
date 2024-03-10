const std = @import("std");
const world_transform = @import("../../world/world_transform.zig");
const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;

/// Represents the index of the GLSL shader buffer object of all the block states.
pub const BlockStatePathtraceIndices = extern struct {
    /// A value of 0 for an index means air.
    /// FOR NOW, 0 is air, 1 is a full block. TODO actual block states.
    indices: [CHUNK_SIZE]u32 = std.mem.zeroes([CHUNK_SIZE]u32),
};
