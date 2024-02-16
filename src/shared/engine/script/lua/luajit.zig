const std = @import("std");
//const c = @import("../../../../clibs.zig");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("lauxlib.h");
    @cInclude("luajit.h");
});

const lua_State = c.lua_State;

// Tests arent working for some reason??
// Probably some weird linking stuff

// test "Call lua function from zig" {
//     //const file = @embedFile("test_return_number.lua");

//     const L = c.luaL_newstate().?;
//     c.lua_close(L);
//     // _ = c.luaL_dostring(L, file);
//     // c.lua_getglobal(L, "ReturnSomeNumber"); // push to top of lua stack
//     // try expect(c.lua_isfunction(L, -1));

//     // _ = c.lua_pcall(L, 0, 1, 0);
//     // const shouldBe10 = c.lua_tonumber(L, -1);
//     // try expect(shouldBe10 == 10.0);
// }
