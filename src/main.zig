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
    //std.debug.print("\n", .{});
    //VulkanEngine.init();
    //defer VulkanEngine.deinit();

    //var e = VulkanEngine.init(std.heap.page_allocator);
    //e.cleanup();

    // var window: *c.GLFWwindow = undefined;

    // // Initialize the library
    // if (c.glfwInit() == c.GLFW_FALSE) {
    //     @panic("failed to init glfw");
    // }

    // // Create a windowed mode window and its OpenGL context */
    // const createdWindow = c.glfwCreateWindow(640, 480, "Hello World", null, null);
    // if (createdWindow == null) {
    //     c.glfwTerminate();
    //     @panic("failed to create glfw window");
    // }

    // window = createdWindow.?;

    // var extensionCount: u32 = undefined;
    // _ = c.vkEnumerateInstanceExtensionProperties(null, &extensionCount, null);

    // std.debug.print("{} extensions supported\n", .{extensionCount});

    // // Make the window's context current
    // c.glfwMakeContextCurrent(window);

    // // Loop until the user closes the window
    // while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
    //     // Poll for and process events
    //     c.glfwPollEvents();
    // }

    // c.glfwTerminate();

    var app = Application.init(std.heap.page_allocator);
    defer app.deinit();

    app.run();
}
