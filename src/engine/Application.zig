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
    newSelf.createCommandBuffers();

    return newSelf;
}

pub fn deinit(self: *Self) void {
    c.vkDestroyPipelineLayout(self.device.device, self.pipelineLayout, null);

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
        self.drawFrame();
    }

    _ = c.vkDeviceWaitIdle(self.device.device);
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
}

fn createPipeline(self: *Self) void {
    var pipelineConfig = Pipeline.PipelineConfigInfo.default(self.swapChain.width(), self.swapChain.height());
    pipelineConfig.renderPass = self.swapChain.renderPass;
    pipelineConfig.pipelineLayout = self.pipelineLayout;
    self.pipeline = Pipeline.init(&self.device, pipelineConfig);
}

fn createCommandBuffers(self: *Self) void {
    self.commandBuffers = ArrayList(c.VkCommandBuffer).initCapacity(self.allocator, self.swapChain.imageCount()) catch unreachable;
    self.commandBuffers.items.len = self.swapChain.imageCount();

    var allocInfo: c.VkCommandBufferAllocateInfo = .{};
    allocInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocInfo.level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandPool = self.device.commandPool;
    allocInfo.commandBufferCount = @intCast(self.commandBuffers.items.len);

    if (c.vkAllocateCommandBuffers(self.device.device, &allocInfo, self.commandBuffers.items.ptr) != c.VK_SUCCESS) {
        @panic("Failed to create command buffers!");
    }

    for (0..self.commandBuffers.items.len) |i| {
        var beginInfo: c.VkCommandBufferBeginInfo = .{};
        beginInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

        if (c.vkBeginCommandBuffer(self.commandBuffers.items[i], &beginInfo) != c.VK_SUCCESS) {
            @panic("Failed to begin recording command buffer!");
        }

        var renderPassInfo: c.VkRenderPassBeginInfo = .{};
        renderPassInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
        renderPassInfo.renderPass = self.swapChain.renderPass;
        renderPassInfo.framebuffer = self.swapChain.getFrameBuffer(i);

        renderPassInfo.renderArea.offset = .{ .x = 0, .y = 0 };
        renderPassInfo.renderArea.extent = .{ .width = @intCast(self.swapChain.width()), .height = @intCast(self.swapChain.height()) };

        // NOTE For the framebuffer,
        // index 0 -> color attachment
        // index 1 -> depth attachment
        var clearValues: [2]c.VkClearValue = undefined;
        clearValues[0].color = c.VkClearColorValue{ .float32 = .{ 0.1, 0.1, 0.1, 1.0 } };
        clearValues[1].depthStencil = .{ .depth = 1.0, .stencil = 0 };

        renderPassInfo.clearValueCount = @intCast(clearValues.len);
        renderPassInfo.pClearValues = &clearValues;

        c.vkCmdBeginRenderPass(self.commandBuffers.items[i], &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);

        self.pipeline.bind(self.commandBuffers.items[i]);
        c.vkCmdDraw(self.commandBuffers.items[i], 3, 1, 0, 0);

        c.vkCmdEndRenderPass(self.commandBuffers.items[i]);
        if (c.vkEndCommandBuffer(self.commandBuffers.items[i]) != c.VK_SUCCESS) {
            @panic("Failed to record command buffer!");
        }
    }
}

fn drawFrame(self: *Self) void {
    //std.debug.print("drawing frame... {}\n", .{c.glfwGetTime()});

    var imageIndex: u32 = undefined;
    var result = self.swapChain.acquireNextImage(&imageIndex);

    if (result != c.VK_SUCCESS and result != c.VK_SUBOPTIMAL_KHR) {
        @panic("Failed to acquire the next swap chain image!");
    }

    result = self.swapChain.submitCommandBuffers(&self.commandBuffers.items[imageIndex], &imageIndex);
    if (result != c.VK_SUCCESS) {
        @panic("Failed to present swap chain image!");
    }
}
