const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;

/// See string_simd.cpp
extern fn stringCompareEqualStringAndStringSimdHeapRep(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) bool;
/// See string_simd.cpp
extern fn stringCompareEqualStringAndSliceSimdHeapRep(selfBuffer: [*c]const u8, otherBuffer: [*c]const u8, len: c_ulonglong) bool;

/// Utility functions for string slice handling
pub const Slice = struct {
    /// Find the index of the first occurence of `character`
    /// within `slice`. Returns null if not found.
    pub fn find(slice: [:0]const u8, character: u8) ?usize {
        // TODO simd
        var i: usize = 0;
        for (slice) |c| {
            if (c == character) {
                return i;
            }
            i += 1;
        }
        return null;
    }

    /// Find the index of the first occurence of `character` starting at `offset`
    /// within `slice`. Returns null if not found.
    pub fn findFrom(slice: [:0]const u8, character: u8, offset: usize) ?usize {
        // TODO simd ??? maybe?
        if (offset >= slice.len) {
            return null;
        }

        for (offset..slice.len) |i| {
            if (slice[i] == character) {
                return i;
            }
        }
        return null;
    }

    /// Find the index of the first occurrence of the sub-string `other`
    /// within `slice`. Returns null if not found.
    pub fn findSlice(slice: [:0]const u8, other: [:0]const u8) ?usize {
        if (other.len > slice.len) {
            return null;
        } else if (slice.len == other.len) {
            if (std.mem.eql(u8, slice, other)) {
                return 0;
            } else {
                return null;
            }
        }

        const upperLimit: usize = (slice.len - other.len) + 1;
        for (0..upperLimit) |i| {
            if (slice[i] != other[0]) {
                continue;
            }

            const compareSlice: []const u8 = slice[i..][0..other.len];
            if (std.mem.eql(u8, compareSlice, other)) { // comparison doesn't check null terminator in other
                return i;
            }
        }

        return null;
    }

    /// Find the index of the first occurrence of the sub-string `other`
    /// starting at `offset` within `slice`. Returns null if not found.
    pub fn findSliceFrom(slice: [:0]const u8, other: [:0]const u8, offset: usize) ?usize {
        if (offset >= slice.len) {
            return null;
        }

        const upperLimit: usize = (slice.len - other.len) + 1;
        if (offset >= upperLimit) {
            return null;
        }

        for (offset..upperLimit) |i| {
            if (slice[i] != other[0]) {
                continue;
            }

            const compareSlice: []const u8 = slice[i..][0..other.len];
            if (std.mem.eql(u8, compareSlice, other)) { // comparison doesn't check null terminator in other
                return i;
            }
        }

        return null;
    }

    /// Find the index of the last occurrence of `character` within `slice`.
    /// Returns null if not found.
    pub fn findLast(slice: [:0]const u8, character: u8) ?usize {
        var i: usize = slice.len;
        while (i > 0) {
            i -= 1;

            if (slice[i] == character) {
                return i;
            }
        }
        return null;
    }

    /// Find the index of the last occurrence of `character` within `slice`, starting
    /// at index `offset - 1` and searching the string backwards. Returns null if not found.
    pub fn findLastFrom(slice: [:0]const u8, character: u8, offset: usize) ?usize {
        if (offset > slice.len) {
            return null;
        } else if (offset == 0) {
            if (slice[0] == character) {
                return 0;
            } else {
                return null;
            }
        }

        var i: usize = offset;
        while (i > 0) {
            i -= 1;

            if (slice[i] == character) {
                return i;
            }
        }
        return null;
    }

    /// Find the index of the last occurrence of `other` within `slice`.
    ///  Returns null if not found.
    pub fn findLastSlice(slice: [:0]const u8, other: [:0]const u8) ?usize {
        if (other.len > slice.len) {
            return null;
        } else if (slice.len == other.len) {
            if (std.mem.eql(u8, slice, other)) {
                return 0;
            } else {
                return null;
            }
        }

        const upperLimit: usize = (slice.len - other.len) + 1;
        var i: usize = upperLimit;
        while (i > 0) {
            i -= 1;

            if (slice[i] != other[0]) {
                continue;
            }

            const compareSlice: []const u8 = slice[i..][0..other.len];
            if (std.mem.eql(u8, compareSlice, other)) {
                return i;
            }
        }

        return null;
    }

    /// Find the index of the last occurrence of `other` within `slice`, starting
    /// at `offset` and searching the string backwards. Returns null if not found.
    pub fn findLastSliceFrom(slice: [:0]const u8, other: [:0]const u8, offset: usize) ?usize {
        if (offset > slice.len) {
            return null;
        }

        const start = (offset - other.len) + 1;
        const upperLimit: usize = (slice.len - other.len) + 1;
        if (start > upperLimit) {
            return null;
        }

        var i: usize = start;
        while (i > 0) {
            i -= 1;

            if (slice[i] != other[0]) {
                continue;
            }

            const compareSlice: []const u8 = slice[i..][0..other.len];
            if (std.mem.eql(u8, compareSlice, other)) {
                return i;
            }
        }

        return null;
    }

    /// Parses the string `slice` as a bool. Returns an error if
    /// the string is not either "true" or "false".
    pub fn parseBool(slice: [:0]const u8) !bool {
        if (std.mem.eql(u8, slice, "true")) {
            return true;
        } else if (std.mem.eql(u8, slice, "false")) {
            return false;
        }
        return error{ParseBoolError};
    }

    pub const parseInt = std.fmt.parseInt;
    pub const parseUnsigned = std.fmt.parseUnsigned;
    pub const parseFloat = std.fmt.parseFloat;
};

