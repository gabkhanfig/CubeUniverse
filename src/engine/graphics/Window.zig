//! Engine window

const std = @import("std");
const c = @import("../clibs.zig");
const GLFWwindow = c.GLFWwindow;
const GLFW_TRUE = c.GLFW_TRUE;
const GLFW_FALSE = c.GLFW_FALSE;
const JobThread = @import("../types/job_system.zig").JobThread;
//const Vec2i = @import("../math/vector.zig").Vector2(i32);

const WINDOW_NAME = "Cube Universe";

const Self = @This();

glfwwindow: *GLFWwindow,
width: i32,
height: i32,

pub fn init(renderThread: *JobThread, width: i32, height: i32) Self {
    if (c.glfwInit() == GLFW_FALSE) {
        @panic("failed to init glfw");
    }

    c.glfwWindowHint(c.GLFW_RESIZABLE, GLFW_FALSE);

    const createdWindow = c.glfwCreateWindow(width, height, WINDOW_NAME, null, null);
    if (createdWindow == null) {
        c.glfwTerminate();
        @panic("failed to create glfw window");
    }

    const window = createdWindow.?;

    const future = renderThread.runJob(c.glfwMakeContextCurrent, .{window}) catch unreachable;
    future.wait();

    return Self{ .glfwwindow = window, .width = width, .height = height };
}

pub fn deinit(self: Self) void {
    c.glfwDestroyWindow(self.glfwwindow);
    c.glfwTerminate();
}

pub fn shouldClose(self: Self) bool {
    const result = c.glfwWindowShouldClose(self.glfwwindow);
    return result == GLFW_TRUE;
}

pub fn pollEvents() void {
    c.glfwPollEvents();
}

// TODO implement window switching and resizing later
// pub const WindowDimensionsTag = enum {
//     windowed,
//     fullscreen,
// };

// pub const WindowDimensions = union(WindowDimensionsTag) {
//     windowed: Vec2i,
//     fullscreen: bool,
// };

// pub const WindowInitParams = struct {
//     dimensions: WindowDimensions,
// };
