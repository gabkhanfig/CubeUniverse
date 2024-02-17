const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const c = @import("../../clibs.zig");
const Device = @import("device.zig").Device;

const MAX_FRAMES_IN_FLIGHT = 2;

const Self = @This();

allocator: Allocator,

swapChainImageFormat: c.VkFormat,
swapChainExtent: c.VkExtent2D,

swapChainFramebuffers: ArrayList(c.VkFramebuffer),
renderPass: c.VkRenderPass,

depthImages: ArrayList(c.VkImage),
depthImageMemorys: ArrayList(c.VkDeviceMemory),
depthImageViews: ArrayList(c.VkImageView),
swapChainImages: ArrayList(c.VkImage),
swapChainImageViews: ArrayList(c.VkImageView),

device: *Device,
windowExtent: c.VkExtent2D,

swapChain: c.VkSwapchainKHR,

imageAvailableSemaphores: ArrayList(c.VkSemaphore),
renderFinishedSemaphores: ArrayList(c.VkSemaphore),
inFlightFences: ArrayList(c.VkFence),
imagesInFlight: ArrayList(c.VkFence),
currentFrame: usize = 0,

pub fn init(allocator: Allocator, device: *Device, windowExtent: c.VkExtent2D) *Self {
    const newSelf = allocator.create(Self) catch unreachable;
    newSelf.currentFrame = 0; // not necessary but just for the sake of explicitness
    newSelf.allocator = allocator;
    newSelf.device = device;
    newSelf.windowExtent = windowExtent;

    newSelf.createSwapChain();
    newSelf.createImageViews();
    newSelf.createRenderPass();
    newSelf.createDepthResources();
    newSelf.createFramebuffers();
    newSelf.createSyncObjects();

    return newSelf;
}

pub fn deinit(self: *Self) void {
    for (self.swapChainImageViews.items) |imageView| {
        c.vkDestroyImageView(self.device.device, imageView, null);
    }
    self.swapChainImageViews.deinit();

    if (self.swapChain != null) {
        c.vkDestroySwapchainKHR(self.device.device, self.swapChain, null);
        self.swapChain = null;
    }

    for (0..self.depthImages.items.len) |i| {
        c.vkDestroyImageView(self.device.device, self.depthImageViews.items[i], null);
        c.vkDestroyImage(self.device.device, self.depthImages.items[i], null);
        c.vkFreeMemory(self.device.device, self.depthImageMemorys.items[i], null);
    }

    for (self.swapChainFramebuffers.items) |framebuffer| {
        c.vkDestroyFramebuffer(self.device.device, framebuffer, null);
    }

    c.vkDestroyRenderPass(self.device.device, self.renderPass, null);

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        c.vkDestroySemaphore(self.device.device, self.renderFinishedSemaphores.items[i], null);
        c.vkDestroySemaphore(self.device.device, self.imageAvailableSemaphores.items[i], null);
        c.vkDestroyFence(self.device.device, self.inFlightFences.items[i], null);
    }

    self.swapChainFramebuffers.deinit();
    self.depthImages.deinit();
    self.depthImageMemorys.deinit();
    self.depthImageViews.deinit();
    self.swapChainImages.deinit();
    self.imageAvailableSemaphores.deinit();
    self.renderFinishedSemaphores.deinit();
    self.inFlightFences.deinit();
    self.imagesInFlight.deinit();
}

pub fn getFrameBuffer(self: Self, index: usize) c.VkFramebuffer {
    return self.swapChainFrameBuffers[index];
}

pub fn getImageView(self: Self, index: usize) c.VkImageView {
    return self.swapChainImageViews[index];
}

pub fn imageCount(self: Self) usize {
    return self.swapChainImages.items.len;
}

pub fn width(self: Self) u32 {
    return self.swapChainExtent.width;
}

pub fn height(self: Self) u32 {
    return self.swapChainExtent.height;
}

pub fn extentAspectRatio(self: Self) f32 {
    const w: f32 = @floatFromInt(self.swapChainExtent.width);
    const h: f32 = @floatFromInt(self.swapChainExtent.height);
    return w / h;
}

