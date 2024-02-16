const std = @import("std");
const c = @import("../../clibs.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Window = @import("../Window.zig");

const VK_NULL_HANDLE = null;
const VK_SUCCESS = c.VK_SUCCESS;
const VK_TRUE = c.VK_TRUE;
const VK_FALSE = c.VK_FALSE;
const enableValidationLayers = true;

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

    allocator: Allocator,

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

    pub fn init(allocator: Allocator, window: *Window) Self {
        var newSelf: Self = undefined;

        newSelf.allocator = allocator;
        newSelf.window = window;

        newSelf.createInstance();
        newSelf.setupDebugMessenger();
        newSelf.createSurface();
        newSelf.pickPhysicalDevice();
        newSelf.createLogicalDevice();
        newSelf.createCommandPool();
        return newSelf;
    }

    pub fn deinit(self: Self) void {
        c.vkDestroyCommandPool(self.device, self.commandPool, null);
        c.vkDestroyDevice(self.device, null);

        if (enableValidationLayers) {
            destroyDebugUtilsMessengerEXT(self.instance, self.debugMessenger, null);
        }

        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }

    pub fn getSwapChainSupport(self: *Self) SwapChainSupportDetails {
        return querySwapChainSupport(self.physicalDevice, self.allocator);
    }

    pub fn findMemoryType(self: *Self, typeFilter: u32, properties: c.VkMemoryPropertyFlags) u32 {
        var memProperties: c.VkPhysicalDeviceMemoryProperties = .{};
        c.vkGetPhysicalDeviceMemoryProperties(self.physicalDevice, &memProperties);
        for (0..memProperties.memoryTypeCount) |i| {
            const bitshift: u5 = @intCast(i);
            if ((typeFilter & @shrExact(@as(u32, 1), bitshift)) and (memProperties.memoryTypes[i].propertyFlags & properties) == properties) {
                return i;
            }
        }

        @panic("Failed to find suitable memory type!");
    }

    pub fn findPhysicalQueueFamilies(self: *Self) QueueFamilyIndices {
        return findQueueFamilies(self.physicalDevice, self.surface, self.allocator);
    }

    pub fn findSupportedFormat(self: *Self, candidates: ArrayList(c.VkFormat), tiling: c.VkImageTiling, features: c.VkFormatFeatureFlags) c.VkFormat {
        for (candidates.items) |format| {
            var props: c.VkFormatProperties = .{};
            c.vkGetPhysicalDeviceFormatProperties(self.physicalDevice, format, &props);

            if (tiling == c.VK_IMAGE_TILING_LINEAR and (props.linearTilingFeatures & features) == features) {
                return format;
            } else if (tiling == c.VK_IMAGE_TILING_OPTIMAL and (props.optimalTilingFeatures & features) == features) {
                return format;
            }
        }
        @panic("Failed to find supported format!");
    }

    pub fn createBuffer(self: *Self, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, bufferMemory: *c.VkDeviceMemory) void {
        var bufferInfo: c.VkBufferCreateInfo = .{};
        bufferInfo.sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        bufferInfo.size = size;
        bufferInfo.usage = usage;
        bufferInfo.sharingMode = c.VK_SHARING_MODE_EXCLUSIVE;

        if (c.vkCreateBuffer(self.device, &bufferInfo, null, buffer) != VK_SUCCESS) {
            @panic("Failed to create vertex buffer");
        }

        var memRequirements: c.VkMemoryRequirements = .{};
        c.vkGetBufferMemoryRequirements(self.device, buffer.*, &memRequirements);

        var allocInfo: c.VkMemoryAllocateInfo = .{};
        allocInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocInfo.allocationSize = memRequirements.size;
        allocInfo.memoryTypeIndex = self.findMemoryType(memRequirements.memoryTypeBits, properties);

        if (c.vkAllocateMemory(self.device, &allocInfo, null, bufferMemory) != c.VK_SUCCESS) {
            @panic("Failed to allocate vertex buffer memory");
        }

        c.vkBindBufferMemory(self.device, buffer.*, bufferMemory.*, 0);
    }

    pub fn beginSingleTimeCommands(self: *Self) c.VkCommandBuffer {
        var allocInfo: c.VkCommandBufferAllocateInfo = .{};
        allocInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocInfo.level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        allocInfo.commandPool = self.commandPool;
        allocInfo.commandBufferCount = 1;

        var commandBuffer: c.VkCommandBufferBeginInfo = .{};
        c.vkAllocateCommandBuffers(self.device, &allocInfo, &commandBuffer);

        var beginInfo: c.VkCommandBufferBeginInfo = .{};
        beginInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        beginInfo.flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

        c.vkBeginCommandBuffer(commandBuffer, &beginInfo);
        return commandBuffer;
    }

    pub fn endSingleTimeCommands(self: *Self, commandBuffer: c.VkCommandBuffer) void {
        c.vkEndCommandBuffer(commandBuffer);

        var submitInfo: c.VkSubmitInfo = .{};
        submitInfo.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &commandBuffer;

        c.vkQueueSubmit(self.graphicsQueue, 1, &submitInfo, VK_NULL_HANDLE);
        c.vkQueueWaitIdle(self.graphicsQueue);

        c.vkFreeCommandBuffers(self.device, self.commandPool, 1, &commandBuffer);
    }

    pub fn copyBuffer(self: *Self, srcBuffer: c.VkBuffer, dstBuffer: c.VkBuffer, size: c.VkDeviceSize) void {
        const commandBuffer = self.beginSingleTimeCommands();

        var copyRegion: c.VkBufferCopy = .{};
        copyRegion.srcOffset = 0;
        copyRegion.dstOffset = 0;
        copyRegion.size = size;
        c.vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

        self.endSingleTimeCommands(commandBuffer);
    }

    pub fn copyBufferToImage(self: *Self, buffer: c.VkBuffer, image: c.VkImage, width: u32, height: u32, layerCount: u32) void {
        const commandBuffer = self.beginSingleTimeCommands();

        var region: c.VkBufferImageCopy = .{};
        region.bufferOffset = 0;
        region.bufferRowLength = 0;
        region.bufferImageHeight = 0;

        region.imageSubresource.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
        region.imageSubresource.mipLevel = 0;
        region.imageSubresource.baseArrayLayer = 0;
        region.imageSubresource.layerCount = layerCount;

        region.imageOffset = .{ .x = 0, .y = 0, .z = 0 };
        region.imageExtent = .{ .width = width, .height = height, .depth = 0 };

        c.vkCmdCopyBufferToImage(commandBuffer, buffer, image, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
        self.endSingleTimeCommands(commandBuffer);
    }

    pub fn createImageWithInfo(self: *Self, imageInfo: c.VkImageCreateInfo, properties: c.VkMemoryPropertyFlags, image: *c.VkImage, imageMemory: c.VkDeviceMemory) void {
        if (c.vkCreateImage(self.device, &imageInfo, null, &image) != VK_SUCCESS) {
            @panic("Failed to create image");
        }

        var memRequirements: c.VkMemoryRequirements = .{};
        c.vkGetImageMemoryRequirements(self.device, image, &memRequirements);

        var allocInfo: c.VkMemoryAllocateInfo = .{};
        allocInfo.sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        allocInfo.allocationSize = memRequirements.size;
        allocInfo.memoryTypeIndex = self.findMemoryType(memRequirements.memoryTypeBits, properties);

        if (c.vkAllocateMemory(self.device, &allocInfo, null, &imageMemory) != VK_SUCCESS) {
            @panic("Failed to allocate image memory!");
        }

        if (c.vkBindImageMemory(self.device, image, imageMemory, 0) != VK_SUCCESS) {
            @panic("Failed to bind image memory!");
        }
    }

    fn createInstance(self: *Self) void {
        if (enableValidationLayers and !checkValidationLayerSupport(self.allocator)) {
            @panic("validation layers requested, but not available!");
        }

        var appInfo: c.VkApplicationInfo = .{};
        appInfo.sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "Vulkan Engine";
        appInfo.applicationVersion = c.VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "Cube Universe Engine";
        appInfo.engineVersion = c.VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion = c.VK_API_VERSION_1_0;

        var createInfo: c.VkInstanceCreateInfo = .{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &appInfo;

        const extensions = getRequiredExtensions(self.allocator);
        defer extensions.deinit();

        createInfo.enabledExtensionCount = @intCast(extensions.items.len);
        createInfo.ppEnabledExtensionNames = extensions.items.ptr;

        var debugCreateInfo: c.VkDebugUtilsMessengerCreateInfoEXT = .{};
        if (enableValidationLayers) {
            createInfo.enabledLayerCount = @intCast(validationLayers.len);
            createInfo.ppEnabledLayerNames = &validationLayers;

            populateDebugMessengerCreateInfo(&debugCreateInfo);
            const asDebugCreateInfoEXT: *c.VkDebugUtilsMessengerCreateInfoEXT = @ptrCast(&debugCreateInfo);
            createInfo.pNext = @ptrCast(asDebugCreateInfoEXT);
        } else {
            createInfo.enabledLayerCount = 0;
            createInfo.pNext = null;
        }

        if (c.vkCreateInstance(&createInfo, null, &self.instance) != VK_SUCCESS) {
            @panic("Failed to create vulkan instance!");
        }

        hasGlfwRequiredInstanceExtensions(self.allocator);
    }

    fn setupDebugMessenger(self: *Self) void {
        if (!enableValidationLayers) return;

        var createInfo: c.VkDebugUtilsMessengerCreateInfoEXT = .{};
        populateDebugMessengerCreateInfo(&createInfo);
        if (createDebugUtilsMessengerEXT(self.instance, &createInfo, null, &self.debugMessenger) != VK_SUCCESS) {
            @panic("Failed to setup debug messenger!");
        }
    }

    fn createSurface(self: *Self) void {
        self.window.createSurface(self.instance, &self.surface);
    }

    fn pickPhysicalDevice(self: *Self) void {
        self.physicalDevice = std.mem.zeroes(c.VkPhysicalDevice);

        var deviceCount: u32 = undefined;
        _ = c.vkEnumeratePhysicalDevices(self.instance, &deviceCount, null);
        if (deviceCount == 0) {
            @panic("Failed to find GPUs with Vulkan support!");
        }
        std.debug.print("Vulkan GPU count: {}\n", .{deviceCount});

        const devices = self.allocator.alloc(c.VkPhysicalDevice, deviceCount) catch unreachable;
        _ = c.vkEnumeratePhysicalDevices(self.instance, &deviceCount, devices.ptr);

        for (devices) |device| {
            if (isDeviceSuitable(device, self.surface, self.allocator)) {
                self.physicalDevice = device;
                break;
            }
        }

        if (self.physicalDevice == VK_NULL_HANDLE) {
            @panic("Failed to find a suitable GPU!");
        }

        c.vkGetPhysicalDeviceProperties(self.physicalDevice, &self.properties);
        std.debug.print("physical device: {s}\n", .{self.properties.deviceName});
    }

    fn createLogicalDevice(self: *Self) void {
        const indices = findQueueFamilies(self.physicalDevice, self.surface, self.allocator);

        var queueCreateInfos = ArrayList(c.VkDeviceQueueCreateInfo).init(self.allocator);
        defer queueCreateInfos.deinit();

        var uniqueQueueFamilies = ArrayList(u32).init(self.allocator);
        defer uniqueQueueFamilies.deinit();

        uniqueQueueFamilies.append(indices.graphicsFamily.?) catch unreachable;
        if (uniqueQueueFamilies.items[0] != indices.presentFamily.?) {
            uniqueQueueFamilies.append(indices.presentFamily.?) catch unreachable;
        }

        const queuePriority: f32 = 1.0;
        for (uniqueQueueFamilies.items) |queueFamily| {
            var queueCreateInfo: c.VkDeviceQueueCreateInfo = .{};
            queueCreateInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
            queueCreateInfo.queueFamilyIndex = queueFamily;
            queueCreateInfo.queueCount = 1;
            queueCreateInfo.pQueuePriorities = &queuePriority;
            queueCreateInfos.append(queueCreateInfo) catch unreachable;
        }

        var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
        deviceFeatures.samplerAnisotropy = VK_TRUE;

        var createInfo: c.VkDeviceCreateInfo = .{};
        createInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;

        createInfo.queueCreateInfoCount = @intCast(queueCreateInfos.items.len);
        createInfo.pQueueCreateInfos = queueCreateInfos.items.ptr;

        createInfo.pEnabledFeatures = &deviceFeatures;
        createInfo.enabledExtensionCount = @intCast(deviceExtensions.len);
        createInfo.ppEnabledExtensionNames = &deviceExtensions;

        // might not really be necessary anymore because device specific validation layers
        // have been deprecated
        // if (enableValidationLayers) {
        //     createInfo.enabledLayerCount = @intCast(validationLayers.len);
        //     createInfo.ppEnabledExtensionNames = &validationLayers;
        // } else {
        //     createInfo.enabledLayerCount = 0;
        // }

        if (c.vkCreateDevice(self.physicalDevice, &createInfo, null, &self.device) != VK_SUCCESS) {
            @panic("Failed to create logical device");
        }

        c.vkGetDeviceQueue(self.device, indices.graphicsFamily.?, 0, &self.graphicsQueue);
        c.vkGetDeviceQueue(self.device, indices.presentFamily.?, 0, &self.presentQueue);
    }

    fn createCommandPool(self: *Self) void {
        const queueFamilyIndices = self.findPhysicalQueueFamilies();

        var poolInfo: c.VkCommandPoolCreateInfo = .{};
        poolInfo.sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        poolInfo.queueFamilyIndex = queueFamilyIndices.graphicsFamily.?;
        poolInfo.flags = c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

        if (c.vkCreateCommandPool(self.device, &poolInfo, null, &self.commandPool) != VK_SUCCESS) {
            @panic("Failed to create command pool!");
        }
    }
};

fn isDeviceSuitable(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR, allocator: Allocator) bool {
    const indices = findQueueFamilies(device, surface, allocator);

    const extensionsSupported = checkDeviceExtensionSupport(device, allocator);

    var swapChainAdequate = false;
    if (extensionsSupported) {
        const swapChainSupport = querySwapChainSupport(device, surface, allocator);
        swapChainAdequate = swapChainSupport.formats.items.len > 0 and swapChainSupport.presentModes.items.len > 0;
    }

    var supportedFeatures: c.VkPhysicalDeviceFeatures = .{};
    c.vkGetPhysicalDeviceFeatures(device, &supportedFeatures);

    return indices.isComplete() and extensionsSupported and swapChainAdequate and supportedFeatures.samplerAnisotropy == VK_TRUE;
}

fn getRequiredExtensions(allocator: Allocator) ArrayList([*c]const u8) {
    var glfwExtensionCount: u32 = undefined;
    const glfwExtensions = c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    var extensions = ArrayList([*c]const u8).init(allocator);
    for (0..glfwExtensionCount) |i| {
        extensions.append(glfwExtensions[i]) catch unreachable;
    }

    if (enableValidationLayers) {
        extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME) catch unreachable;
    }

    return extensions;
}

fn checkValidationLayerSupport(allocator: Allocator) bool {
    var layerCount: u32 = undefined;
    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, null);

    const availableLayers = allocator.alloc(c.VkLayerProperties, layerCount) catch unreachable;
    defer allocator.free(availableLayers);

    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr);

    for (validationLayers) |layerName| {
        var layerFound = false;

        for (availableLayers) |layerProperties| {
            const layerNameSlice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(layerName)), 0);
            const propertiesNameSlice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(layerProperties.layerName[0..layerNameSlice.len].ptr)), 0);
            if (std.mem.eql(u8, layerNameSlice, propertiesNameSlice)) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            return false;
        }
    }

    return true;
}

