const std = @import("std");
const Window = @import("engine/Window.zig");
const Pipeline = @import("engine/vulkan/Pipeline.zig");
const Device = @import("engine/vulkan/device.zig").Device;
const Allocator = std.mem.Allocator;

const WINDOW_WIDTH = 960;
const WINDOW_HEIGHT = 540;

const Self = @This();

allocator: Allocator,
window: Window,
device: Device,
pipeline: Pipeline,

pub fn init(allocator: Allocator) *Self {
    const newSelf = allocator.create(Self) catch unreachable;
    newSelf.allocator = allocator;
    newSelf.window = Window.init(WINDOW_WIDTH, WINDOW_HEIGHT);
    newSelf.device = Device.init(allocator, &newSelf.window);
    newSelf.pipeline = Pipeline.init(&newSelf.device, Pipeline.defaultPipelineConfigInfo(WINDOW_WIDTH, WINDOW_HEIGHT));
    return newSelf;
}

pub fn deinit(self: *Self) void {
    self.window.deinit();
    self.pipeline.deinit();
    self.device.deinit();

    const allocator = self.allocator;
    allocator.destroy(self);
}

pub fn run(self: *Self) void {
    while (!self.window.shouldClose()) {
        Window.pollEvents();
    }
}