pub fn findDepthFormat(self: *Self) c.VkFormat {
    var candidates: [3]c.VkFormat = .{
        @as(c.VkFormat, c.VK_FORMAT_D32_SFLOAT),
        @as(c.VkFormat, c.VK_FORMAT_D32_SFLOAT_S8_UINT),
        @as(c.VkFormat, c.VK_FORMAT_D24_UNORM_S8_UINT),
    };
    const asSlice: []c.VkFormat = &candidates;

    return self.device.findSupportedFormat(
        asSlice,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
    );
}

// NOTE Why is `imageIndex` a pointer?
pub fn acquireNextImage(self: *Self, imageIndex: *u32) c.VkResult {
    c.vkWaitForFences(
        self.device.device,
        1,
        &self.inFlightFences[self.currentFrame],
        c.VK_TRUE,
        std.math.maxInt(u64),
    );

    const result = c.vkAcquireNextImageKHR(
        self.device.device,
        self.swapChain,
        std.math.maxInt(u64),
        self.imageAvailableSemaphores[self.currentFrame],
        c.VK_NULL_HANDLE,
        imageIndex,
    );

    return result;
}

// NOTE Why is `imageIndex` a pointer?
pub fn submitCommandBuffers(self: *Self, buffers: *const c.VkCommandBuffer, imageIndex: *u32) c.VkResult {
    if (self.imagesInFlight[imageIndex.*] != c.VK_NULL_HANDLE) {
        c.vkWaitForFences(self.device.device, 1, &self.imagesInFlight[imageIndex.*], c.VK_TRUE, std.math.maxInt(u64));
    }
    self.imagesInFlight[imageIndex.*] = self.inFlightFences[self.currentFrame];

    var submitInfo: c.VkSubmitInfo = .{};
    submitInfo.sType = c.VK_STRUCTURE_tYPE_SUBMIT_INFO;

    const waitSemaphores: [1]c.VkSemaphore = .{self.imageAvailableSemaphores[self.currentFrame]};
    const waitStages: [1]c.VkPipelineStageFlags = .{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submitInfo.waitSemaphoreCount = 1;
    submitInfo.pWaitSemaphores = &waitSemaphores;
    submitInfo.pWaitDstStageMask = &waitStages;

    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = buffers;

    const signalSemaphores: [1]c.VkSemaphore = .{self.renderFinishedSemaphores[self.currentFrame]};
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores = &signalSemaphores;

    c.vkResetFences(self.device.device, 1, &self.inFlightFences[self.currentFrame]);
    if (c.vkQueueSubmit(self.device.graphicsQueue, 1, submitInfo, self.inFlightFences[self.currentFrame]) != c.VK_SUCCESS) {
        @panic("Failed to submit draw command buffer");
    }

    var presentInfo: c.VkPresentInfoKHR = .{};
    presentInfo.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;

    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = &signalSemaphores;

    const swapChains: [1]c.VkSwapchainKHR = .{self.swapChain};
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = &swapChains;

    presentInfo.pImageIndices = imageIndex;

    const result = c.vkQueuePresentKHR(self.device.presentQueue, &presentInfo);

    self.currentFrame = @mod(self.currentFrame + 1, MAX_FRAMES_IN_FLIGHT);

    return result;
}

fn createSwapChain(self: *Self) void {
    const swapChainSupport = self.device.getSwapChainSupport();

    const surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats);
    const presentMode = chooseSwapPresentMode(swapChainSupport.presentModes);
    const extent = self.chooseSwapExtent(&swapChainSupport.capabilities);

    var imgCount: u32 = swapChainSupport.capabilities.minImageCount + 1;
    if (swapChainSupport.capabilities.maxImageCount > 0 and self.imageCount() > swapChainSupport.capabilities.maxImageCount) {
        imgCount = swapChainSupport.capabilities.maxImageCount;
    }

    var createInfo: c.VkSwapchainCreateInfoKHR = .{};
    createInfo.sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    createInfo.surface = self.device.surface;

    createInfo.minImageCount = imgCount;
    createInfo.imageFormat = surfaceFormat.format;
    createInfo.imageColorSpace = surfaceFormat.colorSpace;
    createInfo.imageExtent = extent;
    createInfo.imageArrayLayers = 1;
    createInfo.imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    const indices = self.device.findPhysicalQueueFamilies();
    const queueFamilyIndices: [2]u32 = .{ indices.graphicsFamily.?, indices.presentFamily.? };

    if (indices.graphicsFamily.? != indices.presentFamily.?) {
        createInfo.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        createInfo.queueFamilyIndexCount = 2;
        createInfo.pQueueFamilyIndices = &queueFamilyIndices;
    } else {
        createInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        createInfo.queueFamilyIndexCount = 0;
        createInfo.pQueueFamilyIndices = null;
    }

    createInfo.preTransform = swapChainSupport.capabilities.currentTransform;
    createInfo.compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

    createInfo.presentMode = presentMode;
    createInfo.clipped = c.VK_TRUE;

    createInfo.oldSwapchain = null;

    if (c.vkCreateSwapchainKHR(self.device.device, &createInfo, null, &self.swapChain) != c.VK_SUCCESS) {
        @panic("Failed to create swap chain!");
    }

    _ = c.vkGetSwapchainImagesKHR(self.device.device, self.swapChain, &imgCount, null);
    self.swapChainImages = ArrayList(c.VkImage).initCapacity(self.allocator, imgCount) catch unreachable;
    self.swapChainImages.items.len = imgCount;
    _ = c.vkGetSwapchainImagesKHR(self.device.device, self.swapChain, &imgCount, self.swapChainImages.items.ptr);

    self.swapChainImageFormat = surfaceFormat.format;
    self.swapChainExtent = extent;
}