fn findQueueFamilies(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR, allocator: Allocator) QueueFamilyIndices {
    var properties: c.VkPhysicalDeviceProperties = .{};
    c.vkGetPhysicalDeviceProperties(device, &properties);

    var indices = QueueFamilyIndices{ .graphicsFamily = null, .presentFamily = null };

    var queueFamilyCount: u32 = undefined;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch unreachable;
    defer allocator.free(queueFamilies);

    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var i: u32 = 0;
    for (queueFamilies) |queueFamily| {
        if (queueFamily.queueCount > 0 and (queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
            indices.graphicsFamily = i;
        }

        var presentSupport: c.VkBool32 = VK_FALSE;
        _ = c.vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &presentSupport);
        if (queueFamily.queueCount > 0 and presentSupport == VK_TRUE) {
            indices.presentFamily = i;
        }

        if (indices.isComplete()) {
            break;
        }

        i += 1;
    }

    return indices;
}

fn populateDebugMessengerCreateInfo(createInfo: *c.VkDebugUtilsMessengerCreateInfoEXT) void {
    createInfo.* = .{};
    createInfo.sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    createInfo.messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
    createInfo.messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
    createInfo.pfnUserCallback = debugCallback;
    createInfo.pUserData = null;
}

fn hasGlfwRequiredInstanceExtensions(allocator: Allocator) void {
    var extensionCount: u32 = undefined;
    _ = c.vkEnumerateInstanceExtensionProperties(null, &extensionCount, null);

    const extensions = allocator.alloc(c.VkExtensionProperties, extensionCount) catch unreachable;
    defer allocator.free(extensions);

    _ = c.vkEnumerateInstanceExtensionProperties(null, &extensionCount, extensions.ptr);

    std.debug.print("available extensions:\n", .{});

    const available = allocator.alloc([*c]const u8, extensions.len) catch unreachable;
    defer allocator.free(available);

    {
        var appendIter: usize = 0;
        for (0..extensions.len) |i| {
            const extensionName = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&extensions[i].extensionName)), 0);
            std.debug.print("\t{s}\n", .{extensionName});

            var contains = false;

            for (0..appendIter) |availableIter| {
                const nameSlice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(available[availableIter])), 0);

                if (std.mem.eql(u8, extensionName, nameSlice)) {
                    contains = true;
                    break;
                }
            }

            if (contains == false) {
                available[appendIter] = extensionName.ptr;
                appendIter += 1;
            }
        }
    }

    std.debug.print("required extensions:\n", .{});

    const requiredExtensions = getRequiredExtensions(allocator);
    defer requiredExtensions.deinit();

    for (requiredExtensions.items) |requiredExtension| {
        std.debug.print("\t{s}\n", .{requiredExtension});
    }

    for (requiredExtensions.items) |requiredExtension| {
        const extensionName = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(requiredExtension)), 0);
        //std.debug.print("\t{s}\n", .{extensionName});

        var found = false;

        for (available) |name| {
            const nameSlice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(name)), 0);

            if (std.mem.eql(u8, extensionName, nameSlice)) {
                std.debug.print("found extension: {s}\n", .{extensionName});
                found = true;
                break;
            }
        }

        if (!found) {
            @panic("Missing required glfw extension");
        }
    }
}

