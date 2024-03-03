const std = @import("std");
const c = @import("../../clibs.zig");
const Device = @import("device.zig").Device;
const assert = std.debug.assert;

const SIMPLE_SHADER_VERT_FILE = @embedFile("../shaders/simple_shader.vert.spv");
const SIMPLE_SHADER_FRAG_FILE = @embedFile("../shaders/simple_shader.frag.spv");
const VERTEX_SHADER_SRC: [:0]const u8 = SIMPLE_SHADER_VERT_FILE;
const FRAGMENT_SHADER_SRC: [:0]const u8 = SIMPLE_SHADER_FRAG_FILE;

const Self = @This();

device: *Device,
graphicsPipeline: c.VkPipeline,
vertShaderModule: c.VkShaderModule,
fragShaderModule: c.VkShaderModule,

pub fn init(device: *Device, configInfo: PipelineConfigInfo) Self {
    var newSelf = Self{
        .device = device,
        .graphicsPipeline = undefined,
        .vertShaderModule = undefined,
        .fragShaderModule = undefined,
    };

    assert(configInfo.pipelineLayout != null);
    assert(configInfo.renderPass != null);

    newSelf.createShaderModule(VERTEX_SHADER_SRC, &newSelf.vertShaderModule);
    newSelf.createShaderModule(FRAGMENT_SHADER_SRC, &newSelf.fragShaderModule);

    var shaderStages: [2]c.VkPipelineShaderStageCreateInfo = std.mem.zeroes([2]c.VkPipelineShaderStageCreateInfo);

    shaderStages[0].sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shaderStages[0].stage = c.VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module = newSelf.vertShaderModule;
    shaderStages[0].pName = "main"; // shader main function
    shaderStages[0].flags = 0;
    shaderStages[0].pNext = null;
    shaderStages[0].pSpecializationInfo = null;

    shaderStages[1].sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shaderStages[1].stage = c.VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].module = newSelf.fragShaderModule;
    shaderStages[1].pName = "main"; // shader main function
    shaderStages[1].flags = 0;
    shaderStages[1].pNext = null;
    shaderStages[1].pSpecializationInfo = null;

    var vertexInputInfo: c.VkPipelineVertexInputStateCreateInfo = .{};
    vertexInputInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertexInputInfo.vertexAttributeDescriptionCount = 0;
    vertexInputInfo.vertexBindingDescriptionCount = 0;
    vertexInputInfo.pVertexAttributeDescriptions = null;
    vertexInputInfo.pVertexBindingDescriptions = null;

    var viewportInfo: c.VkPipelineViewportStateCreateInfo = .{};
    viewportInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewportInfo.viewportCount = 1;
    viewportInfo.pViewports = &configInfo.viewport;
    viewportInfo.scissorCount = 1;
    viewportInfo.pScissors = &configInfo.scissor;

    var pipelineInfo: c.VkGraphicsPipelineCreateInfo = .{};
    pipelineInfo.sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipelineInfo.stageCount = 2;
    pipelineInfo.pStages = &shaderStages;
    pipelineInfo.pVertexInputState = &vertexInputInfo;
    pipelineInfo.pInputAssemblyState = &configInfo.inputAssemblyInfo;
    pipelineInfo.pViewportState = &viewportInfo;
    pipelineInfo.pRasterizationState = &configInfo.rasterizationInfo;
    pipelineInfo.pMultisampleState = &configInfo.multisampleInfo;
    pipelineInfo.pColorBlendState = &configInfo.colorBlendInfo;
    pipelineInfo.pDepthStencilState = &configInfo.depthStencilInfo;
    pipelineInfo.pDynamicState = null;

    pipelineInfo.layout = configInfo.pipelineLayout;
    pipelineInfo.renderPass = configInfo.renderPass;
    pipelineInfo.subpass = configInfo.subpass;

    pipelineInfo.basePipelineIndex = -1;
    pipelineInfo.basePipelineHandle = null;

    if (c.vkCreateGraphicsPipelines(newSelf.device.device, null, 1, &pipelineInfo, null, &newSelf.graphicsPipeline) != c.VK_SUCCESS) {
        @panic("Failed to create graphics pipeline!");
    }

    return newSelf;
}

pub fn deinit(self: Self) void {
    c.vkDestroyShaderModule(self.device.device, self.vertShaderModule, null);
    c.vkDestroyShaderModule(self.device.device, self.fragShaderModule, null);
    c.vkDestroyPipeline(self.device.device, self.graphicsPipeline, null);
}

pub fn bind(self: *Self, commandBuffer: c.VkCommandBuffer) void {
    c.vkCmdBindPipeline(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipeline);
}

fn createShaderModule(self: *Self, code: [:0]const u8, shaderModule: *c.VkShaderModule) void {
    var createInfo: c.VkShaderModuleCreateInfo = .{};
    createInfo.sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    createInfo.codeSize = code.len;

    const codeMem = std.heap.page_allocator.alignedAlloc(u8, 4, code.len) catch unreachable; // must be 4 byte aligned
    defer std.heap.page_allocator.free(codeMem);

    @memset(codeMem, 0);
    @memcpy(codeMem, code);

    createInfo.pCode = @ptrCast(@alignCast(codeMem));

    if (c.vkCreateShaderModule(self.device.device, &createInfo, null, shaderModule) != c.VK_SUCCESS) {
        @panic("Failed to create shader module!");
    }
}

