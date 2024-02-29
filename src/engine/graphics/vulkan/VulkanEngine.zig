const std = @import("std");
const c = @import("../../../clibs.zig");
const vk_types = @import("vk_types.zig");
const vkCheck = vk_types.vkCheck;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Self = @This();

const VK_NULL_HANDLE = null;

const WINDOW_EXTENT = c.VkExtent2D{ .width = 1920, .height = 1080 };

allocator: Allocator,

frameNumber: i32 = 0,
stopRendering: bool = false,
enableValidationLayers: bool = true,

windowExtent: c.VkExtent2D,
window: *c.SDL_Window = undefined,

instance: c.VkInstance = VK_NULL_HANDLE,
debugMessenger: c.VkDebugUtilsMessengerEXT = VK_NULL_HANDLE,

physicalDevice: c.VkPhysicalDevice = VK_NULL_HANDLE,
device: c.VkDevice = VK_NULL_HANDLE,
surface: c.VkSurfaceKHR = VK_NULL_HANDLE,

graphicsQueue: c.VkQueue = VK_NULL_HANDLE,
graphicsQueueFamily: u32 = undefined,
presentQueue: c.VkQueue = VK_NULL_HANDLE,
presentQueueFamily: u32 = undefined,

swapChain: c.VkSwapchainKHR = VK_NULL_HANDLE,

pub fn init(allocator: Allocator) Self {
    checkSdl(c.SDL_Init(c.SDL_INIT_VIDEO));

    const window = c.SDL_CreateWindow("Vulkan Engine", 0, 0, WINDOW_EXTENT.width, WINDOW_EXTENT.height, c.SDL_WINDOW_VULKAN) orelse @panic("Failed to create SDL window");

    var engine = Self{
        .window = window,
        .allocator = allocator,
        .windowExtent = WINDOW_EXTENT,
    };

    engine.createInstance();
    engine.setupDebugMessenger();
    engine.createSurface();
    engine.selectPhysicalDevice();

    const indices = QueueFamilyIndices.findQueueFamilies(engine.allocator, engine.physicalDevice, engine.surface);
    engine.graphicsQueueFamily = indices.graphicsFamily.?;
    engine.presentQueueFamily = indices.presentFamily.?;

    engine.createLogicalDevice();

    return engine;
}

pub fn cleanup(self: *Self) void {
    //c.vkDestroySwapchainKHR(self.device, self.swapChain, null);
    c.vkDestroyDevice(self.device, null);
    self.destroyDebugMessenger();
    c.vkDestroySurfaceKHR(self.instance, self.surface, null);
    c.vkDestroyInstance(self.instance, null);
    c.SDL_DestroyWindow(self.window);
}

fn createInstance(self: *Self) void {
    const appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Hello Triangle",
        .applicationVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .pEngineName = "No Engine",
        .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .apiVersion = c.VK_MAKE_VERSION(1, 3, 0),
        .pNext = VK_NULL_HANDLE,
    };

    var sdlExtensionCount: u32 = undefined;
    _ = c.SDL_Vulkan_GetInstanceExtensions(self.window, &sdlExtensionCount, null);
    const sdlExtensions = self.allocator.alloc([*c]const u8, sdlExtensionCount) catch unreachable;
    defer self.allocator.free(sdlExtensions);
    _ = c.SDL_Vulkan_GetInstanceExtensions(self.window, &sdlExtensionCount, sdlExtensions.ptr);

    // TODO maybe append VK_EXT_DEBUG_UTILS_EXTENSION_NAME and VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME

    const requiredExtensions = self.getRequiredExtensions();
    defer requiredExtensions.deinit();

    const validationLayers = self.getValidationLayers();
    defer validationLayers.deinit();

    if (self.enableValidationLayers and !checkValidationLayerSupport(validationLayers)) {
        @panic("Validation layers requested, but not available!");
    }

    var createInfo: c.VkInstanceCreateInfo = .{};
    createInfo.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = @intCast(requiredExtensions.items.len);
    createInfo.ppEnabledExtensionNames = requiredExtensions.items.ptr;
    createInfo.flags |= @intCast(c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR);

    if (self.enableValidationLayers) {
        createInfo.enabledLayerCount = @intCast(validationLayers.items.len);
        createInfo.ppEnabledLayerNames = validationLayers.items.ptr;
    } else {
        createInfo.enabledLayerCount = 0;
    }

    vkCheck(c.vkCreateInstance(&createInfo, null, &self.instance));
    std.debug.print("Created Vulkan Instance\n", .{});
}

