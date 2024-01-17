const std = @import("std");
const c = @import("../../../clibs.zig");
const vk = @cImport({
    @cInclude("vulkan/vk_enum_string_helper.h");
    @cInclude("vk_mem_alloc.h");
});

pub fn vkCheck(vkResult: c.VkResult) void {
    if (vkResult != 0) {
        const vkError: [*:0]const u8 = vk.string_VkResult(vkResult);
        const res = std.fmt.allocPrint(std.heap.page_allocator, "Detected Vulkan error: {s}\n", .{vkError});
        if (res) |message| {
            @panic(message);
        } else |_| {
            @panic("Detected Vulkan Error. Failed to print it.");
        }
    }
}
