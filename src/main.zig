const std = @import("std");
const c = @import("engine/clibs.zig");
const RasterShader = @import("engine/graphics/opengl/shader.zig").RasterShader;

const vertSource = @embedFile("assets/basic.vert");
const fragSource = @embedFile("assets/basic.frag");

pub fn main() !void {
    if (c.glfwInit() == c.GLFW_FALSE) {
        @panic("Failed to initialize glfw!");
    }

    const createWindow = c.glfwCreateWindow(640, 480, "Hello World", null, null);
    if (createWindow == null) {
        c.glfwTerminate();
        @panic("Failed to create glfw window");
    }

    c.glfwMakeContextCurrent(createWindow);

    _ = c.gladLoadGL();

    defer c.glfwTerminate();

    const positions: [6]f32 = .{
        -0.5, -0.5, //0.0,
        0.0, 0.5, //0.0,
        0.5, -0.5, //0.0,
    };

    var buffer: u32 = undefined;
    c.glGenBuffers(1, &buffer);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, buffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, 6 * @sizeOf(f32), @ptrCast(&positions), c.GL_STATIC_DRAW);

    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), @ptrFromInt(0));

    var shader = RasterShader.init(vertSource, fragSource) catch unreachable;
    defer shader.deinit();

    shader.bind();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glfwSwapBuffers(createWindow);
    }
}