///
pub const StringUnmanaged = extern struct {
    const Self = @This();

    _rep: StringRep = StringRep.default(),

    /// Frees the string's memory if it's not currently using the SSO representation.
    /// If it is, does nothing.
    pub fn deinit(self: Self, allocator: Allocator) void {
        if (self.isSso()) {
            return;
        }

        self.freeHeapRep(allocator);
    }

    /// Initializes a new `StringUnmanaged` to have a pre-allocated buffer that is at least `requiredCapacity` in bytes
    /// including null terminators.
    pub fn initCapacity(allocator: Allocator, requiredCapacity: usize) Allocator.Error!Self {
        var self = Self{};
        try self.ensureTotalCapacityPrecise(allocator, requiredCapacity);
        return self;
    }

    /// Constructs a new `StringUnmanaged` filled with a copy of `slice`.
    pub fn fromSlice(allocator: Allocator, slice: [:0]const u8) Allocator.Error!Self {
        var self = try Self.initCapacity(allocator, slice.len + 1);
        if (self.isSso()) {
            var i: usize = 0;
            for (slice) |c| {
                self._rep.sso.chars[i] = c;
                i += 1;
            }
            self._rep.sso.setLen(slice.len);
        } else {
            self._rep.heap.len = slice.len;
            for (0..self._rep.heap.len) |i| {
                self._rep.heap.data[i] = slice[i];
            }
        }
        return self;
    }

    /// Create a clone of this `StringUnmanaged`. The self and return will have the same `len()` and string data.
    /// Calling `toSlice()` on the self and return will yield equal slices but different pointers.
    /// The two will not have the same guaranteed capacity.
    pub fn clone(self: *const Self, allocator: Allocator) Allocator.Error!Self {
        return Self.fromSlice(allocator, self.toSlice());
    }

    /// Length of the `StringUnmanaged`, excluding null terminators. It is NOT UTF-8 codepoints,
    /// rather the number of bytes.
    pub fn len(self: *const Self) usize {
        if (self.isSso()) {
            return self._rep.sso.len();
        } else {
            return self._rep.heap.len;
        }
    }

    /// Get this `StringUnmanaged`'s data as a borrowed immutable null terminated slice.
    pub fn toSlice(self: *const Self) [:0]const u8 {
        if (self.isSso()) {
            const out: [:0]const u8 = self._rep.sso.chars[0..self._rep.sso.len() :0];
            return out;
        } else {
            return self._rep.heap.data[0..self._rep.heap.len :0];
        }
    }

    /// Equality comparison between two `StringUnmanaged` instances.
    pub fn eql(self: *const Self, other: Self) bool {
        if (!self.isSso() and !other.isSso()) {
            if (self._rep.heap.len != other._rep.heap.len) {
                return false;
            }
            //return true;
            return stringCompareEqualStringAndStringSimdHeapRep(@ptrCast(self._rep.heap.data), @ptrCast(other._rep.heap.data), self._rep.heap.len);
        }
        return std.mem.eql(u8, self.toSlice(), other.toSlice());
    }

    /// Equality comparison between self and a null terminated slice.
    pub fn eqlSlice(self: *const Self, other: [:0]const u8) bool {
        // TODO explicit AVX512 or AVX2 from calling extern C function
        if (!self.isSso()) {
            if (self._rep.heap.len != other.len) {
                return false;
            }
            return stringCompareEqualStringAndSliceSimdHeapRep(@ptrCast(self._rep.heap.data), @ptrCast(other.ptr), other.len);
        }
        return std.mem.eql(u8, self.toSlice(), other);
    }

    pub fn hash(self: *const Self) usize {
        // TODO explicit AVX512 or AVX2 from calling extern C function. The AVX512 version does not have to equal the AVX2 version, as long as only one is used during application runtime.
        _ = self;
        return 0;
    }

    /// Pre-allocate space in the string to fit a string of at least length `requiredCapacity`.
    /// Specutively reserves extra space for future appending. Adds 1 byte for null terminator.
    pub fn reserve(self: *Self, allocator: Allocator, requiredCapacity: usize) Allocator.Error!void {
        return self.ensureTotalCapacity(allocator, requiredCapacity + 1); // null terminator
    }

    /// Pre-allocate space in the string to fit a string of at least length `requiredCapacity`,
    /// reserving no extra space than actually required. Adds 1 byte for null terminator.
    pub fn reserveExact(self: *Self, allocator: Allocator, requiredCapacity: usize) Allocator.Error!void {
        return self.ensureTotalCapacityPrecise(allocator, requiredCapacity + 1); // null terminator
    }

    /// Appends another `StringUnmanaged` to the end of this one, allocating extra space if necessary.
    /// Mutates self, does not mutate other.
    pub fn append(self: *Self, allocator: Allocator, other: *const Self) Allocator.Error!void {
        return self.appendSlice(allocator, other.toSlice());
    }

    /// Appends a string slice to the end of self, allocating extra space if necessary.
    /// Mutates self, does not mutate other.
    pub fn appendSlice(self: *Self, allocator: Allocator, other: [:0]const u8) Allocator.Error!void {
        const currentCapacity: usize = if (self.isSso()) SsoRep.MAX_LEN else self._rep.heap.capacity();
        try self.ensureTotalCapacity(allocator, currentCapacity + other.len);
        if (self.isSso()) {
            const offset: []u8 = self._rep.sso.chars[self._rep.sso.len()..][0..other.len];
            @memcpy(offset, other);
            self._rep.sso.setLen(self._rep.sso.len() + other.len);
        } else {
            const oldLen = self._rep.heap.len;
            self._rep.heap.len += other.len;
            const offset: []u8 = self._rep.heap.data[oldLen..][0..other.len];
            @memcpy(offset, other);
        }
    }

    /// Concatenate two `StringUnmanaged` together, making a new string.
    /// Essentially appends rhs to the end of a copy of lhs.
    pub fn concat(allocator: Allocator, lhs: *const Self, rhs: *const Self) Allocator.Error!Self {
        return concatSlice(allocator, lhs, rhs.toSlice());
    }

    /// Concatenate a `StringUnmanaged` with a stirng slice together, making a new string.
    /// Essentially appends rhs to the end of a copy of lhs.
    pub fn concatSlice(allocator: Allocator, lhs: *const Self, rhs: [:0]const u8) Allocator.Error!void {
        const lhsCapacity: usize = if (lhs.isSso()) SsoRep.MAX_LEN else lhs._rep.heap.capacity();
        var self = try Self.initCapacity(allocator, lhsCapacity + rhs.len);
        if (self.isSso()) {
            var i: usize = 0;
            for (rhs) |c| {
                self._rep.sso.chars[i] = c;
                i += 1;
            }
            self._rep.sso.setLen(self._rep.sso.len() + rhs.len);
        } else {
            self._rep.heap.len += rhs.len;
            for (0..self._rep.heap.len) |i| {
                self._rep.heap.data[i] = rhs[i];
            }
        }
    }

    /// Find the index of the first occurence of `character` withing the string.
    /// Returns null if the character doesn't exist in the string.
    pub fn find(self: *const Self, character: u8) ?usize {
        return Slice.find(self.toSlice(), character);
    }

    pub fn findSlice(self: *const Self, substr: [:0]const u8) ?usize {
        return Slice.findSlice(self.toSlice(), substr);
    }

    pub fn findString(self: *const Self, substr: *const Self) ?usize {
        return Slice.findSlice(self.toSlice(), substr.toSlice());
    }

    /// Find the index of the first occurrence of `character` within the string after
    /// index `offset` inclusively. Returns null if the character doesn't exist in the string.
    pub fn findFrom(self: *const Self, character: u8, offset: usize) ?usize {
        return Slice.findFrom(self.toSlice(), character, offset);
    }

    pub fn findSliceFrom(self: *const Self, substr: [:0]const u8, offset: usize) ?usize {
        return Slice.findSliceFrom(self.toSlice(), substr, offset);
    }

    pub fn findStringFrom(self: *const Self, substr: *const Self, offset: usize) ?usize {
        return Slice.findSliceFrom(self.toSlice(), substr.toSlice(), offset);
    }

    pub fn findLast(self: *const Self, character: u8) ?usize {
        return Slice.findLast(self.toSlice(), character);
    }

    pub fn findLastSlice(self: *const Self, substr: []const u8) ?usize {
        return Slice.findLastSlice(self.toSlice(), substr);
    }

    pub fn findLastString(self: *const Self, substr: *const Self) ?usize {
        return Slice.findLastSlice(self.toSlice(), substr.toSlice());
    }

    pub fn findLastFrom(self: *const Self, character: u8, offset: usize) ?usize {
        return Slice.findLastFrom(self.toSlice(), character, offset);
    }

    pub fn findLastSliceFrom(self: *const Self, substr: []const u8, offset: usize) ?usize {
        return Slice.findLastSliceFrom(self.toSlice(), substr, offset);
    }

    pub fn findLastStringFrom(self: *const Self, substr: *const Self, offset: usize) ?usize {
        return Slice.findLastSliceFrom(self.toSlice(), substr.toSlice(), offset);
    }

    pub fn substring(self: *const Self, allocator: Allocator, startIndexInclusive: usize, endIndexExclusive: usize) Allocator.Error!Self {
        _ = self;
        _ = allocator;
        _ = startIndexInclusive;
        _ = endIndexExclusive;
    }

    /// Create a new `StringUnmanaged` with character representing the providing bool value.
    ///
    /// * b = true -> "true"
    /// * b = false -> "false"
    ///
    /// Due to the size of the SSO buffer, this is guaranteed to not require an allocator.
    pub fn fromBool(b: bool) Self {
        var self = StringUnmanaged{};
        if (b) {
            @memcpy(self._rep.sso.chars, "true");
            self._rep.sso.setLen(4);
        } else {
            @memcpy(self._rep.sso.chars, "false");
            self._rep.sso.setLen(5);
        }
        return self;
    }

    /// Create a new `StringUnmanaged` with characters representing the provided signed or unsigned `num` of type `T`.
    /// `base` is the base of the number to represent the string as. Only 4 different values are allowed.
    ///
    /// * `base` = 2 (binary) -> The string will be prefixed with 0b
    /// * `base` = 8 (octal) -> The string will be prefixed with 0o
    /// * `base` = 10 (decimal) -> No prefix
    /// * `base` = 16 (hexadecimal) -> The string will be prefixed with 0x. Capital letters will be used
    ///
    /// Signedness is ignored for all bases except for 10.
    ///
    /// For `base` = 10 and `base` = 16, allocation will never fail due
    /// to the size of the SSO buffer.
    pub fn fromInt(allocator: Allocator, comptime T: type, num: T, comptime base: u8) Allocator.Error!Self {
        comptime switch (base) {
            2 => @compileError("not yet implemented"),
            8 => @compileError("not yet implemented"),
            10 => return fromIntBase10(T, num),
            16 => @compileError("not yet implemented"),
            else => @compileError("base of StringUnmanaged must be either 2, 8, 10, or 16"),
        };

        _ = allocator;
    }

    /// Parses `self` as a bool. Returns an error if
    /// the string is not either "true" or "false".
    pub fn parseBool(self: Self) !bool {
        return Slice.parseBool(self.toSlice());
    }

    /// Parses `self` as a signed or unsigned integer `T`.
    /// Ignores '_' character in `self`.
    ///
    ///  * A prefix of "0b" implies base=2,
    ///  * A prefix of "0o" implies base=8,
    ///  * A prefix of "0x" implies base=16,
    ///  * Otherwise base=10 is assumed.
    pub fn parseInt(self: Self, comptime T: type) !T {
        return Slice.parseInt(T, self.toSlice(), 0);
    }

    /// Parses the `self` as an unsigned integer `T`.
    /// Ignores '_' character in `self`. Is basically the same as `parseInt` but skips any sign checks.
    ///
    ///  * A prefix of "0b" implies base=2,
    ///  * A prefix of "0o" implies base=8,
    ///  * A prefix of "0x" implies base=16,
    ///  * Otherwise base=10 is assumed.
    pub fn parseUnsigned(self: Self, comptime T: type) !T {
        return Slice.parseUnsigned(T, self.toSlice(), 0);
    }

    /// Parses `self` as a floating point number `T`.
    pub fn parseFloat(self: Self, comptime T: type) !T {
        return Slice.parseFloat(T, self.toSlice());
    }

    fn ensureTotalCapacity(self: *Self, allocator: Allocator, newCapacity: usize) Allocator.Error!void {
        const currentCapacity: usize = if (self.isSso()) SsoRep.MAX_LEN else self._rep.heap.capacity();
        const newActualCapacity = growCapacity(currentCapacity, newCapacity);
        return self.ensureTotalCapacityPrecise(allocator, newActualCapacity);
    }

    fn ensureTotalCapacityPrecise(self: *Self, allocator: Allocator, newCapacity: usize) Allocator.Error!void {
        var mallocCapacity = newCapacity;

        if (self.isSso()) {
            if (newCapacity <= SsoRep.MAX_LEN) {
                return;
            }

            const newSlice: [:0]align(64) u8 = try mallocCharBufferAligned(allocator, &mallocCapacity);
            const currentSsoLen = self._rep.sso.len();
            for (0..currentSsoLen) |i| {
                newSlice[i] = self._rep.sso.chars[i];
            }
            //newSlice[currentSsoLen - 1] = 0; // null terminator

            self._rep.heap.data = newSlice.ptr;
            self._rep.heap.len = currentSsoLen;
            self._rep.heap.setCapacity(mallocCapacity);
            return;
        }

        if (newCapacity <= self._rep.heap.capacity()) {
            return;
        }

        const newSlice: [:0]align(64) u8 = try mallocCharBufferAligned(allocator, &mallocCapacity);
        const currentLen = self._rep.heap.len;
        for (0..currentLen) |i| {
            newSlice[i] = self._rep.heap.data[i];
        }

        var freeSlice: []align(64) u8 = self._rep.heap.data[0..self._rep.heap.len];
        freeSlice.len = self._rep.heap.capacity();
        allocator.free(freeSlice);

        self._rep.heap.data = newSlice.ptr;
        self._rep.heap.len = newSlice.len;
        self._rep.heap.setCapacity(mallocCapacity);
    }

    fn growCapacity(current: usize, minimum: usize) usize {
        var new = current;
        while (true) {
            // https://github.com/ziglang/zig/issues/1284#issuecomment-907580258
            new +|= new / 2 + 32;
            if (new >= minimum)
                return new;
        }
    }

    fn freeHeapRep(self: Self, allocator: Allocator) void {
        var slice: []align(64) u8 = self._rep.heap.data[0..self._rep.heap.capacity()];
        slice.len = self._rep.heap.capacity();
        allocator.free(slice);
    }

    fn isSso(self: *const Self) bool {
        return !self._rep.heap.isFlagSet();
    }

    /// Guaranteed to never fail due to SSO buffer size.
    fn fromIntBase10(comptime T: type, num: T) Self {
        const info = @typeInfo(T);
        comptime assert(info == .Int);

        var self = StringUnmanaged{};

        if (num == 0) {
            self._rep.sso.chars[0] = '0';
            self._rep.sso.setLen(1);
            return self;
        }

        const digits = "9876543210123456789";
        const zeroDigit = 9;
        const maxChars = 20;

        var tempNums: [maxChars]u8 = undefined;
        var tempAt: usize = maxChars;

        while (num) {
            tempAt -= 1;
            tempNums[tempAt] = digits[zeroDigit + @mod(num, 10)];
            num = @divTrunc(num, 10);
        }
        comptime if (info.Int.signedness == .signed) {
            if (num < 0) {
                tempAt -= 1;
                tempNums[tempAt] = '-';
            }
        };

        const length: usize = maxChars - tempAt;
        @memcpy(self._rep.sso.chars, tempNums[tempAt..][0..length]);
        self._rep.sso.setLen(length);
        return self;
    }
}; // StringUnmanaged

