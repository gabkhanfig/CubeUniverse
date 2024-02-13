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

const Application = @import("shared/Application.zig");

pub fn main() !void {
    var app = Application.init(std.heap.page_allocator);
    defer app.deinit();

    app.run();
}
