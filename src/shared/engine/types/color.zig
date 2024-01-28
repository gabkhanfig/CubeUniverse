const std = @import("std");
const expect = std.testing.expect;

pub const RgbColor = extern struct {
    const Self = @This();

    r: u8,
    g: u8,
    b: u8,
};

/// 2-byte, 4-bit component RGBA color structure for use in the NTree.
/// Compressed to 2 bytes to allow aggressive memory usage optimizations within
/// each layer of the NTree. Uses bitmasks to allow usage on the GPU using the same
/// API. On the CPU side, uses zig's u4 integer type per component (0 - 15 range).
pub const TreeNodeColor = extern struct {
    const Self = @This();
    pub const RED_BITMASK = 0b1111;
    pub const GREEN_BITMASK = 0b11110000;
    pub const BLUE_BITMASK = 0b111100000000;
    pub const ALPHA_BITMASK = 0b1111000000000000;

    mask: u16,

    pub fn init(red: u4, green: u4, blue: u4, alpha: u4) Self {
        const castR: u16 = @intCast(red);
        const castG: u16 = @intCast(green);
        const castB: u16 = @intCast(blue);
        const castA: u16 = @intCast(alpha);

        return Self{
            .mask = castR | @shlExact(castG, 4) | @shlExact(castB, 8) | @shlExact(castA, 12),
        };
    }

    pub fn r(self: Self) u4 {
        return @intCast(self.mask & 0b1111);
    }

    pub fn g(self: Self) u4 {
        const greenMask = self.mask & GREEN_BITMASK;
        return @intCast(@shrExact(greenMask, 4) & 0b1111);
    }

    pub fn b(self: Self) u4 {
        const blueMask = self.mask & BLUE_BITMASK;
        return @intCast(@shrExact(blueMask, 8) & 0b1111);
    }

    pub fn a(self: Self) u4 {
        const alphaMask = self.mask & ALPHA_BITMASK;
        return @intCast(@shrExact(alphaMask, 12) & 0b1111);
    }

    pub fn setR(self: *Self, red: u4) void {
        const castR: u16 = @intCast(red);
        self.mask = (self.mask & ~@as(u16, RED_BITMASK)) | castR;
    }

    pub fn setG(self: *Self, green: u4) void {
        const castG: u16 = @intCast(green);
        self.mask = (self.mask & ~@as(u16, GREEN_BITMASK)) | @shlExact(castG, 4);
    }

    pub fn setB(self: *Self, blue: u4) void {
        const castB: u16 = @intCast(blue);
        self.mask = (self.mask & ~@as(u16, BLUE_BITMASK)) | @shlExact(castB, 8);
    }

    pub fn setA(self: *Self, alpha: u4) void {
        const castA: u16 = @intCast(alpha);
        self.mask = (self.mask & ~@as(u16, ALPHA_BITMASK)) | @shlExact(castA, 12);
    }
};

// Tests

test "TreeNodeColor 0, 0, 0, 0" {
    const c = TreeNodeColor.init(0, 0, 0, 0);
    try expect(c.r() == 0);
    try expect(c.g() == 0);
    try expect(c.b() == 0);
    try expect(c.a() == 0);
}

test "TreeNodeColor 15, 15, 15, 15" {
    const c = TreeNodeColor.init(15, 15, 15, 15);
    try expect(c.r() == 15);
    try expect(c.g() == 15);
    try expect(c.b() == 15);
    try expect(c.a() == 15);
}

test "TreeNodeColor mixed values" {
    const c = TreeNodeColor.init(1, 3, 7, 12);
    try expect(c.r() == 1);
    try expect(c.g() == 3);
    try expect(c.b() == 7);
    try expect(c.a() == 12);
}

test "TreeNodeColour set red component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setR(15);
    try expect(c.r() == 15);
    try expect(c.g() == 0);
    try expect(c.b() == 0);
    try expect(c.a() == 0);
}

test "TreeNodeColour set red component to 0" {
    var c = TreeNodeColor.init(15, 15, 15, 15);
    c.setR(0);
    try expect(c.r() == 0);
    try expect(c.g() == 15);
    try expect(c.b() == 15);
    try expect(c.a() == 15);
}

test "TreeNodeColour set green component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setG(15);
    try expect(c.r() == 0);
    try expect(c.g() == 15);
    try expect(c.b() == 0);
    try expect(c.a() == 0);
}

test "TreeNodeColour set green component to 0" {
    var c = TreeNodeColor.init(15, 15, 15, 15);
    c.setG(0);
    try expect(c.r() == 15);
    try expect(c.g() == 0);
    try expect(c.b() == 15);
    try expect(c.a() == 15);
}

test "TreeNodeColour set blue component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setB(15);
    try expect(c.r() == 0);
    try expect(c.g() == 0);
    try expect(c.b() == 15);
    try expect(c.a() == 0);
}

test "TreeNodeColour set blue component to 0" {
    var c = TreeNodeColor.init(15, 15, 15, 15);
    c.setB(0);
    try expect(c.r() == 15);
    try expect(c.g() == 15);
    try expect(c.b() == 0);
    try expect(c.a() == 15);
}

test "TreeNodeColour set alpha component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setA(15);
    try expect(c.r() == 0);
    try expect(c.g() == 0);
    try expect(c.b() == 0);
    try expect(c.a() == 15);
}

test "TreeNodeColour set alpha component to 0" {
    var c = TreeNodeColor.init(15, 15, 15, 15);
    c.setA(0);
    try expect(c.r() == 15);
    try expect(c.g() == 15);
    try expect(c.b() == 15);
    try expect(c.a() == 0);
}