fn mallocCharBufferAligned(allocator: Allocator, capacity: *usize) Allocator.Error![:0]align(64) u8 {
    var mallocCapacity = capacity.*;
    const remainder = @mod(mallocCapacity, 64);
    if (remainder != 0) {
        mallocCapacity = mallocCapacity + (64 - remainder);
    }
    capacity.* = mallocCapacity;
    const newSlice: []align(64) u8 = try allocator.alignedAlloc(u8, 64, mallocCapacity);
    @memset(newSlice, 0);
    return newSlice[0..(newSlice.len - 1) :0];
}

const HeapRep = extern struct {
    const Self = @This();

    const FLAG_BIT: usize = @shlExact(1, 63);

    data: [*:0]align(64) u8,
    len: usize,
    capacityAndFlag: usize,

    fn isFlagSet(self: Self) bool {
        return (self.capacityAndFlag & FLAG_BIT) != 0;
    }

    fn capacity(self: Self) usize {
        return self.capacityAndFlag & (~FLAG_BIT);
    }

    /// Also sets flag. Marking this string as heap, not SSO.
    fn setCapacity(self: *Self, newCapacity: usize) void {
        assert(newCapacity < (~FLAG_BIT));
        self.capacityAndFlag = newCapacity | FLAG_BIT;
    }
};