fn createImageViews(self: *Self) void {
    const viewCount = self.swapChainImages.items.len;
    self.swapChainImageViews = ArrayList(c.VkImageView).initCapacity(self.allocator, viewCount) catch unreachable;
    self.swapChainImageViews.items.len = viewCount;
    for (0..viewCount) |i| {
        var viewInfo: c.VkImageViewCreateInfo = .{};
        viewInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        viewInfo.image = self.swapChainImages.items[i];
        viewInfo.viewType = c.VK_IMAGE_VIEW_TYPE_2D;
        viewInfo.format = self.swapChainImageFormat;
        viewInfo.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
        viewInfo.subresourceRange.baseMipLevel = 0;
        viewInfo.subresourceRange.levelCount = 1;
        viewInfo.subresourceRange.baseArrayLayer = 0;
        viewInfo.subresourceRange.layerCount = 1;

        if (c.vkCreateImageView(self.device.device, &viewInfo, null, &self.swapChainImageViews.items[i]) != c.VK_SUCCESS) {
            @panic("Failed to create texture image view!");
        }
    }
}

fn createDepthResources(self: *Self) void {
    const depthFormat = self.findDepthFormat();
    const swapChainExtent = self.swapChainExtent;

    const imgCount = self.imageCount();
    self.depthImages = ArrayList(c.VkImage).initCapacity(self.allocator, imgCount) catch unreachable;
    self.depthImages.items.len = imgCount;
    self.depthImageMemorys = ArrayList(c.VkDeviceMemory).initCapacity(self.allocator, imgCount) catch unreachable;
    self.depthImageMemorys.items.len = imgCount;
    self.depthImageViews = ArrayList(c.VkImageView).initCapacity(self.allocator, imgCount) catch unreachable;
    self.depthImageViews.items.len = imgCount;

    //std.debug.print("imgCount: {}\n", .{imgCount});

    for (0..imgCount) |i| {
        var imageInfo: c.VkImageCreateInfo = .{};
        imageInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        imageInfo.imageType = c.VK_IMAGE_TYPE_2D;
        imageInfo.extent.width = swapChainExtent.width;
        imageInfo.extent.height = swapChainExtent.height;
        imageInfo.extent.depth = 1;
        imageInfo.mipLevels = 1;
        imageInfo.arrayLayers = 1;
        imageInfo.format = depthFormat;
        imageInfo.tiling = c.VK_IMAGE_TILING_OPTIMAL;
        imageInfo.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
        imageInfo.usage = c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
        imageInfo.samples = c.VK_SAMPLE_COUNT_1_BIT;
        imageInfo.sharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        imageInfo.flags = 0;

        // var asAddress: usize = @intFromPtr(self.depthImageMemorys.items[i]);
        // std.debug.print("before create image: {}\n", .{asAddress});

        self.device.createImageWithInfo(imageInfo, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &self.depthImages.items[i], &self.depthImageMemorys.items[i]);

        // asAddress = @intFromPtr(self.depthImageMemorys.items[i]);
        // std.debug.print("after create image: {}\n", .{asAddress});

        var viewInfo: c.VkImageViewCreateInfo = .{};
        viewInfo.sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        viewInfo.image = self.depthImages.items[i];
        viewInfo.viewType = c.VK_IMAGE_VIEW_TYPE_2D;
        viewInfo.format = depthFormat;
        viewInfo.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_DEPTH_BIT;
        viewInfo.subresourceRange.baseMipLevel = 0;
        viewInfo.subresourceRange.levelCount = 1;
        viewInfo.subresourceRange.baseArrayLayer = 0;
        viewInfo.subresourceRange.layerCount = 1;

        if (c.vkCreateImageView(self.device.device, &viewInfo, null, &self.depthImageViews.items[i]) != c.VK_SUCCESS) {
            @panic("Failed to create texture image view");
        }
    }
}

