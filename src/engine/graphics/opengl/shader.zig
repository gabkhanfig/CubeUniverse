const std = @import("std");
const c = @import("../../clibs.zig");
const Engine = @import("../../Engine.zig");
const assert = std.debug.assert;
const StringHashMap = std.StringHashMap;
const v = @import("../../math/vector.zig");
const Vector2 = v.Vector2;
const Vector3 = v.Vector3;
const Vector4 = v.Vector4;

/// Will only ever be accessed by 1 thread, the Engine's OpenGL render thread.
var currentBoundShader: u32 = 0;

pub const RasterShader = struct {
    const Self = @This();

    /// The OpenGL program id. Equivalent to `glCreateProgram()`.
    id: u32,
    uniforms: StringHashMap(u32),

    pub fn init(vertexSource: []const u8, fragmentSource: []const u8) CompileError!Self {
        const program = c.glCreateProgram();

        const vs = compileShader(vertexSource, c.GL_VERTEX_SHADER) catch |err| {
            c.glDeleteProgram(program);
            return err;
        };

        const fs = compileShader(fragmentSource, c.GL_FRAGMENT_SHADER) catch |err| {
            c.glDeleteProgram(program);
            return err;
        };

        c.glAttachShader(program, vs);
        c.glAttachShader(program, fs);
        c.glLinkProgram(program);
        c.glValidateProgram(program);

        c.glDeleteShader(vs);
        c.glDeleteShader(fs);

        return Self{
            .id = program,
            .uniforms = StringHashMap(u32).init(std.heap.c_allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteProgram(self.id);
        self.uniforms.deinit();
    }

    pub fn bind(self: Self) void {
        //assert(Engine.isCurrentOnRenderThread());
        bindShader(self.id);
    }

    pub fn unbind() void {
        unbindShader();
    }

    pub fn setUniform(self: *Self, uniformName: [:0]const u8, comptime T: type, value: T) void {
        setShaderUniform(self.id, T, uniformName, &self.map, value);
    }
};

fn compileShader(source: []const u8, comptime shaderType: c_uint) CompileError!u32 {
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

        c.glDeleteShader(id);
        if (shaderType == c.GL_VERTEX_SHADER) {
            std.debug.print("Failed to compile vertex shader:\n{s}\n", .{message});
            return CompileError.Vertex;
        } else if (shaderType == c.GL_FRAGMENT_SHADER) {
            std.debug.print("Failed to compile fragment shader:\n{s}\n", .{message});
            return CompileError.Fragment;
        } else if (shaderType == c.GL_COMPUTE_SHADER) {
            std.debug.print("Failed to compile compute shader:\n{s}\n", .{message});
            return CompileError.Compute;
        } else {
            @compileError("Unsupported raster shader type. Must be either GL_VERTEX_SHADER, GL_FRAGMENT_SHADER, or GL_COMPUTE_SHADER");
        }
    }

    return id;
}

fn bindShader(programId: u32) void {
    if (isShaderBound(programId)) return;
    c.glUseProgram(programId);
    currentBoundShader = programId;
}

fn unbindShader() void {
    currentBoundShader = 0;
    c.glUseProgram(0);
}

fn isShaderBound(programId: u32) bool {
    return programId == currentBoundShader;
}

fn getUniformLocation(programId: u32, uniformName: [:0]const u8, map: *StringHashMap(u32)) u32 {
    const found = map.get(uniformName);
    if (found != null) {
        return found;
    }

    const location = c.glGetUniformLocation(programId, uniformName.ptr);
    if (location == -1) {
        std.debug.print("Invalid uniform name: {s}", .{uniformName});
    }
    map.put(uniformName, location) catch unreachable;
    return @intCast(location);
}

fn setShaderUniform(programId: u32, comptime T: type, uniformName: [:0]const u8, map: *StringHashMap(u32), value: T) void {
    assert(isShaderBound(programId));
    const location: c_int = @intCast(getUniformLocation(programId, uniformName, map));

    if (T == f32) {
        c.glUniform1f(location, value);
    } else if (T == Vector2(f32)) {
        c.glUniform2f(location, value.x, value.y);
    } else if (T == Vector3(f32)) {
        c.glUniform3f(location, value.x, value.y, value.z);
    } else if (T == Vector4(f32)) {
        c.glUniform4f(location, value.x, value.y, value.z, value.w);
    } else if (T == i32) {
        c.glUniform1i(location, value);
    } else if (T == Vector2(i32)) {
        c.glUniform2i(location, value.x, value.y);
    } else if (T == Vector3(i32)) {
        c.glUniform3i(location, value.x, value.y, value.z);
    } else if (T == Vector4(i32)) {
        c.glUniform4i(location, value.x, value.y, value.z, value.w);
    } else if (false) { // TODO matrix 4x4

    } else {
        @compileError("Unsupported OpenGL uniform type");
    }
}

//fn setUniform1f(uniform, [:0]const u8, value: f32) void {}

pub const CompileError = error{
    Vertex,
    Fragment,
    Compute,
};
