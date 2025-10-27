//! WHATWG Infra String Operations
//!
//! Spec: https://infra.spec.whatwg.org/#string
//!
//! A string is a sequence of 16-bit unsigned integers (code units), representing
//! UTF-16 encoded text. This matches JavaScript's internal string representation
//! and allows zero-copy interop with V8.
//!
//! # String Representation
//!
//! Infra strings use UTF-16 encoding (`[]const u16`), NOT UTF-8. This is
//! required by the WHATWG Infra specification and enables direct V8 interop.
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const string = @import("string.zig");
//!
//! const allocator = std.heap.page_allocator;
//!
//! // Convert UTF-8 (Zig default) to UTF-16 (Infra)
//! const utf8_str = "hello";
//! const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
//! defer allocator.free(infra_str);
//!
//! // Convert UTF-16 (Infra) back to UTF-8 (Zig)
//! const utf8_result = try string.utf16ToUtf8(allocator, infra_str);
//! defer allocator.free(utf8_result);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const String = []const u16;

pub const InfraError = error{
    InvalidUtf8,
    InvalidUtf16,
    InvalidCodePoint,
    OutOfMemory,
};

pub fn utf8ToUtf16(allocator: Allocator, utf8: []const u8) !String {
    if (utf8.len == 0) {
        return &[_]u16{};
    }

    if (isAscii(utf8)) {
        const result = try allocator.alloc(u16, utf8.len);
        errdefer allocator.free(result);
        for (utf8, 0..) |byte, i| {
            result[i] = byte;
        }
        return result;
    }

    return utf8ToUtf16Unicode(allocator, utf8);
}

inline fn isAscii(bytes: []const u8) bool {
    if (bytes.len >= 16) {
        return isAsciiSimd(bytes);
    }

    for (bytes) |b| {
        if (b >= 0x80) return false;
    }
    return true;
}

fn isAsciiSimd(bytes: []const u8) bool {
    const VecSize = 16;
    const Vec = @Vector(VecSize, u8);
    const ascii_mask: Vec = @splat(0x80);

    var i: usize = 0;

    while (i + VecSize <= bytes.len) : (i += VecSize) {
        const chunk: Vec = bytes[i..][0..VecSize].*;
        const masked = chunk & ascii_mask;
        if (@reduce(.Or, masked) != 0) return false;
    }

    while (i < bytes.len) : (i += 1) {
        if (bytes[i] >= 0x80) return false;
    }

    return true;
}

