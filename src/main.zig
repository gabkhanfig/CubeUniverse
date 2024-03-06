const std = @import("std");
const c = @import("engine/clibs.zig");
const RasterShader = @import("engine/graphics/opengl/shader.zig").RasterShader;
const Vbo = @import("engine/graphics/opengl/VertexBufferObject.zig");
const Ibo = @import("engine/graphics/opengl/IndexBufferObject.zig");

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

    // const vertices: [12]f32 = .{
    //     // Pos         UV
    //     -1.0, -1.0, 0.0, 0.0,
    //     -1.0, 1.0,  0.0, 1.0,
    //     1.0,  1.0,  1.0, 1.0,
    //     1.0,  -1.0, 1.0, 0.0,
    // };

    // const indices: [6]u32 = .{
    //     0, 2, 1,
    //     0, 3, 2,
    // };

    var vbo = Vbo.init();
    vbo.bufferData(f32, &positions);
    vbo.bind();

    var ibo = Ibo.init();
    ibo.bufferData(&.{ 0, 1, 2 });
    ibo.bind();

    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), @ptrFromInt(0));

    var shader = RasterShader.init(vertSource, fragSource) catch unreachable;
    defer shader.deinit();

    shader.bind();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        //c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
        c.glDrawElements(c.GL_TRIANGLES, 3, c.GL_UNSIGNED_INT, null);

        c.glfwSwapBuffers(createWindow);
    }
}
