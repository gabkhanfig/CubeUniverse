const std = @import("std");
const c = @import("clibs.zig");
//const VulkanEngine = @import("shared/engine/vulkan/vk_engine.zig").VulkanEngine;
const VulkanEngine = @import("shared/engine/vulkan/VulkanEngine.zig");
//const NTree = @import("shared/world/NTree.zig");
const tree_layer_indices = @import("shared/world/n_tree/tree_layer_indices.zig");
const TreeLayerIndices = tree_layer_indices.TreeLayerIndices;
const Chunk = @import("shared/world/chunk/Chunk.zig");
const LoadedChunksHashMap = @import("shared/world/n_tree/LoadedChunksHashMap.zig");
const world_transform = @import("shared/world/world_transform.zig");
const BlockPosition = world_transform.BlockPosition;

const luajit = @import("shared/engine/script/lua/luajit.zig");

const Application = @import("shared/Application.zig");

const assert = std.debug.assert;

//extern fn luaL_newstate() ?*c.lua_State;
// extern fn _luaL_openlibs(?*c.lua_State) void;
// extern fn _luaL_dofile(?*c.lua_State, [*c]const u8) c_int;

pub fn main() !void {
    // var app = Application.init(std.heap.page_allocator);
    // defer app.deinit();

    // app.run();

    const file = @embedFile("shared/engine/script/lua/test_return_number.lua");

    const L = c.luaL_newstate().?;
    _ = c.luaL_dostring(L, file);
    c.lua_getglobal(L, "ReturnSomeNumber"); // push to top of lua stack
    assert(c.lua_isfunction(L, -1));

    _ = c.lua_pcall(L, 0, 1, 0);
    const shouldBe10 = c.lua_tonumber(L, -1);
    assert(shouldBe10 == 10.0);
    const asInt: i32 = @intFromFloat(shouldBe10);
    std.debug.print("lua number = {}\n", .{asInt});

    // const num: u32 = @intCast(c.LUAJIT_MODE_ON);
    // std.debug.print("erm {}\n", .{num});

}
