const std = @import("std");
const expect = std.testing.expect;

pub fn Vector3(comptime T: type) type {
    return extern struct {
        const Self = @This();

        x: T = std.mem.zeroes(T),
        y: T = std.mem.zeroes(T),
        z: T = std.mem.zeroes(T),

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
        }

        pub fn addAssign(self: *Self, other: Self) void {
            self.* = self.add(other);
        }

        pub fn addScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x + scalar, .y = self.y + scalar, .z = self.z + scalar };
        }

        pub fn addScalarAssign(self: *Self, scalar: T) void {
            self.* = self.addScalar(scalar);
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        }

        pub fn subAssign(self: *Self, other: Self) void {
            self.* = self.sub(other);
        }

        pub fn subScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x - scalar, .y = self.y - scalar, .z = self.z - scalar };
        }

        pub fn subScalarAssign(self: *Self, scalar: T) void {
            self.* = self.subScalar(scalar);
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
        }

        pub fn mulAssign(self: *Self, other: Self) void {
            self.* = self.mul(other);
        }

        pub fn mulScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
        }

        pub fn mulScalarAssign(self: *Self, scalar: T) void {
            self.* = self.mulScalar(scalar);
        }

        pub fn div(self: Self, other: Self) Self {
            return .{ .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
        }

        pub fn divAssign(self: *Self, other: Self) void {
            self.* = self.div(other);
        }

        pub fn divScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
        }

        pub fn divScalarAssign(self: *Self, scalar: T) void {
            self.* = self.divScalar(scalar);
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y and self.z == other.z;
        }
    };
}

// Tests

test "Default 0" {
    {
        const v = Vector3(f32){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
    {
        const v = Vector3(f64){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
    {
        const v = Vector3(i32){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
    {
        const v = Vector3(u32){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
}

test "Add" {
    {
        const v1 = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        const v1 = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f64){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        const v1 = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(i32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        const v1 = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(u32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
}

test "Add assign" {
    {
        var v = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f32){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        var v = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f64){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        var v = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(i32){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        var v = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(u32){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
}

test "Add scalar" {
    {
        const v1 = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        const v1 = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        const v1 = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        const v1 = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
}

test "Add scalar assign" {
    {
        var v = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        var v = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        var v = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        var v = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
}