fn createRenderPass(self: *Self) void {
    var depthAttachment: c.VkAttachmentDescription = .{};
    depthAttachment.format = self.findDepthFormat();
    depthAttachment.samples = c.VK_SAMPLE_COUNT_1_BIT;
    depthAttachment.loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
    depthAttachment.storeOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    depthAttachment.stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    depthAttachment.stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    depthAttachment.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
    depthAttachment.finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    var depthAttachmentRef: c.VkAttachmentReference = .{};
    depthAttachmentRef.attachment = 1;
    depthAttachmentRef.layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;

    var colorAttachment: c.VkAttachmentDescription = .{};
    colorAttachment.format = self.swapChainImageFormat;
    colorAttachment.samples = c.VK_SAMPLE_COUNT_1_BIT;
    colorAttachment.loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
    colorAttachment.storeOp = c.VK_ATTACHMENT_STORE_OP_STORE;
    colorAttachment.stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    colorAttachment.stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    colorAttachment.initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED;
    colorAttachment.finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    var colorAttachmentRef: c.VkAttachmentReference = .{};
    colorAttachmentRef.attachment = 0;
    colorAttachmentRef.layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var subpass: c.VkSubpassDescription = .{};
    subpass.pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &colorAttachmentRef;
    subpass.pDepthStencilAttachment = &depthAttachmentRef;

    var dependency: c.VkSubpassDependency = .{};
    dependency.srcSubpass = c.VK_SUBPASS_EXTERNAL;
    dependency.srcAccessMask = 0;
    dependency.srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    dependency.dstSubpass = 0;
    dependency.dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
    dependency.dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

    const attachments: [2]c.VkAttachmentDescription = .{ colorAttachment, depthAttachment };

    var renderPassInfo: c.VkRenderPassCreateInfo = .{};
    renderPassInfo.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderPassInfo.attachmentCount = @intCast(attachments.len);
    renderPassInfo.pAttachments = &attachments;
    renderPassInfo.subpassCount = 1;
    renderPassInfo.pSubpasses = &subpass;
    renderPassInfo.dependencyCount = 1;
    renderPassInfo.pDependencies = &dependency;

    if (c.vkCreateRenderPass(self.device.device, &renderPassInfo, null, &self.renderPass) != c.VK_SUCCESS) {
        @panic("Failed to create render pass");
    }
}

