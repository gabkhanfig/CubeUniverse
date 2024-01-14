const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

pub const BlockLight = struct {
    const Self = @This();
    pub const RED_BITMASK = 0b11111;
    pub const GREEN_BITMASK = 0b1111100000;
    pub const BLUE_BITMASK = 0b111110000000000;
    pub const MAX_LIGHT_LEVEL = 31;

    /// Mask representing the RGB light colours ranging from `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusively.
    /// Doesn't use custom bitwidth integers for parity with GPU shaders
    mask: u16,

    /// Create a new `BlockLight` with RGB components.
    /// Asserts that `inR`, `inG`, and `inB` are in the range `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn init(inR: u8, inG: u8, inB: u8) Self {
        assert(inR <= MAX_LIGHT_LEVEL);
        assert(inG <= MAX_LIGHT_LEVEL);
        assert(inB <= MAX_LIGHT_LEVEL);

        const castR: u16 = @intCast(inR);
        const castG: u16 = @intCast(inG);
        const castB: u16 = @intCast(inB);

        return Self{
            .mask = castR | @shlExact(castG, 5) | @shlExact(castB, 10),
        };
    }

    /// Get the red light component value. Will be in the range of `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn r(self: Self) u8 {
        return @intCast(self.mask & RED_BITMASK);
    }

    /// Get the green light component value. Will be in the range of `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn g(self: Self) u8 {
        const greenMask = self.mask & GREEN_BITMASK;
        return @intCast(@shrExact(greenMask, 5));
    }

    /// Get the blue light component value. Will be in the range of `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn b(self: Self) u8 {
        const blueMask = self.mask & BLUE_BITMASK;
        return @intCast(@shrExact(blueMask, 10));
    }

    /// Set the red component of this `BlockLight`, without modifying the green or blue channels.
    /// Is more efficient than calling `init()` to only change the red component.
    /// Asserts that `inR` is in the range `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn setR(self: *Self, inR: u8) void {
        assert(inR <= MAX_LIGHT_LEVEL);
        const castR: u16 = @intCast(inR);
        self.mask = (self.mask & ~@as(u16, RED_BITMASK)) | castR;
    }

    /// Set the green component of this `BlockLight`, without modifying the red or blue channels.
    /// Is more efficient than calling `init()` to only change the green component.
    /// Asserts that `inG` is in the range `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn setG(self: *Self, inG: u8) void {
        assert(inG <= MAX_LIGHT_LEVEL);
        const castG: u16 = @intCast(inG);
        self.mask = (self.mask & ~@as(u16, GREEN_BITMASK)) | @shlExact(castG, 5);
    }

    /// Set the blue component of this `BlockLight`, without modifying the red or green channels.
    /// Is more efficient than calling `init()` to only change the blue component.
    /// Asserts that `inB` is in the range `0 -> BlockLight.MAX_LIGHT_LEVEL` inclusive.
    pub fn setB(self: *Self, inB: u8) void {
        assert(inB <= MAX_LIGHT_LEVEL);
        const castB: u16 = @intCast(inB);
        self.mask = (self.mask & ~@as(u16, BLUE_BITMASK)) | @shlExact(castB, 10);
    }
};

// Tests

test "BlockLight 0, 0, 0" {
    const light = BlockLight.init(0, 0, 0);
    try expect(light.r() == 0);
    try expect(light.g() == 0);
    try expect(light.b() == 0);
}

test "BlockLight max values" {
    const light = BlockLight.init(BlockLight.MAX_LIGHT_LEVEL, BlockLight.MAX_LIGHT_LEVEL, BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.r() == BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.g() == BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.b() == BlockLight.MAX_LIGHT_LEVEL);
}

test "BlockLight mixed values" {
    const light = BlockLight.init(5, 10, 20);
    try expect(light.r() == 5);
    try expect(light.g() == 10);
    try expect(light.b() == 20);
}

test "BlockLight set r 0" {
    var light = BlockLight.init(15, 15, 15);
    light.setR(0);
    try expect(light.r() == 0);
    try expect(light.g() == 15);
    try expect(light.b() == 15);
}

test "BlockLight set r max" {
    var light = BlockLight.init(15, 15, 15);
    light.setR(BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.r() == BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.g() == 15);
    try expect(light.b() == 15);
}

test "BlockLight set r mixed" {
    var light = BlockLight.init(15, 15, 15);
    light.setR(20);
    try expect(light.r() == 20);
    try expect(light.g() == 15);
    try expect(light.b() == 15);
}

test "BlockLight set g 0" {
    var light = BlockLight.init(15, 15, 15);
    light.setG(0);
    try expect(light.r() == 15);
    try expect(light.g() == 0);
    try expect(light.b() == 15);
}

test "BlockLight set g max" {
    var light = BlockLight.init(15, 15, 15);
    light.setG(BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.r() == 15);
    try expect(light.g() == BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.b() == 15);
}

test "BlockLight set g mixed" {
    var light = BlockLight.init(15, 15, 15);
    light.setG(20);
    try expect(light.r() == 15);
    try expect(light.g() == 20);
    try expect(light.b() == 15);
}

test "BlockLight set b 0" {
    var light = BlockLight.init(15, 15, 15);
    light.setB(0);
    try expect(light.r() == 15);
    try expect(light.g() == 15);
    try expect(light.b() == 0);
}

test "BlockLight set b max" {
    var light = BlockLight.init(15, 15, 15);
    light.setB(BlockLight.MAX_LIGHT_LEVEL);
    try expect(light.r() == 15);
    try expect(light.g() == 15);
    try expect(light.b() == BlockLight.MAX_LIGHT_LEVEL);
}

test "BlockLight set b mixed" {
    var light = BlockLight.init(15, 15, 15);
    light.setB(20);
    try expect(light.r() == 15);
    try expect(light.g() == 15);
    try expect(light.b() == 20);
}
