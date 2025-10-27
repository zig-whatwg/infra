//! WHATWG Infra Byte Sequence Operations
//!
//! Spec: https://infra.spec.whatwg.org/#byte-sequences
//!
//! A byte sequence is a sequence of bytes (8-bit unsigned integers).

const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;

pub const ByteSequence = []const u8;

pub const ByteError = error{
    InvalidUtf8,
    InvalidIsomorphicEncoding,
    OutOfMemory,
};

pub fn byteLessThan(a: ByteSequence, b: ByteSequence) bool {
    const min_len = @min(a.len, b.len);

    for (0..min_len) |i| {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }

    return a.len < b.len;
}

pub fn isAsciiByteSequence(bytes: ByteSequence) bool {
    for (bytes) |byte| {
        if (byte > 0x7F) return false;
    }
    return true;
}

pub fn decodeAsUtf8(allocator: Allocator, bytes: ByteSequence) !String {
    const string_module = @import("string.zig");
    return string_module.utf8ToUtf16(allocator, bytes);
}

pub fn utf8Encode(allocator: Allocator, string: String) !ByteSequence {
    const string_module = @import("string.zig");
    return string_module.utf16ToUtf8(allocator, string);
}

pub fn isomorphicDecode(allocator: Allocator, bytes: ByteSequence) !String {
    if (bytes.len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, bytes.len);
    for (bytes, 0..) |byte, i| {
        result[i] = @as(u16, byte);
    }
    return result;
}

pub fn isomorphicEncode(allocator: Allocator, string: String) !ByteSequence {
    if (string.len == 0) {
        return &[_]u8{};
    }

    const result = try allocator.alloc(u8, string.len);
    errdefer allocator.free(result);

    for (string, 0..) |c, i| {
        if (c > 0xFF) {
            return ByteError.InvalidIsomorphicEncoding;
        }
        result[i] = @as(u8, @intCast(c));
    }

    return result;
}

test "byteLessThan - less than" {
    const a = [_]u8{ 0x01, 0x02, 0x03 };
    const b = [_]u8{ 0x01, 0x02, 0x04 };
    try std.testing.expect(byteLessThan(&a, &b));
}

test "byteLessThan - equal" {
    const a = [_]u8{ 0x01, 0x02, 0x03 };
    const b = [_]u8{ 0x01, 0x02, 0x03 };
    try std.testing.expect(!byteLessThan(&a, &b));
}

test "byteLessThan - greater than" {
    const a = [_]u8{ 0x01, 0x02, 0x04 };
    const b = [_]u8{ 0x01, 0x02, 0x03 };
    try std.testing.expect(!byteLessThan(&a, &b));
}

test "byteLessThan - shorter is less" {
    const a = [_]u8{ 0x01, 0x02 };
    const b = [_]u8{ 0x01, 0x02, 0x03 };
    try std.testing.expect(byteLessThan(&a, &b));
}

test "byteLessThan - longer is greater" {
    const a = [_]u8{ 0x01, 0x02, 0x03 };
    const b = [_]u8{ 0x01, 0x02 };
    try std.testing.expect(!byteLessThan(&a, &b));
}

test "isAsciiByteSequence - pure ASCII" {
    const bytes = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiByteSequence(&bytes));
}

test "isAsciiByteSequence - contains high byte" {
    const bytes = [_]u8{ 'h', 0x80, 'l', 'l', 'o' };
    try std.testing.expect(!isAsciiByteSequence(&bytes));
}

test "isAsciiByteSequence - empty" {
    const bytes = [_]u8{};
    try std.testing.expect(isAsciiByteSequence(&bytes));
}

test "decodeAsUtf8 - valid UTF-8" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    const result = try decodeAsUtf8(allocator, &bytes);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "decodeAsUtf8 - Unicode" {
    const allocator = std.testing.allocator;
    const bytes = "héllo";
    const result = try decodeAsUtf8(allocator, bytes);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "decodeAsUtf8 - invalid UTF-8" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 0xFF, 0xFE };
    const result = decodeAsUtf8(allocator, &bytes);
    try std.testing.expectError(error.InvalidUtf8, result);
}

test "utf8Encode - ASCII" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try utf8Encode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello", result);
}

test "utf8Encode - Unicode BMP" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    const result = try utf8Encode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("héllo", result);
}

test "utf8Encode - surrogate pairs" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 0xD83D, 0xDCA9 };
    const result = try utf8Encode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("💩", result);
}

test "isomorphicDecode - byte sequence to string" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{ 0x41, 0x42, 0x43, 0xFF };
    const result = try isomorphicDecode(allocator, &bytes);
    defer allocator.free(result);

    const expected = [_]u16{ 0x0041, 0x0042, 0x0043, 0x00FF };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "isomorphicDecode - empty" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{};
    const result = try isomorphicDecode(allocator, &bytes);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "isomorphicEncode - string to bytes" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 0x0041, 0x0042, 0x0043, 0x00FF };
    const result = try isomorphicEncode(allocator, &string);
    defer allocator.free(result);

    const expected = [_]u8{ 0x41, 0x42, 0x43, 0xFF };
    try std.testing.expectEqualSlices(u8, &expected, result);
}

test "isomorphicEncode - error on high code unit" {
    const allocator = std.testing.allocator;
    const string = [_]u16{ 0x0041, 0x0100 };
    const result = isomorphicEncode(allocator, &string);
    try std.testing.expectError(ByteError.InvalidIsomorphicEncoding, result);
}

test "isomorphicEncode - empty" {
    const allocator = std.testing.allocator;
    const string = [_]u16{};
    const result = try isomorphicEncode(allocator, &string);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "roundtrip - isomorphicDecode then encode" {
    const allocator = std.testing.allocator;
    const original = [_]u8{ 0x41, 0x42, 0x43, 0xFF };

    const string = try isomorphicDecode(allocator, &original);
    defer allocator.free(string);

    const bytes = try isomorphicEncode(allocator, string);
    defer allocator.free(bytes);

    try std.testing.expectEqualSlices(u8, &original, bytes);
}