pub const PipelineConfigInfo = extern struct {
    viewport: c.VkViewport,
    scissor: c.VkRect2D,
    inputAssemblyInfo: c.VkPipelineInputAssemblyStateCreateInfo,
    rasterizationInfo: c.VkPipelineRasterizationStateCreateInfo,
    multisampleInfo: c.VkPipelineMultisampleStateCreateInfo,
    colorBlendAttachment: c.VkPipelineColorBlendAttachmentState,
    colorBlendInfo: c.VkPipelineColorBlendStateCreateInfo,
    depthStencilInfo: c.VkPipelineDepthStencilStateCreateInfo,
    pipelineLayout: c.VkPipelineLayout = null,
    renderPass: c.VkRenderPass = null,
    subpass: u32 = 0,

    pub fn default(width: u32, height: u32) PipelineConfigInfo {
        var configInfo = PipelineConfigInfo{
            .viewport = .{},
            .scissor = .{},
            .inputAssemblyInfo = .{},
            .rasterizationInfo = .{},
            .multisampleInfo = .{},
            .colorBlendAttachment = .{},
            .colorBlendInfo = .{},
            .depthStencilInfo = .{},
        };

        configInfo.inputAssemblyInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        configInfo.inputAssemblyInfo.topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        configInfo.inputAssemblyInfo.primitiveRestartEnable = c.VK_FALSE;

        configInfo.viewport.x = 0.0;
        configInfo.viewport.y = 0.0;
        configInfo.viewport.width = @floatFromInt(width);
        configInfo.viewport.height = @floatFromInt(height);
        configInfo.viewport.minDepth = 0.0;
        configInfo.viewport.maxDepth = 1.0;

        configInfo.scissor.offset = .{ .x = 0, .y = 0 };
        configInfo.scissor.extent = .{ .width = 0, .height = 0 };

        configInfo.rasterizationInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        configInfo.rasterizationInfo.depthClampEnable = c.VK_FALSE;
        configInfo.rasterizationInfo.rasterizerDiscardEnable = c.VK_FALSE;
        configInfo.rasterizationInfo.polygonMode = c.VK_POLYGON_MODE_FILL;
        configInfo.rasterizationInfo.lineWidth = 1.0;
        configInfo.rasterizationInfo.cullMode = c.VK_CULL_MODE_NONE;
        configInfo.rasterizationInfo.frontFace = c.VK_FRONT_FACE_CLOCKWISE;
        configInfo.rasterizationInfo.depthBiasEnable = c.VK_FALSE;
        configInfo.rasterizationInfo.depthBiasConstantFactor = 0.0; // Optional
        configInfo.rasterizationInfo.depthBiasClamp = 0.0; // Optional
        configInfo.rasterizationInfo.depthBiasSlopeFactor = 0.0; // Optional

        configInfo.multisampleInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        configInfo.multisampleInfo.sampleShadingEnable = c.VK_FALSE;
        configInfo.multisampleInfo.rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT;
        configInfo.multisampleInfo.minSampleShading = 1.0; // Optional
        configInfo.multisampleInfo.pSampleMask = null; // Optional
        configInfo.multisampleInfo.alphaToCoverageEnable = c.VK_FALSE; // Optional
        configInfo.multisampleInfo.alphaToOneEnable = c.VK_FALSE; // Optional

        configInfo.colorBlendAttachment.colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT;
        configInfo.colorBlendAttachment.blendEnable = c.VK_FALSE;
        configInfo.colorBlendAttachment.srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE; // Optional
        configInfo.colorBlendAttachment.dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO; // Optional
        configInfo.colorBlendAttachment.colorBlendOp = c.VK_BLEND_OP_ADD; // Optional
        configInfo.colorBlendAttachment.srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE; // Optional
        configInfo.colorBlendAttachment.dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO; // Optional
        configInfo.colorBlendAttachment.alphaBlendOp = c.VK_BLEND_OP_ADD; // Optional

        configInfo.colorBlendInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        configInfo.colorBlendInfo.logicOpEnable = c.VK_FALSE;
        configInfo.colorBlendInfo.logicOp = c.VK_LOGIC_OP_COPY; // Optional
        configInfo.colorBlendInfo.attachmentCount = 1;
        configInfo.colorBlendInfo.pAttachments = &configInfo.colorBlendAttachment;
        configInfo.colorBlendInfo.blendConstants[0] = 0.0; // Optional
        configInfo.colorBlendInfo.blendConstants[1] = 0.0; // Optional
        configInfo.colorBlendInfo.blendConstants[2] = 0.0; // Optional
        configInfo.colorBlendInfo.blendConstants[3] = 0.0; // Optional

        configInfo.depthStencilInfo.sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
        configInfo.depthStencilInfo.depthTestEnable = c.VK_TRUE;
        configInfo.depthStencilInfo.depthWriteEnable = c.VK_TRUE;
        configInfo.depthStencilInfo.depthCompareOp = c.VK_COMPARE_OP_LESS;
        configInfo.depthStencilInfo.depthBoundsTestEnable = c.VK_FALSE;
        configInfo.depthStencilInfo.minDepthBounds = 0.0; // Optional
        configInfo.depthStencilInfo.maxDepthBounds = 1.0; // Optional
        configInfo.depthStencilInfo.stencilTestEnable = c.VK_FALSE;
        configInfo.depthStencilInfo.front = .{}; // Optional
        configInfo.depthStencilInfo.back = .{}; // Optional

        return configInfo;
    }
};