const SsoRep = extern struct {
    const Self = @This();

    const MAX_LEN = 23;

    chars: [24]u8,

    fn default() Self {
        var newSelf = std.mem.zeroes(Self);
        newSelf.setLen(0);
        return newSelf;
    }

    fn len(self: Self) usize {
        return MAX_LEN - self.chars[23];
    }

    /// Also clears the heap flag, ensuring the string is SSO flagged.
    fn setLen(self: *Self, newLen: usize) void {
        assert(newLen < MAX_LEN);
        self.chars[23] = MAX_LEN - @as(u8, @intCast(newLen));
    }
};

const StringRep = extern union {
    sso: SsoRep,
    heap: HeapRep,

    fn default() StringRep {
        return StringRep{ .sso = SsoRep.default() };
    }
};

// Tests

test "slice find" {
    const s = "hello world!";
    try expect(Slice.find(s, 'w') == 6);
    try expect(Slice.find(s, 'a') == null);
}

test "slice find from" {
    const s = "hello world!";
    try expect(Slice.findFrom(s, 'l', 5) == 9);
    try expect(Slice.findFrom(s, 'l', 9) == 9);
    try expect(Slice.findFrom(s, 'l', 10) == null);
}

test "slice find slice" {
    const s = "hello world!";
    try expect(Slice.findSlice(s, "hello") == 0);
    try expect(Slice.findSlice(s, "world") == 6);
    try expect(Slice.findSlice(s, "world!") == 6);
    try expect(Slice.findSlice(s, "war!") == null);
}

