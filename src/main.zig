const std = @import("std");
const c = @import("clibs.zig");

pub fn main() !void {
    if (c.glfwInit() == c.GLFW_FALSE) {
        return error.Fail;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    const window = c.glfwCreateWindow(800, 600, "Vulkan window", null, null).?;
    defer c.glfwDestroyWindow(window);

    var extensionCount: u32 = 0;
    _ = c.vkEnumerateInstanceExtensionProperties(null, @ptrCast(&extensionCount), null);
    std.debug.print("{} extensions found\n", .{extensionCount});

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glfwPollEvents();
    }
}
