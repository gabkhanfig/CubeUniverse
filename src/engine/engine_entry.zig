const std = @import("std");
const assert = std.debug.assert;
const c = @import("clibs.zig");
const Application = @import("Application.zig");

fn errorCallback(err: c_int, description: [*]const u8) void {
    _ = err;
    std.debug.print("Glfw error: {s}", .{description});
}

export fn cubeUniverseEngineEntry() void {
    // const file = @embedFile("shared/engine/script/lua/test_return_number.lua");

    // const L = c.luaL_newstate().?;
    // _ = c.luaL_dostring(L, file);
    // c.lua_getglobal(L, "ReturnSomeNumber"); // push to top of lua stack
    // assert(c.lua_isfunction(L, -1));

    // _ = c.lua_pcall(L, 0, 1, 0);
    // const shouldBe10 = c.lua_tonumber(L, -1);
    // assert(shouldBe10 == 10.0);
    // const asInt: i32 = @intFromFloat(shouldBe10);
    // std.debug.print("lua number = {}\n", .{asInt});

    // var app = Application.init(std.heap.page_allocator);
    // defer app.deinit();

    // app.run();

    if (c.glfwInit() == c.GLFW_FALSE) {
        @panic("Failed to initialize glfw!");
    }

    const createWindow = c.glfwCreateWindow(640, 480, "Hello World", null, null);
    if (createWindow == null) {
        c.glfwTerminate();
        @panic("Failed to create glfw window");
    }

    c.glfwMakeContextCurrent(createWindow);

    _ = c.gladLoadGL();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glfwSwapBuffers(createWindow);
    }

    c.glfwTerminate();
}
