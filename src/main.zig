//! Basically nothing happens here.
//! This is simply a way for the exe to enter
//! the application, which is CubeUniverseEngine.dll.
//! The dll is required due to LuaJIT FFI.

// const std = @import("std");

// See engine_entry.zig
extern fn cubeUniverseEngineEntry() void;

pub fn main() !void {
    cubeUniverseEngineEntry();
}