fn setupDebugMessenger(self: *Self) void {
    if (!self.enableValidationLayers) return;

    var createInfo: c.VkDebugUtilsMessengerCreateInfoEXT = .{};
    createInfo.sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    createInfo.messageSeverity = @intCast(c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT);
    createInfo.messageType = @intCast(c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT);
    createInfo.pfnUserCallback = Self.debugCallback;
    createInfo.pUserData = null; // optional?

    const createFnOpt = self.getVulkanInstanceFunc(c.PFN_vkCreateDebugUtilsMessengerEXT, "vkCreateDebugUtilsMessengerEXT");
    if (createFnOpt) |createFn| {
        vkCheck(createFn(self.instance, &createInfo, null, &self.debugMessenger));
        std.debug.print("Created vulkan debug messenger\n", .{});
        return;
    }

    @panic("Failed to create Vulkan debug messenger");
}

fn createSurface(self: *Self) void {
    checkSdlBool(c.SDL_Vulkan_CreateSurface(self.window, self.instance, &self.surface));
}

fn selectPhysicalDevice(self: *Self) void {
    var physicalDeviceCount: u32 = undefined;
    vkCheck(c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, null));
    if (physicalDeviceCount == 0) {
        @panic("Failed to find GPUs with Vulkan support!");
    }

    const physicalDevices = self.allocator.alloc(c.VkPhysicalDevice, physicalDeviceCount) catch unreachable;
    defer self.allocator.free(physicalDevices);

    vkCheck(c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, physicalDevices.ptr));
    self.pickPhysicalDevice(physicalDevices);
}

fn createLogicalDevice(self: *Self) void {
    // https://vulkan-tutorial.com/Drawing_a_triangle/Setup/Logical_device_and_queues#:~:text=queueCreateInfo.pQueuePriorities%20%3D%20%26queuePriority%3B-,Specifying%20used%20device%20features,-The%20next%20information
    const deviceFeatures: c.VkPhysicalDeviceFeatures = .{};

    var uniqueQueueFamilies = ArrayList(u32).init(self.allocator);
    defer uniqueQueueFamilies.deinit();

    // for more queues, this should iterate through the ArrayList, seeing if it contains the value.
    // alternatively, a set would work. Maybe custom implemention or eventual zig std implementation?
    uniqueQueueFamilies.append(self.graphicsQueueFamily) catch unreachable;
    if (self.graphicsQueueFamily == self.presentQueueFamily) {
        uniqueQueueFamilies.append(self.presentQueueFamily) catch unreachable;
    }

    var queueCreateInfos = ArrayList(c.VkDeviceQueueCreateInfo).init(self.allocator);
    defer queueCreateInfos.deinit();

    var queuePriority: f32 = 1.0;
    for (uniqueQueueFamilies.items) |queueFamily| {
        var queueCreateInfo: c.VkDeviceQueueCreateInfo = .{};
        queueCreateInfo.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueCreateInfo.queueFamilyIndex = queueFamily;
        queueCreateInfo.queueCount = 1;
        queueCreateInfo.pQueuePriorities = &queuePriority;

        queueCreateInfos.append(queueCreateInfo) catch unreachable;
    }

    const validationLayers = self.getValidationLayers();
    defer validationLayers.deinit();

    const deviceExtensions = self.getDeviceExtensions();
    defer deviceExtensions.deinit();

    var createInfo: c.VkDeviceCreateInfo = .{};
    createInfo.sType = @intCast(c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    createInfo.pQueueCreateInfos = queueCreateInfos.items.ptr;
    createInfo.queueCreateInfoCount = @intCast(queueCreateInfos.items.len);
    createInfo.pEnabledFeatures = &deviceFeatures;
    createInfo.enabledExtensionCount = @intCast(deviceExtensions.items.len);
    createInfo.ppEnabledExtensionNames = deviceExtensions.items.ptr;

    if (self.enableValidationLayers) {
        createInfo.enabledLayerCount = @intCast(validationLayers.items.len);
        createInfo.ppEnabledLayerNames = validationLayers.items.ptr;
    } else {
        createInfo.enabledLayerCount = 0;
    }

    vkCheck(c.vkCreateDevice(self.physicalDevice, &createInfo, null, &self.device));
    c.vkGetDeviceQueue(self.device, self.graphicsQueueFamily, 0, &self.graphicsQueue);
    //c.vkGetDeviceQueue(self.device, self.presentQueueFamily, 0, &self.presentQueue);
}

fn destroyDebugMessenger(self: *Self) void {
    if (!self.enableValidationLayers) return;

    const destroyFnOpt = self.getVulkanInstanceFunc(c.PFN_vkDestroyDebugUtilsMessengerEXT, "vkDestroyDebugUtilsMessengerEXT");
    if (destroyFnOpt) |destroyFn| {
        destroyFn(self.instance, self.debugMessenger, null);
        return;
    }

    @panic("Failed to destroy Vulkan debug messenger");
}

fn getRequiredExtensions(self: *const Self) ArrayList([*c]const u8) {
    var requiredExtensions = ArrayList([*c]const u8).init(self.allocator);

    var sdlExtensionCount: u32 = 0;
    _ = c.SDL_Vulkan_GetInstanceExtensions(@ptrCast(self.window), &sdlExtensionCount, null);
    std.debug.print("\nextension count: {}\n", .{sdlExtensionCount});
    const sdlExtensions = self.allocator.alloc([*c]const u8, sdlExtensionCount) catch unreachable;
    defer self.allocator.free(sdlExtensions);
    _ = c.SDL_Vulkan_GetInstanceExtensions(@ptrCast(self.window), &sdlExtensionCount, sdlExtensions.ptr);

    for (sdlExtensions) |extension| {
        std.debug.print("found extension: {s}\n", .{extension});
        requiredExtensions.append(extension) catch unreachable;
    }
    if (self.enableValidationLayers) {
        requiredExtensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME) catch unreachable;
    }

    requiredExtensions.append(c.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME) catch unreachable;

    return requiredExtensions;
}

