const std = @import("std");
const c = @import("engine/clibs.zig");
const RasterShader = @import("engine/graphics/opengl/shader.zig").RasterShader;
const Vbo = @import("engine/graphics/opengl/VertexBufferObject.zig");
const Ibo = @import("engine/graphics/opengl/IndexBufferObject.zig");
const ComputeShader = @import("engine/graphics/opengl/shader.zig").ComputeShader;

// const vertSource = @embedFile("assets/basic.vert");
// const fragSource = @embedFile("assets/basic.frag");
const vertSource = @embedFile("assets/pathtrace.vert");
const fragSource = @embedFile("assets/pathtrace.frag");
const compSource = @embedFile("assets/test.comp");

const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 640;

pub fn main() !void {
    if (c.glfwInit() == c.GLFW_FALSE) {
        @panic("Failed to initialize glfw!");
    }

    const createWindow = c.glfwCreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Muehehehe", null, null);
    if (createWindow == null) {
        c.glfwTerminate();
        @panic("Failed to create glfw window");
    }

    c.glfwMakeContextCurrent(createWindow);

    _ = c.gladLoadGL();

    c.glClearColor(1.0, 0.5, 0.5, 1.0);
    c.glViewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    //c.glFrontFace(c.GL_CCW);

    defer c.glfwTerminate();

    // const positions: [6]f32 = .{
    //     -0.5, -0.5, //0.0,
    //     0.0, 0.5, //0.0,
    //     0.5, -0.5, //0.0,
    // };

    const vertices: [20]f32 = .{
        // Pos         UV
        -1.0, -1.0, 0.0, 0.0, 0.0,
        -1.0, 1.0,  0.0, 0.0, 1.0,
        1.0,  1.0,  0.0, 1.0, 1.0,
        1.0,  -1.0, 0.0, 1.0, 0.0,
    };

    const indices: [6]u32 = .{
        0, 2, 1,
        0, 3, 2,
    };

    var vao: u32 = undefined;
    c.glCreateVertexArrays(1, &vao);

    var vbo = Vbo.init();
    vbo.bufferData(f32, &vertices);
    vbo.bind();

    var ibo = Ibo.init();
    ibo.bufferData(&indices);
    ibo.bind();

    var screenTex: u32 = undefined;
    c.glCreateTextures(c.GL_TEXTURE_2D, 1, &screenTex);
    c.glTextureParameteri(screenTex, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(screenTex, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(screenTex, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTextureParameteri(screenTex, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glTextureStorage2D(screenTex, 1, c.GL_RGBA32F, SCREEN_WIDTH, SCREEN_HEIGHT);
    c.glBindImageTexture(0, screenTex, 0, c.GL_FALSE, 0, c.GL_WRITE_ONLY, c.GL_RGBA32F);

    c.glEnableVertexArrayAttrib(vao, 0);
    c.glVertexArrayAttribBinding(vao, 0, 0);
    c.glVertexArrayAttribFormat(vao, 0, 3, c.GL_FLOAT, c.GL_FALSE, 0);

    c.glEnableVertexArrayAttrib(vao, 1);
    c.glVertexArrayAttribBinding(vao, 1, 0);
    c.glVertexArrayAttribFormat(vao, 1, 2, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32));

    c.glVertexArrayVertexBuffer(vao, 0, vbo.id, 0, 5 * @sizeOf(f32));
    c.glVertexArrayElementBuffer(vao, ibo.id);

    // c.glEnableVertexAttribArray(0);
    // c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), @ptrFromInt(0));
    // c.glEnableVertexAttribArray(1);
    // c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));

    var raster = RasterShader.init(vertSource, fragSource) catch unreachable;
    defer raster.deinit();

    var compute = ComputeShader.init(compSource) catch unreachable;
    defer compute.deinit();

    //shader.bind();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        compute.bind();
        compute.dispatch(SCREEN_WIDTH / 16, SCREEN_HEIGHT / 16, 1);

        raster.bind();
        c.glBindTextureUnit(0, screenTex);
        c.glUniform1i(c.glGetUniformLocation(raster.id, "screen"), 0);

        //c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
        c.glBindVertexArray(vao);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(ibo.indexCount), c.GL_UNSIGNED_INT, null);

        c.glfwSwapBuffers(createWindow);
    }
}
