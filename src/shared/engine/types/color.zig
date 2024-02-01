const std = @import("std");
const expect = std.testing.expect;

pub const RgbColor = extern struct {
    const Self = @This();

    r: u8,
    g: u8,
    b: u8,
};

/// 2-byte, 3-bit component RGBA color structure for use in the NTree.
/// Compressed to 2 bytes to allow aggressive memory usage optimizations within
/// each layer of the NTree. Uses bitmasks to allow usage on the GPU using the same
/// API. On the CPU side, uses zig's u3 integer type per component (0 - 7 range).
/// The upper 4 bits are unused, and the programmer is free to use them for whatever.
///
/// # Zero value
///
/// If the member variable `mask` is just 0, it can be considered as "empty",
/// because it is RGBA(0, 0, 0, 0);
pub const TreeNodeColor = extern struct {
    const Self = @This();
    pub const RED_BITMASK = 0b111;
    pub const GREEN_BITMASK = 0b111000;
    pub const BLUE_BITMASK = 0b111000000;
    pub const ALPHA_BITMASK = 0b111000000000;
    pub const GREEN_SHIFT = 3;
    pub const BLUE_SHIFT = 6;
    pub const ALPHA_SHIFT = 9;
    pub const EXTRACT_MASK = 0b111;

    mask: u16,

    pub fn init(red: u3, green: u3, blue: u3, alpha: u3) Self {
        const castR: u16 = @intCast(red);
        const castG: u16 = @intCast(green);
        const castB: u16 = @intCast(blue);
        const castA: u16 = @intCast(alpha);

        return Self{
            .mask = castR | @shlExact(castG, GREEN_SHIFT) | @shlExact(castB, BLUE_SHIFT) | @shlExact(castA, ALPHA_SHIFT),
        };
    }

    pub fn r(self: Self) u3 {
        return @intCast(self.mask & EXTRACT_MASK);
    }

    pub fn g(self: Self) u3 {
        const greenMask = self.mask & GREEN_BITMASK;
        return @intCast(@shrExact(greenMask, GREEN_SHIFT) & EXTRACT_MASK);
    }

    pub fn b(self: Self) u3 {
        const blueMask = self.mask & BLUE_BITMASK;
        return @intCast(@shrExact(blueMask, BLUE_SHIFT) & EXTRACT_MASK);
    }

    pub fn a(self: Self) u3 {
        const alphaMask = self.mask & ALPHA_BITMASK;
        return @intCast(@shrExact(alphaMask, ALPHA_SHIFT) & EXTRACT_MASK);
    }

    pub fn setR(self: *Self, red: u3) void {
        const castR: u16 = @intCast(red);
        self.mask = (self.mask & ~@as(u16, RED_BITMASK)) | castR;
    }

    pub fn setG(self: *Self, green: u3) void {
        const castG: u16 = @intCast(green);
        self.mask = (self.mask & ~@as(u16, GREEN_BITMASK)) | @shlExact(castG, GREEN_SHIFT);
    }

    pub fn setB(self: *Self, blue: u3) void {
        const castB: u16 = @intCast(blue);
        self.mask = (self.mask & ~@as(u16, BLUE_BITMASK)) | @shlExact(castB, BLUE_SHIFT);
    }

    pub fn setA(self: *Self, alpha: u3) void {
        const castA: u16 = @intCast(alpha);
        self.mask = (self.mask & ~@as(u16, ALPHA_BITMASK)) | @shlExact(castA, ALPHA_SHIFT);
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

test "TreeNodeColor 7, 7, 7, 7" {
    const c = TreeNodeColor.init(7, 7, 7, 7);
    try expect(c.r() == 7);
    try expect(c.g() == 7);
    try expect(c.b() == 7);
    try expect(c.a() == 7);
}

test "TreeNodeColor mixed values" {
    const c = TreeNodeColor.init(1, 3, 7, 5);
    try expect(c.r() == 1);
    try expect(c.g() == 3);
    try expect(c.b() == 7);
    try expect(c.a() == 5);
}

test "TreeNodeColour set red component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setR(7);
    try expect(c.r() == 7);
    try expect(c.g() == 0);
    try expect(c.b() == 0);
    try expect(c.a() == 0);
}

test "TreeNodeColour set red component to 0" {
    var c = TreeNodeColor.init(7, 7, 7, 7);
    c.setR(0);
    try expect(c.r() == 0);
    try expect(c.g() == 7);
    try expect(c.b() == 7);
    try expect(c.a() == 7);
}

test "TreeNodeColour set green component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setG(7);
    try expect(c.r() == 0);
    try expect(c.g() == 7);
    try expect(c.b() == 0);
    try expect(c.a() == 0);
}

test "TreeNodeColour set green component to 0" {
    var c = TreeNodeColor.init(7, 7, 7, 7);
    c.setG(0);
    try expect(c.r() == 7);
    try expect(c.g() == 0);
    try expect(c.b() == 7);
    try expect(c.a() == 7);
}

test "TreeNodeColour set blue component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setB(7);
    try expect(c.r() == 0);
    try expect(c.g() == 0);
    try expect(c.b() == 7);
    try expect(c.a() == 0);
}

test "TreeNodeColour set blue component to 0" {
    var c = TreeNodeColor.init(7, 7, 7, 7);
    c.setB(0);
    try expect(c.r() == 7);
    try expect(c.g() == 7);
    try expect(c.b() == 0);
    try expect(c.a() == 7);
}

test "TreeNodeColour set alpha component from 0" {
    var c = TreeNodeColor.init(0, 0, 0, 0);
    c.setA(7);
    try expect(c.r() == 0);
    try expect(c.g() == 0);
    try expect(c.b() == 0);
    try expect(c.a() == 7);
}

test "TreeNodeColour set alpha component to 0" {
    var c = TreeNodeColor.init(7, 7, 7, 7);
    c.setA(0);
    try expect(c.r() == 7);
    try expect(c.g() == 7);
    try expect(c.b() == 7);
    try expect(c.a() == 0);
}