fn getValidationLayers(self: *const Self) ArrayList([*c]const u8) {
    var validationLayers = ArrayList([*c]const u8).init(self.allocator);
    validationLayers.append("VK_LAYER_KHRONOS_validation") catch unreachable;
    return validationLayers;
}

fn getDeviceExtensions(self: *const Self) ArrayList([*c]const u8) {
    var deviceExtensions = ArrayList([*c]const u8).init(self.allocator);
    deviceExtensions.append(c.VK_KHR_SWAPCHAIN_EXTENSION_NAME) catch unreachable;
    return deviceExtensions;
}

fn checkValidationLayerSupport(validationLayers: ArrayList([*c]const u8)) bool {
    var layerCount: u32 = undefined;
    vkCheck(c.vkEnumerateInstanceLayerProperties(&layerCount, null));
    const availableLayers = std.heap.page_allocator.alloc(c.VkLayerProperties, layerCount) catch unreachable;
    defer std.heap.page_allocator.free(availableLayers);

    vkCheck(c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr));
    for (validationLayers.items) |layerName| {
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

fn pickPhysicalDevice(self: *Self, physicalDevices: []c.VkPhysicalDevice) void {
    var scores = ArrayList(u32).init(self.allocator);
    defer scores.deinit();

    for (physicalDevices) |physicalDevice| {
        if (!self.isDeviceSuitable(physicalDevice)) {
            continue;
        }
        scores.append(self.rateDeviceSuitability(physicalDevice)) catch unreachable;
    }

    var optimalIndex: u32 = 0;
    var optimalScore: u32 = 0;
    var i: u32 = 0;
    for (scores.items) |score| {
        if (score > optimalScore) {
            optimalScore = score;
            optimalIndex = i;
        }
        i += 1;
    }

    if (optimalScore == 0) {
        @panic("Failed to find suitable Vulkan gpu");
    }

    self.physicalDevice = physicalDevices[optimalIndex];
}

fn isDeviceSuitable(self: *const Self, potentialPhysicalDevice: c.VkPhysicalDevice) bool {
    const indices = QueueFamilyIndices.findQueueFamilies(self.allocator, potentialPhysicalDevice, self.surface);

    var deviceProperties: c.VkPhysicalDeviceProperties = .{};
    var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
    c.vkGetPhysicalDeviceProperties(potentialPhysicalDevice, &deviceProperties);
    c.vkGetPhysicalDeviceFeatures(potentialPhysicalDevice, &deviceFeatures);

    const hasGeometryShader = deviceFeatures.geometryShader == c.VK_TRUE;
    const extensionsSupported = self.checkDeviceExtensionSupport(potentialPhysicalDevice);

    var swapChainAdequate = false;
    if (extensionsSupported) {
        const swapChainSupport = SwapChainSupportDetails.querySwapChainSupport(potentialPhysicalDevice, self.surface);
        defer swapChainSupport.deinit();

        swapChainAdequate = swapChainSupport.formats != null and swapChainSupport.presentModes != null;
    }

    return hasGeometryShader and indices.isComplete() and extensionsSupported and swapChainAdequate;
}

fn checkDeviceExtensionSupport(self: *const Self, physicalDevice: c.VkPhysicalDevice) bool {
    var deviceExtensions = ArrayList([*c]const u8).init(self.allocator);
    defer deviceExtensions.deinit();

    deviceExtensions.append(c.VK_KHR_SWAPCHAIN_EXTENSION_NAME) catch unreachable;

    var extensionCount: u32 = 0;
    vkCheck(c.vkEnumerateDeviceExtensionProperties(physicalDevice, null, &extensionCount, null));

    const availableExtensions = self.allocator.alloc(c.VkExtensionProperties, extensionCount) catch unreachable;
    defer self.allocator.free(availableExtensions);
    vkCheck(c.vkEnumerateDeviceExtensionProperties(physicalDevice, null, &extensionCount, availableExtensions.ptr));

    for (availableExtensions) |extension| {
        const extensionName = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&extension.extensionName)), 0);

        for (0..deviceExtensions.items.len) |i| {
            const requiredExtensionName = std.mem.sliceTo(deviceExtensions.items[i], 0);
            if (std.mem.eql(u8, extensionName, requiredExtensionName)) {
                _ = deviceExtensions.orderedRemove(i);
                break;
            }
        }
    }

    return deviceExtensions.items.len == 0;
}

