const std = @import("std");
const c = @import("engine/clibs.zig");

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

    const shader = createShader();
    c.glUseProgram(shader);

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glfwSwapBuffers(createWindow);
    }
}

fn createShader() u32 {
    const program = c.glCreateProgram();

    const vertSource = @embedFile("assets/basic.vert");
    const fragSource = @embedFile("assets/basic.frag");

    const vs = compileShader(vertSource, c.GL_VERTEX_SHADER);
    const fs = compileShader(fragSource, c.GL_FRAGMENT_SHADER);

    c.glAttachShader(program, vs);
    c.glAttachShader(program, fs);
    c.glLinkProgram(program);
    c.glValidateProgram(program);

    c.glDeleteShader(vs);
    c.glDeleteShader(fs);

    return program;
}

fn compileShader(source: []const u8, shaderType: c_uint) u32 {
    const id = c.glCreateShader(shaderType);

    const src = source.ptr;
    c.glShaderSource(id, 1, &src, null);
    c.glCompileShader(id);

    var result: c_int = undefined;
    c.glGetShaderiv(id, c.GL_COMPILE_STATUS, &result);
    if (result == c.GL_FALSE) {
        var length: c_int = undefined;
        c.glGetShaderiv(id, c.GL_INFO_LOG_LENGTH, &length);

        const message = std.heap.c_allocator.alloc(u8, @intCast(length)) catch unreachable;
        defer std.heap.c_allocator.free(message);

        c.glGetShaderInfoLog(id, length, &length, message.ptr);
        std.debug.print("Failed to compile {s} shader:\n{s}\n", .{ if (shaderType == c.GL_VERTEX_SHADER) "vertex" else "fragment", message });

        c.glDeleteShader(id);
        return 0;
    }

    return id;
}
