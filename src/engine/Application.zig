const std = @import("std");
const ArrayList = std.ArrayList;
const c = @import("clibs.zig");
const Allocator = std.mem.Allocator;
const Window = @import("graphics/Window.zig");
const Pipeline = @import("graphics/vulkan/Pipeline.zig");
const Device = @import("graphics/vulkan/device.zig").Device;
const SwapChain = @import("graphics/vulkan/SwapChain.zig");

const WINDOW_WIDTH = 960;
const WINDOW_HEIGHT = 540;

const Self = @This();

allocator: Allocator,
window: Window,
device: Device,
pipeline: Pipeline,
swapChain: *SwapChain,
pipelineLayout: c.VkPipelineLayout,
commandBuffers: ArrayList(c.VkCommandBuffer),

pub fn init(allocator: Allocator) *Self {
    const newSelf = allocator.create(Self) catch unreachable;
    newSelf.allocator = allocator;
    newSelf.window = Window.init(WINDOW_WIDTH, WINDOW_HEIGHT);
    newSelf.device = Device.init(newSelf.allocator, &newSelf.window);
    newSelf.swapChain = SwapChain.init(newSelf.allocator, &newSelf.device, c.VkExtent2D{ .width = @intCast(newSelf.window.width), .height = @intCast(newSelf.window.height) });

    newSelf.createPipelineLayout();
    newSelf.createPipeline();
    //newSelf.createCommandBuffers(); TODO this

    return newSelf;
}

pub fn deinit(self: *Self) void {
    self.window.deinit();
    self.pipeline.deinit();
    self.swapChain.deinit();
    self.device.deinit();

    const allocator = self.allocator;
    allocator.destroy(self);
}

pub fn run(self: *Self) void {
    while (!self.window.shouldClose()) {
        Window.pollEvents();
    }
}

fn createPipelineLayout(self: *Self) void {
    var pipelineLayoutInfo: c.VkPipelineLayoutCreateInfo = .{};
    pipelineLayoutInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount = 0;
    pipelineLayoutInfo.pSetLayouts = null;
    pipelineLayoutInfo.pushConstantRangeCount = 0;
    pipelineLayoutInfo.pPushConstantRanges = null;
    if (c.vkCreatePipelineLayout(self.device.device, &pipelineLayoutInfo, null, &self.pipelineLayout) != c.VK_SUCCESS) {
        @panic("Failed to create pipeline layout!");
    }
    //std.debug.assert(self.pipelineLayout != null);
}

fn createPipeline(self: *Self) void {
    var pipelineConfig = Pipeline.PipelineConfigInfo.default(self.swapChain.width(), self.swapChain.height());
    pipelineConfig.renderPass = self.swapChain.renderPass;
    pipelineConfig.pipelineLayout = self.pipelineLayout;
    self.pipeline = Pipeline.init(&self.device, pipelineConfig);
}

fn createCommandBuffers(self: *Self) void {
    _ = self;
}

fn drawFrame(self: *Self) void {
    _ = self; // TODO draw frame
}