test "slice find slice from" {
    const s = "hello hello world!";
    try expect(Slice.findSliceFrom(s, "hello", 2) == 6);
    try expect(Slice.findSliceFrom(s, "hello", 6) == 6);
    try expect(Slice.findSliceFrom(s, "hello", 7) == null);
    try expect(Slice.findSliceFrom(s, "ld!", 7) == 15);
}

test "slice find last" {
    const s = "hello world!";
    try expect(Slice.findLast(s, 'l') == 9);
    try expect(Slice.findLast(s, 'o') == 7);
    try expect(Slice.findLast(s, '!') == 11);
}

test "slice find last from" {
    const s = "hello world!";
    try expect(Slice.findLastFrom(s, 'l', 7) == 3);
    try expect(Slice.findLastFrom(s, 'o', 6) == 4);
    try expect(Slice.findLastFrom(s, '!', 12) == 11);
    try expect(Slice.findLastFrom(s, '!', 10) == null);
}

test "slice find last slice" {
    const s = "hello hello world!";
    try expect(Slice.findLastSlice(s, "hello") == 6);
    try expect(Slice.findLastSlice(s, "world!") == 12);
    try expect(Slice.findLastSlice(s, "war!") == null);
}

test "slice find last slice from" {
    const s = "hello hello world!";
    try expect(Slice.findLastSliceFrom(s, "hello", 5) == 0);
    try expect(Slice.findLastSliceFrom(s, "world!", 18) == 12);
    try expect(Slice.findLastSliceFrom(s, "world!", 17) == null);
    try expect(Slice.findLastSliceFrom(s, "war!", 6) == null);
}

