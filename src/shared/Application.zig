const std = @import("std");
const Window = @import("engine/Window.zig");

const WINDOW_WIDTH = 960;
const WINDOW_HEIGHT = 540;

const Self = @This();

window: Window,

pub fn init() Self {
    std.debug.print("Initializing application...\n", .{});
    return Self{ .window = Window.init(WINDOW_WIDTH, WINDOW_HEIGHT) };
}

pub fn deinit(self: Self) void {
    self.window.deinit();
}

pub fn run(self: *Self) void {
    while (!self.window.shouldClose()) {
        Window.pollEvents();
    }
}
