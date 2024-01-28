const std = @import("std");
const c = @import("clibs.zig");
//const VulkanEngine = @import("shared/engine/vulkan/vk_engine.zig").VulkanEngine;
const VulkanEngine = @import("shared/engine/vulkan/VulkanEngine.zig");

pub fn main() !void {
    //VulkanEngine.init();
    //defer VulkanEngine.deinit();
    var e = VulkanEngine.init(std.heap.page_allocator);
    e.cleanup();
}