test "init" {
    {
        _ = StringUnmanaged{};
    }
}

test "init with capacity" {
    const allocator = std.testing.allocator;
    {
        const s = try StringUnmanaged.initCapacity(allocator, 50);
        try expect(s.len() == 0);
        s.deinit(allocator);
    }
}

test "from slice" {
    const allocator = std.testing.allocator;
    {
        { // sso
            const s = try StringUnmanaged.fromSlice(allocator, "hello world!");
            try expect(s.len() == 12);
            try expect(std.mem.eql(u8, s.toSlice(), "hello world!"));
            s.deinit(allocator);
        }
        { // heap
            const slice = "good morning hello wow whoa holy moly";
            const s = try StringUnmanaged.fromSlice(allocator, slice);
            try expect(s.len() == 37);
            try expect(std.mem.eql(u8, s.toSlice(), slice));
            s.deinit(allocator);
        }
    }
}

test "clone" {
    const allocator = std.testing.allocator;
    {
        { // empty
            const s1 = StringUnmanaged{};
            defer s1.deinit(allocator);

            const s2 = try s1.clone(allocator);
            defer s2.deinit(allocator);

            try expect(s2.len() == 0);
            try expect(std.mem.eql(u8, s2.toSlice(), ""));
        }
        { // sso
            const slice = "hello world!";

            const s1 = try StringUnmanaged.fromSlice(allocator, slice);
            defer s1.deinit(allocator);

            const s2 = try s1.clone(allocator);
            defer s2.deinit(allocator);

            try expect(s2.len() == 12);
            try expect(std.mem.eql(u8, s1.toSlice(), s2.toSlice()));
        }
        { // heap
            const slice = "good morning hello wow whoa holy moly";

            const s1 = try StringUnmanaged.fromSlice(allocator, slice);
            defer s1.deinit(allocator);

            const s2 = try s1.clone(allocator);
            defer s2.deinit(allocator);

            try expect(s2.len() == 37);
            try expect(std.mem.eql(u8, s1.toSlice(), s2.toSlice()));
        }
    }
}

test "equal" {
    const allocator = std.testing.allocator;
    {
        const s1 = try StringUnmanaged.fromSlice(allocator, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        defer s1.deinit(allocator);

        const s2 = try s1.clone(allocator);
        defer s2.deinit(allocator);

        try expect(s1.eql(s2));
    }
}