fn createFramebuffers(self: *Self) void {
    self.swapChainFramebuffers = ArrayList(c.VkFramebuffer).initCapacity(self.allocator, self.imageCount()) catch unreachable;
    self.swapChainFramebuffers.items.len = self.imageCount();

    for (0..self.imageCount()) |i| {
        const attachments: [2]c.VkImageView = .{ self.swapChainImageViews.items[i], self.depthImageViews.items[i] };

        const swapChainExtent = self.swapChainExtent;
        var framebufferInfo: c.VkFramebufferCreateInfo = .{};
        framebufferInfo.sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        framebufferInfo.renderPass = self.renderPass;
        framebufferInfo.attachmentCount = @intCast(attachments.len);
        framebufferInfo.pAttachments = &attachments;
        framebufferInfo.width = swapChainExtent.width;
        framebufferInfo.height = swapChainExtent.height;
        framebufferInfo.layers = 1;

        if (c.vkCreateFramebuffer(self.device.device, &framebufferInfo, null, &self.swapChainFramebuffers.items[i]) != c.VK_SUCCESS) {
            @panic("Failed to create framebuffer!");
        }
    }
}

fn createSyncObjects(self: *Self) void {
    self.imageAvailableSemaphores = ArrayList(c.VkSemaphore).initCapacity(self.allocator, MAX_FRAMES_IN_FLIGHT) catch unreachable;
    self.imageAvailableSemaphores.items.len = MAX_FRAMES_IN_FLIGHT;

    self.renderFinishedSemaphores = ArrayList(c.VkSemaphore).initCapacity(self.allocator, MAX_FRAMES_IN_FLIGHT) catch unreachable;
    self.renderFinishedSemaphores.items.len = MAX_FRAMES_IN_FLIGHT;

    self.inFlightFences = ArrayList(c.VkFence).initCapacity(self.allocator, MAX_FRAMES_IN_FLIGHT) catch unreachable;
    self.inFlightFences.items.len = MAX_FRAMES_IN_FLIGHT;

    self.imagesInFlight = ArrayList(c.VkFence).initCapacity(self.allocator, self.imageCount()) catch unreachable;
    self.imagesInFlight.items.len = self.imageCount();

    var semaphoreInfo: c.VkSemaphoreCreateInfo = .{};
    semaphoreInfo.sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    var fenceInfo: c.VkFenceCreateInfo = .{};
    fenceInfo.sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fenceInfo.flags = c.VK_FENCE_CREATE_SIGNALED_BIT;

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        const resultImageAvailableSemaphore = c.vkCreateSemaphore(self.device.device, &semaphoreInfo, null, &self.imageAvailableSemaphores.items[i]);
        const resultRenderFinishedSemaphore = c.vkCreateSemaphore(self.device.device, &semaphoreInfo, null, &self.renderFinishedSemaphores.items[i]);
        const resultInFlightFence = c.vkCreateFence(self.device.device, &fenceInfo, null, &self.inFlightFences.items[i]);

        if (resultImageAvailableSemaphore != c.VK_SUCCESS or resultRenderFinishedSemaphore != c.VK_SUCCESS or resultInFlightFence != c.VK_SUCCESS) {
            @panic("Failed to create synchronization objects for a frame!");
        }
    }
}

fn chooseSwapSurfaceFormat(availableFormats: ArrayList(c.VkSurfaceFormatKHR)) c.VkSurfaceFormatKHR {
    for (availableFormats.items) |availableFormat| {
        if (availableFormat.format == c.VK_FORMAT_B8G8R8A8_UNORM and availableFormat.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return availableFormat;
        }
    }

    return availableFormats.items[0];
}

fn chooseSwapPresentMode(availablePresentModes: ArrayList(c.VkPresentModeKHR)) c.VkPresentModeKHR {
    for (availablePresentModes.items) |availablePresentMode| {
        if (availablePresentMode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            std.debug.print("Present mode: Mailbox\n", .{});
            return availablePresentMode;
        }
    }

    std.debug.print("Present mode: V-Sync\n", .{});
    return c.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapExtent(self: *Self, capabilities: *const c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    }

    var actualExtent = self.windowExtent;
    actualExtent.width = @max(capabilities.minImageExtent.width, @min(capabilities.maxImageExtent.width, actualExtent.width));
    actualExtent.height = @max(capabilities.minImageExtent.height, @min(capabilities.maxImageExtent.height, actualExtent.height));

    return actualExtent;
}
