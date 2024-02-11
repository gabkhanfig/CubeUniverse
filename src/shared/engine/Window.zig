//! Engine window

const std = @import("std");
const c = @import("../../clibs.zig");
const GLFWwindow = c.GLFWwindow;
const GLFW_TRUE = c.GLFW_TRUE;
const GLFW_FALSE = c.GLFW_FALSE;

const WINDOW_NAME = "Vulkan Engine";

const Self = @This();

window: *GLFWwindow,
width: i32,
height: i32,

pub fn init(width: i32, height: i32) Self {
    if (c.glfwInit() == GLFW_FALSE) {
        @panic("failed to init glfw");
    }

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API); // Dont use OpenGL
    c.glfwWindowHint(c.GLFW_RESIZABLE, GLFW_FALSE);

    const createdWindow = c.glfwCreateWindow(width, height, WINDOW_NAME, null, null);
    if (createdWindow == null) {
        c.glfwTerminate();
        @panic("failed to create glfw window");
    }

    const window = createdWindow.?;

    return Self{ .window = window, .width = width, .height = height };
}

pub fn deinit(self: Self) void {
    c.glfwDestroyWindow(self.window);
    c.glfwTerminate();
}

pub fn shouldClose(self: Self) bool {
    const result = c.glfwWindowShouldClose(self.window);
    return result == GLFW_TRUE;
}

pub fn pollEvents() void {
    c.glfwPollEvents();
}
