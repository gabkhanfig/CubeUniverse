const std = @import("std");
const c = @import("clibs.zig");
//const VulkanEngine = @import("shared/engine/vulkan/vk_engine.zig").VulkanEngine;
const VulkanEngine = @import("shared/engine/vulkan/VulkanEngine.zig");
const NTree = @import("shared/world/NTree.zig");
const TreeLayerIndices = @import("shared/world/TreeLayerIndices.zig");
const Chunk = @import("shared/world/chunk/Chunk.zig");
const LoadedChunksHashMap = @import("shared/world/n_tree/LoadedChunksHashMap.zig");

pub fn main() !void {
    //VulkanEngine.init();
    //defer VulkanEngine.deinit();

    //var e = VulkanEngine.init(std.heap.page_allocator);
    //e.cleanup();
}
