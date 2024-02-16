const std = @import("std");
const c = @import("../../../clibs.zig");
const vk_types = @import("vk_types.zig");
const vkCheck = vk_types.vkCheck;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// https://github.com/AndreVallestero/sdl-vulkan-tutorial/blob/master/hello-triangle/main.cpp
// https://vkguide.dev/docs/new_chapter_1/vulkan_init_code/
// https://vulkan-tutorial.com/en/Drawing_a_triangle/Presentation/Swap_chain
// https://github.com/spanzeri/vkguide-zig/blob/main/src/vulkan_init.zig

var loadedEngine: ?*VulkanEngine = null;

pub const VulkanEngine = struct {
    const Self = @This();

    isInitialized: bool,
    frameNumber: i32,
    stopRendering: bool,
    windowExtent: c.VkExtent2D,
    window: *c.SDL_Window,

    enableValidationLayers: bool,

    instance: c.VkInstance,
    debugMessenger: c.VkDebugUtilsMessengerEXT,
    chosenGpu: c.VkPhysicalDevice,
    device: c.VkDevice,
    graphicsQueue: c.VkQueue,
    surface: c.VkSurfaceKHR,
    presentQueue: c.VkQueue,
    swapChain: c.VkSwapchainKHR,

    pub fn get() *VulkanEngine {
        if (loadedEngine == null) {
            @panic("Global Vulkan Engine instance was not initialized");
        }
        return loadedEngine.?;
    }

    pub fn init() void {
        assert(loadedEngine == null);

        _ = c.SDL_Init(c.SDL_INIT_VIDEO);

        const windowFlags = @as(c.SDL_WindowFlags, c.SDL_WINDOW_VULKAN);

        var window: *c.SDL_Window = undefined;
        if (c.SDL_CreateWindow("Vulkan Engine", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 1920, 1080, windowFlags)) |w| {
            window = w;
        } else {
            @panic("Failed to create SDL window");
        }

        const vkEngine = std.heap.page_allocator.create(VulkanEngine) catch unreachable;

        vkEngine.isInitialized = true;
        vkEngine.frameNumber = 0;
        vkEngine.stopRendering = false;
        vkEngine.windowExtent = .{ .width = 1920, .height = 1080 };
        vkEngine.window = window;
        vkEngine.enableValidationLayers = true;

        vkEngine.createInstance();
        vkEngine.setupDebugMessenger();
        vkEngine.createSurface();
        vkEngine.selectPhysicalDevice();
        vkEngine.createLogicalDevice();
        vkEngine.createSwapChain();

        loadedEngine = vkEngine;
    }

    pub fn deinit() void {
        if (loadedEngine == null) {
            std.debug.print("tried to deinit VulkanEngine that was not initialized", .{});
            return;
        }

        const vkEngine = loadedEngine.?;

        c.vkDestroySwapchainKHR(vkEngine.device, vkEngine.swapChain, null);
        c.vkDestroyDevice(vkEngine.device, null);
        vkEngine.destroyDebugMessenger();
        c.vkDestroySurfaceKHR(vkEngine.instance, vkEngine.surface, null);
        c.vkDestroyInstance(vkEngine.instance, null);
        c.SDL_DestroyWindow(loadedEngine.?.window);
        std.heap.page_allocator.destroy(vkEngine);
        loadedEngine = null;
    }

    pub fn draw(_: *Self) void {}

    pub fn run(self: *Self) void {
        var e: c.SDL_Event = .{};
        var bQuit = false;

        // main loop
        while (!bQuit) {
            // handle events on queue
            while (c.SDL_PollEvent(&e) != 0) {
                if (e.type == c.SDL_QUIT) {
                    bQuit = true;
                }

                if (e.type == c.SDL_WINDOWEVENT) {
                    if (e.window.event == c.SDL_WINDOWEVENT_MINIMIZED) {
                        self.stopRendering = true;
                    }
                    if (e.window.event == c.SDL_WINDOWEVENT_RESTORED) {
                        self.stopRendering = false;
                    }
                }
            }

            if (self.stopRendering) {
                // throttle to avoid constant spinning
                std.time.sleep(100 * std.time.ns_per_ms);
                continue;
            }

            self.draw();
        }
    }

    fn createInstance(self: *Self) void {
        var appInfo: c.VkApplicationInfo = .{};
        appInfo.sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "Hello Triangle";
        appInfo.applicationVersion = c.VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "No Engine";
        appInfo.engineVersion = c.VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion = c.VK_API_VERSION_1_3;

        const requiredExtensions = self.getRequiredExtensions();
        defer requiredExtensions.deinit();

        const validationLayers = getValidationLayers();
        defer validationLayers.deinit();

        if (self.enableValidationLayers and !checkValidationLayerSupport(validationLayers)) {
            @panic("validation layers requested, but not available!");
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
        std.debug.print("Created vulkan instance\n", .{});
    }

    fn checkValidationLayerSupport(validationLayers: std.ArrayList([*c]const u8)) bool {
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

    fn getValidationLayers() ArrayList([*c]const u8) {
        var validationLayers = std.ArrayList([*c]const u8).init(std.heap.page_allocator);
        validationLayers.append("VK_LAYER_KHRONOS_validation") catch unreachable;
        return validationLayers;
    }

    /// Does nothing if `enableValidationLayers` is false.
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

        @panic("setupDebugMessenger failed??");
    }

    /// Does nothing if `enableValidationLayers` is false.
    fn destroyDebugMessenger(self: *Self) void {
        if (!self.enableValidationLayers) return;

        const destroyFnOpt = self.getVulkanInstanceFunc(c.PFN_vkDestroyDebugUtilsMessengerEXT, "vkDestroyDebugUtilsMessengerEXT");
        if (destroyFnOpt) |destroyFn| {
            destroyFn(self.instance, self.debugMessenger, null);
            return;
        }

        @panic("Failed to destroy vulkan debug messenger");
    }

    fn getVulkanInstanceFunc(self: *Self, comptime Fn: type, name: [*c]const u8) Fn {
        const getProcAddr: c.PFN_vkGetInstanceProcAddr = @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
        if (getProcAddr) |getProcAddrFunc| {
            return @ptrCast(getProcAddrFunc(self.instance, name));
        }

        @panic("SDL_Vulkan_GetVkGetInstanceProcAddr returned null");
    }

    fn getRequiredExtensions(self: *Self) ArrayList([*c]const u8) {
        var requiredExtensions = std.ArrayList([*c]const u8).init(std.heap.page_allocator);

        var sdlExtensionCount: u32 = 0;
        _ = c.SDL_Vulkan_GetInstanceExtensions(@ptrCast(self.window), &sdlExtensionCount, null);
        std.debug.print("\nextension count: {}\n", .{sdlExtensionCount});
        const sdlExtensions = std.heap.page_allocator.alloc([*c]const u8, sdlExtensionCount) catch unreachable;
        defer std.heap.page_allocator.free(sdlExtensions);
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

    fn selectPhysicalDevice(self: *Self) void {
        var physicalDeviceCount: u32 = undefined;
        vkCheck(c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, null));
        if (physicalDeviceCount == 0) {
            @panic("Failed to find GPUs with Vulkan support!");
        }

        const physicalDevices = std.heap.page_allocator.alloc(c.VkPhysicalDevice, physicalDeviceCount) catch unreachable;
        defer std.heap.page_allocator.free(physicalDevices);

        vkCheck(c.vkEnumeratePhysicalDevices(self.instance, &physicalDeviceCount, physicalDevices.ptr));
        self.chosenGpu = pickPhysicalDevice(physicalDevices, self.surface);
    }

    fn pickPhysicalDevice(physicalDevices: []c.VkPhysicalDevice, surface: c.VkSurfaceKHR) c.VkPhysicalDevice {
        var scores = ArrayList(u32).init(std.heap.page_allocator);
        defer scores.deinit();

        for (physicalDevices) |physicalDevice| {
            if (!isDeviceSuitable(physicalDevice, surface)) {
                continue;
            }
            scores.append(rateDeviceSuitability(physicalDevice, surface)) catch unreachable;
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

        return physicalDevices[optimalIndex];
    }

    fn isDeviceSuitable(physicalDevice: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) bool {
        const indices = QueueFamilyIndices.findQueueFamilies(physicalDevice, surface);

        var deviceProperties: c.VkPhysicalDeviceProperties = .{};
        var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
        c.vkGetPhysicalDeviceProperties(physicalDevice, &deviceProperties);
        c.vkGetPhysicalDeviceFeatures(physicalDevice, &deviceFeatures);

        var deviceExtensions = getDeviceExtensions();
        defer deviceExtensions.deinit();

        const hasGeomtryShader = deviceFeatures.geometryShader == c.VK_TRUE;
        const extensionsSupported = checkDeviceExtensionSupport(physicalDevice);

        var swapChainAdequate = false;
        if (extensionsSupported) {
            const swapChainSupport = SwapChainSupportDetails.querySwapChainSupport(physicalDevice, surface);
            defer swapChainSupport.deinit();

            swapChainAdequate = swapChainSupport.formats != null and swapChainSupport.presentModes != null;
        }

        return hasGeomtryShader and indices.isComplete() and extensionsSupported and swapChainAdequate;
    }

    fn rateDeviceSuitability(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) u32 {
        var deviceProperties: c.VkPhysicalDeviceProperties = .{};
        var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
        c.vkGetPhysicalDeviceProperties(device, &deviceProperties);
        c.vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

        var score: u32 = 0;

        if (deviceFeatures.geometryShader == 0) {
            return 0;
        }

        const indices = QueueFamilyIndices.findQueueFamilies(device, surface);
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

    fn createLogicalDevice(self: *Self) void {
        var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa = generalPurposeAllocator.allocator();

        const indices = QueueFamilyIndices.findQueueFamilies(self.chosenGpu, self.surface);

        // https://vulkan-tutorial.com/Drawing_a_triangle/Setup/Logical_device_and_queues#:~:text=queueCreateInfo.pQueuePriorities%20%3D%20%26queuePriority%3B-,Specifying%20used%20device%20features,-The%20next%20information
        const deviceFeatures: c.VkPhysicalDeviceFeatures = .{};

        var uniqueQueueFamilies = ArrayList(u32).init(gpa);
        defer uniqueQueueFamilies.deinit();

        uniqueQueueFamilies.append(indices.graphicsFamily.?) catch unreachable;
        // for more queues, this should iterate through the ArrayList, seeing if it contains the value.
        // alternatively, a set would work. Maybe custom implemention or eventual zig std implementation?
        if (indices.presentFamily.? == indices.graphicsFamily.?) {
            uniqueQueueFamilies.append(indices.presentFamily.?) catch unreachable;
        }

        var queueCreateInfos = ArrayList(c.VkDeviceQueueCreateInfo).init(gpa);
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

        const validationLayers = getValidationLayers();
        defer validationLayers.deinit();

        const deviceExtensions = getDeviceExtensions();
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

        vkCheck(c.vkCreateDevice(self.chosenGpu, &createInfo, null, &self.device));
        c.vkGetDeviceQueue(self.device, indices.graphicsFamily.?, 0, &self.graphicsQueue);
    }

    fn createSurface(self: *Self) void {
        const res = c.SDL_Vulkan_CreateSurface(self.window, self.instance, &self.surface);
        if (res != @as(c_uint, c.SDL_TRUE)) {
            @panic("Failed to create window surface!");
        }
    }

    fn createSwapChain(self: *Self) void {
        const swapChainSupport = SwapChainSupportDetails.querySwapChainSupport(self.chosenGpu, self.surface);

        const surfaceFormat = chooseSwapSurfaceFormat(swapChainSupport.formats.?);
        const presentMode = chooseSwapPresentMode(swapChainSupport.presentModes.?);
        const extent = chooseSwapExtent(swapChainSupport.capabilities, self.window);

        var imageCount = swapChainSupport.capabilities.minImageCount + 1;
        if (swapChainSupport.capabilities.maxImageCount > 0 and imageCount > swapChainSupport.capabilities.maxImageCount) {
            imageCount = swapChainSupport.capabilities.maxImageCount;
        }

        const indices = QueueFamilyIndices.findQueueFamilies(self.chosenGpu, self.surface);

        var createInfo: c.VkSwapchainCreateInfoKHR = .{};
        createInfo.sType = @intCast(c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
        createInfo.surface = self.surface;
        createInfo.minImageCount = imageCount;
        createInfo.imageFormat = surfaceFormat.format;
        createInfo.imageColorSpace = surfaceFormat.colorSpace;
        createInfo.imageExtent = extent;
        createInfo.imageArrayLayers = 1;
        createInfo.imageUsage = @intCast(c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);

        const queueFamilyIndices: []const u32 = &.{ indices.graphicsFamily.?, indices.presentFamily.? };

        if (indices.graphicsFamily.? != indices.presentFamily.?) {
            createInfo.imageSharingMode = @intCast(c.VK_SHARING_MODE_CONCURRENT);
            createInfo.queueFamilyIndexCount = 2;
            createInfo.pQueueFamilyIndices = queueFamilyIndices.ptr;
        } else {
            createInfo.imageSharingMode = @intCast(c.VK_SHARING_MODE_EXCLUSIVE);
            createInfo.queueFamilyIndexCount = 0; // optional
            createInfo.pQueueFamilyIndices = null; // optionaal
        }

        createInfo.preTransform = swapChainSupport.capabilities.currentTransform;
        createInfo.compositeAlpha = @intCast(c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR);

        createInfo.presentMode = presentMode;
        createInfo.clipped = c.VK_TRUE;

        createInfo.oldSwapchain = @ptrCast(@alignCast(c.VK_NULL_HANDLE));

        vkCheck(c.vkCreateSwapchainKHR(self.device, &createInfo, null, &self.swapChain));
    }
};

const QueueFamilyIndices = struct {
    const Self = @This();

    graphicsFamily: ?u32,
    presentFamily: ?u32,

    fn findQueueFamilies(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) Self {
        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

        const allocator = std.heap.page_allocator;
        const queueFamilies = allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch unreachable;
        defer allocator.free(queueFamilies);

        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

        var indices: Self = .{ .graphicsFamily = null, .presentFamily = null };

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

    fn isComplete(self: Self) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

/// Required physical device extensions as unique entries. Currently  just swapchain.
fn getDeviceExtensions() ArrayList([*:0]const u8) {
    //var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    //const gpa = generalPurposeAllocator.allocator();
    const allocator = std.heap.page_allocator;

    var deviceExtensions = ArrayList([*:0]const u8).init(allocator);
    deviceExtensions.append(c.VK_KHR_SWAPCHAIN_EXTENSION_NAME) catch unreachable;
    return deviceExtensions;
}

fn checkDeviceExtensionSupport(device: c.VkPhysicalDevice) bool {
    var extensionCount: u32 = 0;
    vkCheck(c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null));

    const allocator = std.heap.page_allocator;
    //const sdlExtensions = std.heap.page_allocator.alloc([*c]const u8, sdlExtensionCount) catch unreachable;
    //defer std.heap.page_allocator.free(sdlExtensions);
    const availableExtensions = allocator.alloc(c.VkExtensionProperties, extensionCount) catch unreachable;
    defer allocator.free(availableExtensions);
    vkCheck(c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr));

    var deviceExtensions = getDeviceExtensions();
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

fn chooseSwapSurfaceFormat(availableFormats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    for (availableFormats) |availableFormat| {
        if (availableFormat.format == @as(c_uint, c.VK_FORMAT_B8G8R8A8_SRGB) and availableFormat.colorSpace == @as(c_uint, c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)) {
            return availableFormat;
        }
    }

    return availableFormats[0];
}

fn chooseSwapPresentMode(availablePresentModes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    for (availablePresentModes) |availablePresentMode| {
        if (availablePresentMode == @as(c_uint, c.VK_PRESENT_MODE_MAILBOX_KHR)) {
            return availablePresentMode;
        }
    }

    return c.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapExtent(capabilities: c.VkSurfaceCapabilitiesKHR, window: *c.SDL_Window) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    }

    var width: i32 = undefined;
    var height: i32 = undefined;
    c.SDL_GetWindowSize(window, &width, &height);

    var actualExtent = c.VkExtent2D{
        .width = @intCast(width),
        .height = @intCast(height),
    };

    actualExtent.width = std.math.clamp(actualExtent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
    actualExtent.height = std.math.clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);

    return actualExtent;
}