fn utf8ToUtf16Unicode(allocator: Allocator, utf8: []const u8) !String {
    var result = try std.ArrayList(u16).initCapacity(allocator, utf8.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < utf8.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8[i]) catch {
            return InfraError.InvalidUtf8;
        };

        if (i + len > utf8.len) {
            return InfraError.InvalidUtf8;
        }

        const codepoint = std.unicode.utf8Decode(utf8[i .. i + len]) catch {
            return InfraError.InvalidUtf8;
        };

        if (codepoint <= 0xFFFF) {
            try result.append(allocator, @intCast(codepoint));
        } else if (codepoint <= 0x10FFFF) {
            const high = @as(u16, @intCast(0xD800 + ((codepoint - 0x10000) >> 10)));
            const low = @as(u16, @intCast(0xDC00 + ((codepoint - 0x10000) & 0x3FF)));
            try result.append(allocator, high);
            try result.append(allocator, low);
        } else {
            return InfraError.InvalidUtf8;
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

pub fn utf16ToUtf8(allocator: Allocator, utf16: String) ![]const u8 {
    if (utf16.len == 0) {
        return &[_]u8{};
    }

    var result = try std.ArrayList(u8).initCapacity(allocator, utf16.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < utf16.len) {
        const unit = utf16[i];

        const codepoint: u21 = blk: {
            if (unit >= 0xD800 and unit <= 0xDBFF) {
                if (i + 1 >= utf16.len) {
                    return InfraError.InvalidUtf16;
                }
                const low = utf16[i + 1];
                if (low < 0xDC00 or low > 0xDFFF) {
                    return InfraError.InvalidUtf16;
                }
                i += 1;
                const high_bits = @as(u21, unit - 0xD800);
                const low_bits = @as(u21, low - 0xDC00);
                break :blk 0x10000 + (high_bits << 10) + low_bits;
            } else if (unit >= 0xDC00 and unit <= 0xDFFF) {
                return InfraError.InvalidUtf16;
            } else {
                break :blk @as(u21, unit);
            }
        };

        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            return InfraError.InvalidCodePoint;
        };
        try result.appendSlice(allocator, buf[0..len]);

        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, string.len);
    errdefer allocator.free(result);

    for (string, 0..) |c, i| {
        result[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }

    return result;
}

pub fn asciiUppercase(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, string.len);
    errdefer allocator.free(result);

    for (string, 0..) |c, i| {
        result[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
    }

    return result;
}

pub inline fn isAsciiString(string: String) bool {
    for (string) |c| {
        if (c > 0x7F) return false;
    }
    return true;
}

pub fn isAsciiCaseInsensitiveMatch(a: String, b: String) bool {
    if (a.len != b.len) return false;

    for (a, b) |ca, cb| {
        const lower_a = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lower_b = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (lower_a != lower_b) return false;
    }

    return true;
}

pub fn asciiByteLength(string: String) InfraError!usize {
    for (string) |c| {
        if (c > 0x7F) return InfraError.InvalidCodePoint;
    }
    return string.len;
}

pub inline fn isAsciiWhitespace(c: u16) bool {
    return c == 0x0009 or c == 0x000A or c == 0x000C or c == 0x000D or c == 0x0020;
}

pub fn stripLeadingAndTrailingAsciiWhitespace(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var start: usize = 0;
    while (start < string.len and isAsciiWhitespace(string[start])) {
        start += 1;
    }

    if (start == string.len) {
        return &[_]u16{};
    }

    var end: usize = string.len;
    while (end > start and isAsciiWhitespace(string[end - 1])) {
        end -= 1;
    }

    const result = try allocator.alloc(u16, end - start);
    @memcpy(result, string[start..end]);
    return result;
}

pub fn stripNewlines(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var result = try std.ArrayList(u16).initCapacity(allocator, string.len);
    errdefer result.deinit(allocator);

    for (string) |c| {
        if (c != 0x000A and c != 0x000D) {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

pub fn normalizeNewlines(allocator: Allocator, string: String) !String {
    if (string.len == 0) {
        return &[_]u16{};
    }

    var result = try std.ArrayList(u16).initCapacity(allocator, string.len);
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < string.len) {
        const c = string[i];
        if (c == 0x000D) {
            if (i + 1 < string.len and string[i + 1] == 0x000A) {
                i += 1;
            }
            try result.append(allocator, 0x000A);
        } else {
            try result.append(allocator, c);
        }
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

pub fn splitOnAsciiWhitespace(allocator: Allocator, string: String) ![]String {
    if (string.len == 0) {
        return &[_]String{};
    }

    var tokens = try std.ArrayList(String).initCapacity(allocator, 0);
    errdefer {
        for (tokens.items) |token| {
            allocator.free(token);
        }
        tokens.deinit(allocator);
    }

    var start: ?usize = null;
    for (string, 0..) |c, i| {
        if (isAsciiWhitespace(c)) {
            if (start) |s| {
                const token = try allocator.alloc(u16, i - s);
                @memcpy(token, string[s..i]);
                try tokens.append(allocator, token);
                start = null;
            }
        } else {
            if (start == null) {
                start = i;
            }
        }
    }

    if (start) |s| {
        const token = try allocator.alloc(u16, string.len - s);
        @memcpy(token, string[s..]);
        try tokens.append(allocator, token);
    }

    return tokens.toOwnedSlice(allocator);
}

pub fn splitOnCommas(allocator: Allocator, string: String) ![]String {
    if (string.len == 0) {
        return &[_]String{};
    }

    var tokens = try std.ArrayList(String).initCapacity(allocator, 0);
    errdefer {
        for (tokens.items) |token| {
            allocator.free(token);
        }
        tokens.deinit(allocator);
    }

    var start: usize = 0;
    for (string, 0..) |c, i| {
        if (c == ',') {
            const stripped = try stripLeadingAndTrailingAsciiWhitespace(allocator, string[start..i]);
            try tokens.append(allocator, stripped);
            start = i + 1;
        }
    }

    const last = try stripLeadingAndTrailingAsciiWhitespace(allocator, string[start..]);
    try tokens.append(allocator, last);

    return tokens.toOwnedSlice(allocator);
}

pub fn concatenate(allocator: Allocator, strings: []const String) !String {
    var total_len: usize = 0;
    for (strings) |s| {
        total_len += s.len;
    }

    if (total_len == 0) {
        return &[_]u16{};
    }

    const result = try allocator.alloc(u16, total_len);
    var pos: usize = 0;
    for (strings) |s| {
        @memcpy(result[pos .. pos + s.len], s);
        pos += s.len;
    }

    return result;
}

test "utf8ToUtf16 - empty string" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "utf8ToUtf16 - ASCII string" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "hello");
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "utf8ToUtf16 - Unicode BMP" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "héllo");
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "utf8ToUtf16 - Unicode with surrogate pairs" {
    const allocator = std.testing.allocator;
    const result = try utf8ToUtf16(allocator, "💩");
    defer allocator.free(result);

    const expected = [_]u16{ 0xD83D, 0xDCA9 };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "utf8ToUtf16 - invalid UTF-8" {
    const allocator = std.testing.allocator;
    const invalid = [_]u8{ 0xFF, 0xFE };
    const result = utf8ToUtf16(allocator, &invalid);
    try std.testing.expectError(InfraError.InvalidUtf8, result);
}

test "utf16ToUtf8 - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "utf16ToUtf8 - ASCII string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("hello", result);
}

test "utf16ToUtf8 - Unicode BMP" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("héllo", result);
}

test "utf16ToUtf8 - surrogate pairs" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 0xD83D, 0xDCA9 };
    const result = try utf16ToUtf8(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("💩", result);
}

test "utf16ToUtf8 - unpaired high surrogate" {
    const allocator = std.testing.allocator;
    const input = [_]u16{0xD83D};
    const result = utf16ToUtf8(allocator, &input);
    try std.testing.expectError(InfraError.InvalidUtf16, result);
}

test "utf16ToUtf8 - unpaired low surrogate" {
    const allocator = std.testing.allocator;
    const input = [_]u16{0xDCA9};
    const result = utf16ToUtf8(allocator, &input);
    try std.testing.expectError(InfraError.InvalidUtf16, result);
}

test "conversion roundtrip - ASCII" {
    const allocator = std.testing.allocator;
    const original = "hello world";

    const utf16 = try utf8ToUtf16(allocator, original);
    defer allocator.free(utf16);

    const utf8 = try utf16ToUtf8(allocator, utf16);
    defer allocator.free(utf8);

    try std.testing.expectEqualStrings(original, utf8);
}

test "conversion roundtrip - Unicode" {
    const allocator = std.testing.allocator;
    const original = "hello 世界 💩";

    const utf16 = try utf8ToUtf16(allocator, original);
    defer allocator.free(utf16);

    const utf8 = try utf16ToUtf8(allocator, utf16);
    defer allocator.free(utf8);

    try std.testing.expectEqualStrings(original, utf8);
}

test "asciiLowercase - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "asciiLowercase - ASCII uppercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiLowercase - mixed case" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'e', 'L', 'l', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiLowercase - already lowercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiLowercase - non-ASCII unchanged" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 0x00E9, 'L', 'L', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiUppercase - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try asciiUppercase(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "asciiUppercase - ASCII lowercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiUppercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "asciiUppercase - mixed case" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'e', 'L', 'l', 'O' };
    const result = try asciiUppercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "isAsciiString - pure ASCII" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiString(&input));
}

test "isAsciiString - contains Unicode" {
    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    try std.testing.expect(!isAsciiString(&input));
}

test "isAsciiString - empty string" {
    const input = [_]u16{};
    try std.testing.expect(isAsciiString(&input));
}

test "isAsciiCaseInsensitiveMatch - match same case" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiCaseInsensitiveMatch(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - match different case" {
    const a = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expect(isAsciiCaseInsensitiveMatch(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - no match" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expect(!isAsciiCaseInsensitiveMatch(&a, &b));
}

test "isAsciiCaseInsensitiveMatch - different lengths" {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l' };
    try std.testing.expect(!isAsciiCaseInsensitiveMatch(&a, &b));
}

test "asciiByteLength - ASCII string" {
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try asciiByteLength(&input);
    try std.testing.expectEqual(@as(usize, 5), result);
}

test "asciiByteLength - non-ASCII error" {
    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o' };
    const result = asciiByteLength(&input);
    try std.testing.expectError(InfraError.InvalidCodePoint, result);
}

test "asciiByteLength - beyond byte range" {
    const input = [_]u16{ 'h', 0x0100, 'l', 'l', 'o' };
    const result = asciiByteLength(&input);
    try std.testing.expectError(InfraError.InvalidCodePoint, result);
}

test "isAsciiWhitespace - tab" {
    try std.testing.expect(isAsciiWhitespace(0x0009));
}

test "isAsciiWhitespace - newline" {
    try std.testing.expect(isAsciiWhitespace(0x000A));
}

test "isAsciiWhitespace - form feed" {
    try std.testing.expect(isAsciiWhitespace(0x000C));
}

test "isAsciiWhitespace - carriage return" {
    try std.testing.expect(isAsciiWhitespace(0x000D));
}

test "isAsciiWhitespace - space" {
    try std.testing.expect(isAsciiWhitespace(0x0020));
}

test "isAsciiWhitespace - non-whitespace" {
    try std.testing.expect(!isAsciiWhitespace('a'));
    try std.testing.expect(!isAsciiWhitespace('Z'));
    try std.testing.expect(!isAsciiWhitespace('0'));
}

test "stripLeadingAndTrailingAsciiWhitespace - both ends" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', '\t', 'h', 'e', 'l', 'l', 'o', ' ', '\n' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - leading only" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', '\t', 'h', 'e', 'l', 'l', 'o' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - trailing only" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', '\n' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - none" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripLeadingAndTrailingAsciiWhitespace - all whitespace" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ ' ', '\t', '\n' };
    const result = try stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
    defer allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "stripNewlines - LF and CR" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', '\n', 'l', 'l', '\r', 'o' };
    const result = try stripNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "stripNewlines - no newlines" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const result = try stripNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "normalizeNewlines - CRLF to LF" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i', '\r', '\n', 't', 'h', 'e', 'r', 'e' };
    const result = try normalizeNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "normalizeNewlines - CR to LF" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i', '\r', 't', 'h', 'e', 'r', 'e' };
    const result = try normalizeNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "normalizeNewlines - LF unchanged" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    const result = try normalizeNewlines(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'i', '\n', 't', 'h', 'e', 'r', 'e' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "splitOnAsciiWhitespace - single space" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 2), result.len);

    const expected1 = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{ 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);
}

test "splitOnAsciiWhitespace - multiple spaces" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ' ', ' ', 'b', ' ', 'c' };
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "splitOnAsciiWhitespace - mixed whitespace" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', '\t', 'b', '\n', 'c' };
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);
}

