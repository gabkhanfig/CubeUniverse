const std = @import("std");
const c = @import("../../../clibs.zig");
const vk_types = @import("vk_types.zig");
const vkCheck = vk_types.vkCheck;
const assert = std.debug.assert;
const sdl_vk = @cImport({
    @cInclude("SDL_vulkan.h");
});
const ArrayList = std.ArrayList;

// https://github.com/AndreVallestero/sdl-vulkan-tutorial/blob/master/hello-triangle/main.cpp
// https://vkguide.dev/docs/new_chapter_1/vulkan_init_code/
// https://vulkan-tutorial.com/en/Drawing_a_triangle/Setup/Physical_devices_and_queue_families
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
    surface: c.VkSurfaceKHR,

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
        vkEngine.windowExtent = .{ .width = 1700, .height = 900 };
        vkEngine.window = window;
        vkEngine.enableValidationLayers = true;

        vkEngine.createInstance();
        vkEngine.setupDebugMessenger();
        vkEngine.selectPhysicalDevice();

        loadedEngine = vkEngine;
    }

    pub fn deinit() void {
        if (loadedEngine == null) {
            std.debug.print("tried to deinit VulkanEngine that was not initialized", .{});
            return;
        }

        const vkEngine = loadedEngine.?;

        vkEngine.destroyDebugMessenger();
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

        var validationLayers = std.ArrayList([*c]const u8).init(std.heap.page_allocator);
        defer validationLayers.deinit();
        validationLayers.append("VK_LAYER_KHRONOS_validation") catch unreachable;

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
        const getProcAddr: c.PFN_vkGetInstanceProcAddr = @ptrCast(sdl_vk.SDL_Vulkan_GetVkGetInstanceProcAddr());
        if (getProcAddr) |getProcAddrFunc| {
            return @ptrCast(getProcAddrFunc(self.instance, name));
        }

        @panic("SDL_Vulkan_GetVkGetInstanceProcAddr returned null");
    }

    fn getRequiredExtensions(self: *Self) ArrayList([*c]const u8) {
        var requiredExtensions = std.ArrayList([*c]const u8).init(std.heap.page_allocator);

        var sdlExtensionCount: u32 = 0;
        _ = sdl_vk.SDL_Vulkan_GetInstanceExtensions(@ptrCast(self.window), &sdlExtensionCount, null);
        std.debug.print("\nextension count: {}\n", .{sdlExtensionCount});
        const sdlExtensions = std.heap.page_allocator.alloc([*c]const u8, sdlExtensionCount) catch unreachable;
        defer std.heap.page_allocator.free(sdlExtensions);
        _ = sdl_vk.SDL_Vulkan_GetInstanceExtensions(@ptrCast(self.window), &sdlExtensionCount, sdlExtensions.ptr);

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
        self.chosenGpu = pickPhysicalDevice(physicalDevices);
    }

    fn pickPhysicalDevice(physicalDevices: []c.VkPhysicalDevice) c.VkPhysicalDevice {
        var scores = ArrayList(u32).init(std.heap.page_allocator);
        defer scores.deinit();

        for (physicalDevices) |physicalDevice| {
            scores.append(rateDeviceSuitability(physicalDevice)) catch unreachable;
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

    fn rateDeviceSuitability(device: c.VkPhysicalDevice) u32 {
        var deviceProperties: c.VkPhysicalDeviceProperties = .{};
        var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};
        c.vkGetPhysicalDeviceProperties(device, &deviceProperties);
        c.vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

        var score: u32 = 0;

        if (deviceFeatures.geometryShader == 0) {
            return 0;
        }

        const indices = QueueFamilyIndices.findQueueFamilies(device);
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
};

const QueueFamilyIndices = struct {
    const Self = @This();

    graphicsFamily: ?u32,

    fn findQueueFamilies(device: c.VkPhysicalDevice) Self {
        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

        const allocator = std.heap.page_allocator;
        const queueFamilies = allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount) catch unreachable;
        defer allocator.free(queueFamilies);

        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

        var indices: Self = .{ .graphicsFamily = null };

        var i: u32 = 0;
        for (queueFamilies) |queueFamily| {
            if (queueFamily.queueCount & c.VK_QUEUE_GRAPHICS_BIT != 0) {
                indices.graphicsFamily = i;
                break;
            }
            i += 1;
        }

        return indices;
    }
};
