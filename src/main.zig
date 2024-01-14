const std = @import("std");
const c = @import("clibs.zig");
const glfw = @import("mach-glfw");
const ChunkInner = @import("shared/world/chunk/chunk.zig").ChunkInner;

fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(640, 480, "Hello, mach-glfw!", null, null, .{}) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    // if (glfw.glfwInit() == glfw.GLFW_FALSE) {
    //     return error.Fail;
    // }

    // glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    // const window: *glfw.GLFWwindow = glfw.glfwCreateWindow(800, 600, @ptrCast("Vulkan window"), null, null).?;

    var extensionCount: u32 = 0;
    _ = c.vkEnumerateInstanceExtensionProperties(null, @ptrCast(&extensionCount), null);

    std.debug.print("{} extensions supported\n", .{extensionCount});

    // Wait for the user to close the window.
    while (!window.shouldClose()) {
        window.swapBuffers();
        glfw.pollEvents();
    }
    std.debug.print("hello world!\n", .{});
}
