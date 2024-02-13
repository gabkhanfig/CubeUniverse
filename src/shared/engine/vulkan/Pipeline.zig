const std = @import("std");
const c = @import("../../../clibs.zig");
const Device = @import("device.zig").Device;

const SIMPLE_SHADER_VERT_FILE = @embedFile("../../../assets/shaders/simple_shader.vert.spv");
const SIMPLE_SHADER_FRAG_FILE = @embedFile("../../../assets/shaders/simple_shader.frag.spv");
const VERTEX_SHADER_SRC: [:0]const u8 = SIMPLE_SHADER_VERT_FILE;
const FRAGMENT_SHADER_SRC: [:0]const u8 = SIMPLE_SHADER_FRAG_FILE;

const Self = @This();

device: *Device,
graphicsPipeline: c.VkPipeline,
vertShaderModule: c.VkShaderModule,
fragShaderModule: c.VkShaderModule,

pub fn init(device: *Device, configInfo: PipelineConfigInfo) Self {
    _ = configInfo;
    // const vert: [:0]const u8 = SIMPLE_SHADER_VERT;
    // const frag: [:0]const u8 = SIMPLE_SHADER_FRAG;
    return Self{
        .device = device,
        .graphicsPipeline = undefined,
        .vertShaderModule = undefined,
        .fragShaderModule = undefined,
    };
}

pub fn deinit(_: Self) void {}

fn createShaderModule(self: *Self, code: [:0]const u8, shaderModule: *c.VkShaderModule) void {
    var createInfo: c.VkShaderModuleCreateInfo = .{};
    createInfo.sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createInfo.codeSize = code.len;
    createInfo.pCode = @ptrCast(@alignCast(code.ptr));

    if (c.vkCreateShaderModule(self.device.device, &createInfo, null, shaderModule) != c.VK_SUCCESS) {
        @panic("Failed to create shader module!");
    }
}

pub const PipelineConfigInfo = struct {};

pub fn defaultPipelineConfigInfo(width: u32, height: u32) PipelineConfigInfo {
    _ = width;
    _ = height;
    return PipelineConfigInfo{};
}
