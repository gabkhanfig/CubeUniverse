const std = @import("std");
const c = @import("../../../clibs.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Window = @import("../Window.zig");

const VK_NULL_HANDLE = null;

pub const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: ArrayList(c.VkSurfaceFormatKHR),
    presentModes: ArrayList(c.VkPresentModeKHR),
};

pub const QueueFamilyIndices = struct {
    graphicsFamily: ?u32,
    presentFamily: ?u32,

    pub fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

pub const Device = struct {
    const Self = @This();

    instance: c.VkInstance,
    debugMessenger: c.VkDebugUtilsMessengerEXT,
    physicalDevice: c.VkPhysicalDevice = VK_NULL_HANDLE,
    window: *Window,
    commandPool: c.VkCommandPool,

    device: c.VkDevice,
    surface: c.VkSurfaceKHR,
    graphicsQueue: c.VkQueue,
    presentQueue: c.VkQueue,

    properties: c.VkPhysicalDeviceProperties,

    pub fn init(window: *Window) Self {}

    pub fn deinit(self: Self) void {}

    pub fn getSwapChainSupport(self: *Self) SwapChainSupportDetails {
        return querySwapChainSupport(self.physicalDevice);
    }

    pub fn findMemoryType(self: *Self, typeFilter: u32, properties: c.VkMemoryPropertyFlags) u32 {}

    pub fn findPhysicalQueueFamilies(self: *Self) QueueFamilyIndices {
        return findQueueFamilies(self.physicalDevice);
    }

    pub fn findSupportedFormat(self: *Self, candidates: ArrayList(c.VkFormat), tiling: c.VkImageTiling, features: c.VkFormatFeatureFlags) c.VkFormat {}

    pub fn createBuffer(size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, bufferMemory: c.VkDeviceMemory) void {}

    pub fn beginSingleTimeCommands(self: *Self) c.VkCommandBuffer {}

    pub fn endSingleTimeCommands(self: *Self, commandBuffer: c.VkCommandBuffer) void {}

    pub fn copyBuffer(self: *Self, srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) void {}

    pub fn copyBufferToImage(self: *Self, buffer: c.VkBuffer, image: c.VkImage, width: u32, height: u32, layerCount: u32) void {}

    pub fn createImageWithInfo(self: *Self, imageInfo: c.VkImageCreateInfo, properties: c.VkMemoryPropertyFlags, image: *c.VkImage, imageMemory: c.VkDeviceMemory) void {}
};

fn isDeviceSuitable(device: c.VkPhysicalDevice) bool {}

fn getRequiredExtensions() ArrayList([*c]const u8) {}

fn checkValidationLayerSupport() bool {}

fn findQueueFamilies(device: c.VkPhysicalDevice) QueueFamilyIndices {}

fn populateDebugMessengerCreateInfo(createInfo: *c.VkDebugUtilsMessengerCreateInfoEXT) void {}

fn hasGlfwRequiredInstanceExtensions() void {}

fn checkDeviceExtensionSupport(device: c.VkPhysicalDevice) bool {}

fn querySwapChainSupport(device: c.VkPhysicalDevice) SwapChainSupportDetails {}

const validationLayers: [][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const deviceExtensions: [][*c]const u8 = .{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

// NOTE may be necessary to write the implementation in a C function for `VKAPI_ATTR` and `VKAPI_CALL` for specific platforms
fn debugCallback(messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: c.VkDebugUtilsMessageTypeFlagsEXT, pCallbackData: ?*const c.VkDebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(.C) c.VkBool32 {
    const severityStr = switch (messageSeverity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warning",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        else => "unknown",
    };

    const typeStr = switch (messageType) {
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT => "device address",
        else => "unknown",
    };

    const message: [*c]const u8 = if (pCallbackData) |callbackData| callbackData.pMessage else "NO MESSAGE!";
    std.log.err("Vulkan validation layer:\n\t[{s}][{s}] Message:\n\t{s}\n", .{ severityStr, typeStr, message });

    if (messageSeverity >= c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
        @panic("Unrecoverable vulkan error occurred");
    }

    return c.VK_FALSE;
}
