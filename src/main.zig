const std = @import("std");
const c = @import("clibs.zig");
//const VulkanEngine = @import("shared/engine/vulkan/vk_engine.zig").VulkanEngine;
const VulkanEngine = @import("shared/engine/vulkan/VulkanEngine.zig");
//const NTree = @import("shared/world/NTree.zig");
const tree_layer_indices = @import("shared/world/n_tree/tree_layer_indices.zig");
const TreeLayerIndices = tree_layer_indices.TreeLayerIndices;
const Chunk = @import("shared/world/chunk/Chunk.zig");
const LoadedChunksHashMap = @import("shared/world/n_tree/LoadedChunksHashMap.zig");
const world_transform = @import("shared/world/world_transform.zig");
const BlockPosition = world_transform.BlockPosition;

pub fn main() !void {
    std.debug.print("\n", .{});
    //VulkanEngine.init();
    //defer VulkanEngine.deinit();

    //var e = VulkanEngine.init(std.heap.page_allocator);
    //e.cleanup();

    var indices: [tree_layer_indices.TREE_LAYERS]TreeLayerIndices.Index = undefined;
    indices[0] = TreeLayerIndices.Index.init(2, 2, 2);
    for (1..tree_layer_indices.TREE_LAYERS) |i| {
        indices[i] = TreeLayerIndices.Index.init(0, 0, 0);
    }
    {
        const treePos = TreeLayerIndices.init(indices);
        const pos = BlockPosition.fromTreeIndices(treePos);
        std.debug.print("x: {}\ny: {}\nz: {}\n", .{ pos.x, pos.y, pos.z });
        // try expect(pos.x == 0);
        // try expect(pos.y == 0);
        // try expect(pos.z == 0);
    }
}
