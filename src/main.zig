const std = @import("std");
const c = @import("clibs.zig");
const VulkanEngine = @import("shared/engine/vulkan/vk_engine.zig").VulkanEngine;

pub fn main() !void {
    VulkanEngine.init();
    defer VulkanEngine.deinit();
}
