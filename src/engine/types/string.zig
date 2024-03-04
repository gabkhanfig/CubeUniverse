const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;

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
