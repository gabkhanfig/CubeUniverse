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
// https://vulkan-tutorial.com/en/Drawing_a_triangle/Setup/Validation_layers
// https://github.com/spanzeri/vkguide-zig/blob/main/src/vulkan_init.zig

var loadedEngine: ?*VulkanEngine = null;

pub const VulkanEngine = struct {
    const Self = @This();

    isInitialized: bool,
    frameNumber: i32,
    stopRendering: bool,
    windowExtent: c.VkExtent2D,
    window: *c.SDL_Window,

    instance: c.VkInstance,

    enableValidationLayers: bool,

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

        loadedEngine = vkEngine;
    }

    pub fn deinit() void {
        if (loadedEngine == null) {
            std.debug.print("tried to deinit VulkanEngine that was not initialized", .{});
            return;
        }

        const vkEngine = loadedEngine.?;

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
        std.debug.print("created vulkan instance\n", .{});
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
};