fn checkDeviceExtensionSupport(device: c.VkPhysicalDevice, allocator: Allocator) bool {
    var extensionCount: u32 = undefined;
    _ = c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null);

    const availableExtensions = allocator.alloc(c.VkExtensionProperties, extensionCount) catch unreachable;
    _ = c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr);

    var requiredExtensions = ArrayList([*c]const u8).init(allocator);
    defer requiredExtensions.deinit();

    for (deviceExtensions) |e| {
        requiredExtensions.append(e) catch unreachable;
    }

    for (availableExtensions) |extension| {
        var i: usize = 0;
        for (0..requiredExtensions.items.len) |_| {
            if (cstrEql(&extension.extensionName, requiredExtensions.items[i])) {
                _ = requiredExtensions.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    return requiredExtensions.items.len == 0;
}

fn querySwapChainSupport(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR, allocator: Allocator) SwapChainSupportDetails {
    var details = SwapChainSupportDetails{
        .capabilities = .{},
        .formats = ArrayList(c.VkSurfaceFormatKHR).init(allocator),
        .presentModes = ArrayList(c.VkPresentModeKHR).init(allocator),
    };

    _ = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities);

    var formatCount: u32 = undefined;
    _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null);

    if (formatCount != 0) {
        details.formats.resize(formatCount) catch unreachable;
        _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, details.formats.items.ptr);
    }

    var presentModeCount: u32 = undefined;
    _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null);

    if (presentModeCount != 0) {
        details.presentModes.resize(presentModeCount) catch unreachable;
        _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, details.presentModes.items.ptr);
    }

    return details;
}

