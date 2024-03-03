// Unit Tests
comptime {
    _ = @import("engine/world/world_transform.zig");
    _ = @import("engine/world/chunk/Chunk.zig");
    _ = @import("engine/world/chunk/Inner.zig");
    _ = @import("engine/world/fat_tree/FatTree.zig");
    _ = @import("engine/types/color.zig");
    _ = @import("engine/types/light.zig");
    _ = @import("engine/types/job_system.zig");
    _ = @import("engine/world/fat_tree/LoadedChunksHashMap.zig");
    _ = @import("engine/world/chunk/BlockStateIndices.zig");
    _ = @import("engine/math/vector.zig");
    _ = @import("engine/math/detail/vector2.zig");
    _ = @import("engine/math/detail/vector3.zig");
    _ = @import("engine/math/detail/vector4.zig");
}

// TODO system tests
pub fn main() !void {}