fn rateDeviceSuitability(self: *const Self, potentialPhysicalDevice: c.VkPhysicalDevice) u32 {
    var deviceProperties: c.VkPhysicalDeviceProperties = .{};
    var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
    c.vkGetPhysicalDeviceProperties(potentialPhysicalDevice, &deviceProperties);
    c.vkGetPhysicalDeviceFeatures(potentialPhysicalDevice, &deviceFeatures);

    var score: u32 = 0;

    if (deviceFeatures.geometryShader == 0) {
        return 0;
    }

    const indices = QueueFamilyIndices.findQueueFamilies(self.allocator, potentialPhysicalDevice, self.surface);
    if (indices.graphicsFamily == null) {
        std.debug.print("null graphics family\n", .{});
        return 0;
    }

    if (deviceProperties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
        score += 1000;
    }

    score += deviceProperties.limits.maxImageDimension2D;
    return score;
}

fn getVulkanInstanceFunc(self: *Self, comptime Fn: type, name: [*c]const u8) Fn {
    const getProcAddr: c.PFN_vkGetInstanceProcAddr = @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
    if (getProcAddr) |getProcAddrFunc| {
        return @ptrCast(getProcAddrFunc(self.instance, name));
    }

    @panic("SDL_Vulkan_GetVkGetInstanceProcAddr returned null");
}

fn checkSdl(res: c_int) void {
    if (res != 0) {
        std.log.err("Detected SDL error: {s}", .{c.SDL_GetError()});
        @panic("SDL error");
    }
}

fn checkSdlBool(res: c.SDL_bool) void {
    if (res != c.SDL_TRUE) {
        std.log.err("Detected SDL error: {s}", .{c.SDL_GetError()});
        @panic("SDL error");
    }
}

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32,
    presentFamily: ?u32,

    fn findQueueFamilies(allocator: Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) QueueFamilyIndices {
        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

        const queueFamilies = allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch unreachable;
        defer allocator.free(queueFamilies);

        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

        var indices: QueueFamilyIndices = .{ .graphicsFamily = null, .presentFamily = null };

        var i: u32 = 0;
        for (queueFamilies) |queueFamily| {
            if (queueFamily.queueCount & c.VK_QUEUE_GRAPHICS_BIT != 0 and indices.graphicsFamily == null) {
                indices.graphicsFamily = i;
            }

            if (indices.presentFamily == null) {
                var presentSupport: c.VkBool32 = @as(c.VkBool32, 0);
                vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &presentSupport));
                if (presentSupport == c.VK_TRUE) {
                    indices.presentFamily = i;
                }
            }

            i += 1;
        }

        return indices;
    }

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR = .{},
    formats: ?[]c.VkSurfaceFormatKHR = null,
    presentModes: ?[]c.VkPresentModeKHR = null,
    allocator: Allocator,

    /// Must call `deinit()` to free the allocations.
    fn querySwapChainSupport(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) SwapChainSupportDetails {
        const allocator = std.heap.page_allocator;

        var details: SwapChainSupportDetails = .{ .allocator = allocator };

        vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities));

        var formatCount: u32 = undefined;
        vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null));

        if (formatCount != 0) {
            details.formats = details.allocator.alloc(c.VkSurfaceFormatKHR, formatCount) catch unreachable;
            vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, details.formats.?.ptr));
        }

        var presentModeCount: u32 = undefined;
        vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null));

        if (presentModeCount != 0) {
            details.presentModes = details.allocator.alloc(c.VkPresentModeKHR, presentModeCount) catch unreachable;
            vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, details.presentModes.?.ptr));
        }

        return details;
    }

    fn deinit(self: SwapChainSupportDetails) void {
        if (self.formats != null) {
            self.allocator.free(self.formats.?);
        }
        if (self.presentModes != null) {
            self.allocator.free(self.presentModes.?);
        }
    }
};