const validationLayers: [1][*c]const u8 = .{"VK_LAYER_KHRONOS_validation"};
const deviceExtensions: [1][*c]const u8 = .{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

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

fn createDebugUtilsMessengerEXT(instance: c.VkInstance, pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const c.VkAllocationCallbacks, pDebugMessenger: *c.VkDebugUtilsMessengerEXT) c.VkResult {
    const func: c.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
        instance,
        "vkCreateDebugUtilsMessengerEXT",
    ));
    if (func != null) {
        const f = func.?;
        return f(instance, pCreateInfo, pAllocator, pDebugMessenger);
    } else {
        return c.VK_ERROR_EXTENSION_NOT_PRESENT;
    }
}

fn destroyDebugUtilsMessengerEXT(instance: c.VkInstance, debugMessenger: c.VkDebugUtilsMessengerEXT, pAllocator: ?*const c.VkAllocationCallbacks) void {
    const func: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(
        instance,
        "vkDestroyDebugUtilsMessengerEXT",
    ));
    if (func != null) {
        const f = func.?;
        f(instance, debugMessenger, pAllocator);
    }
}

fn cstrEql(a: [*c]const u8, b: [*c]const u8) bool {
    const aSlice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(a)), 0);
    const bSlice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(b)), 0);
    return std.mem.eql(u8, aSlice, bSlice);
}