test "splitOnAsciiWhitespace - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try splitOnAsciiWhitespace(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "splitOnCommas - basic" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ',', 'b', ',', 'c' };
    const result = try splitOnCommas(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "splitOnCommas - with whitespace" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'a', ' ', ',', ' ', 'b', ' ', ',', ' ', 'c' };
    const result = try splitOnCommas(allocator, &input);
    defer {
        for (result) |token| {
            allocator.free(token);
        }
        allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 3), result.len);

    const expected1 = [_]u16{'a'};
    try std.testing.expectEqualSlices(u16, &expected1, result[0]);

    const expected2 = [_]u16{'b'};
    try std.testing.expectEqualSlices(u16, &expected2, result[1]);

    const expected3 = [_]u16{'c'};
    try std.testing.expectEqualSlices(u16, &expected3, result[2]);
}

test "splitOnCommas - empty string" {
    const allocator = std.testing.allocator;
    const input = [_]u16{};
    const result = try splitOnCommas(allocator, &input);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}

test "concatenate - multiple strings" {
    const allocator = std.testing.allocator;

    const str1 = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const str2 = [_]u16{' '};
    const str3 = [_]u16{ 'w', 'o', 'r', 'l', 'd' };

    const strings = [_]String{ &str1, &str2, &str3 };
    const result = try concatenate(allocator, &strings);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}

test "concatenate - empty list" {
    const allocator = std.testing.allocator;
    const strings = [_]String{};
    const result = try concatenate(allocator, &strings);
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 0), result.len);
}
