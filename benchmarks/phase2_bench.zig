const std = @import("std");
const infra = @import("infra");
const string = infra.string;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Phase 2: String Operations Benchmarks ===\n\n", .{});

    // indexOf benchmarks (character search)
    try benchIndexOfChar(allocator);
    try benchIndexOfCharLong(allocator);
    try benchIndexOfCharNotFound(allocator);

    // eql benchmarks (string equality)
    try benchEqlShort(allocator);
    try benchEqlLong(allocator);
    try benchEqlLongNotEqual(allocator);

    // contains benchmarks (substring search - to be implemented)
    try benchContainsShort(allocator);
    try benchContainsLong(allocator);
    try benchContainsNotFound(allocator);

    // ASCII string operations (existing - measure baseline)
    try benchIsAsciiShort(allocator);
    try benchIsAsciiLong(allocator);
    try benchAsciiLowercase(allocator);
    try benchAsciiUppercase(allocator);

    std.debug.print("\n=== Phase 2 Benchmarks Complete ===\n", .{});
}

// ===== indexOf Benchmarks =====

fn benchIndexOfChar(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    const utf8_str = "hello world!";
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const needle: u16 = 'o';

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.indexOf(infra_str, needle);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("indexOf (char, short 12 chars):  {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchIndexOfCharLong(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    // 256 character string
    const utf8_str = "a" ** 128 ++ "b" ** 127 ++ "x";
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const needle: u16 = 'x';

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.indexOf(infra_str, needle);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("indexOf (char, long 256 chars):  {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchIndexOfCharNotFound(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    const utf8_str = "a" ** 128 ++ "b" ** 128;
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const needle: u16 = 'x';

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.indexOf(infra_str, needle);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("indexOf (char, not found):       {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

// ===== eql Benchmarks =====

fn benchEqlShort(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    const utf8_str = "hello world!";
    const str1 = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(str1);
    const str2 = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(str2);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.eql(str1, str2);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("eql (short 12 chars, equal):     {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchEqlLong(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    const utf8_str = "a" ** 128 ++ "b" ** 128;
    const str1 = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(str1);
    const str2 = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(str2);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.eql(str1, str2);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("eql (long 256 chars, equal):     {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchEqlLongNotEqual(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    const utf8_str1 = "a" ** 128 ++ "b" ** 128;
    const utf8_str2 = "a" ** 128 ++ "b" ** 127 ++ "x";
    const str1 = try string.utf8ToUtf16(allocator, utf8_str1);
    defer allocator.free(str1);
    const str2 = try string.utf8ToUtf16(allocator, utf8_str2);
    defer allocator.free(str2);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.eql(str1, str2);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("eql (long 256 chars, not equal): {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

// ===== contains Benchmarks (substring search - placeholder) =====

fn benchContainsShort(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    const utf8_str = "hello world!";
    const utf8_needle = "world";
    const haystack = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(haystack);
    const needle = try string.utf8ToUtf16(allocator, utf8_needle);
    defer allocator.free(needle);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        // Placeholder: contains() not yet implemented
        // Using naive search for baseline
        const result = naiveContains(haystack, needle);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("contains (short, found):         {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchContainsLong(allocator: std.mem.Allocator) !void {
    const iterations: usize = 100_000;

    const utf8_str = "a" ** 200 ++ "needle" ++ "b" ** 50;
    const utf8_needle = "needle";
    const haystack = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(haystack);
    const needle = try string.utf8ToUtf16(allocator, utf8_needle);
    defer allocator.free(needle);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = naiveContains(haystack, needle);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("contains (long, found):          {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchContainsNotFound(allocator: std.mem.Allocator) !void {
    const iterations: usize = 100_000;

    const utf8_str = "a" ** 128 ++ "b" ** 128;
    const utf8_needle = "needle";
    const haystack = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(haystack);
    const needle = try string.utf8ToUtf16(allocator, utf8_needle);
    defer allocator.free(needle);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = naiveContains(haystack, needle);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("contains (long, not found):      {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

// ===== ASCII Operations Benchmarks =====

fn benchIsAsciiShort(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    const utf8_str = "hello world!";
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.isAsciiString(infra_str);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("isAsciiString (short 12 chars):  {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchIsAsciiLong(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    const utf8_str = "a" ** 128 ++ "b" ** 128;
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = string.isAsciiString(infra_str);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("isAsciiString (long 256 chars):  {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchAsciiLowercase(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    const utf8_str = "HELLO WORLD! TESTING ASCII LOWERCASE CONVERSION";
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try string.asciiLowercase(allocator, infra_str);
        allocator.free(result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("asciiLowercase (48 chars):       {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchAsciiUppercase(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    const utf8_str = "hello world! testing ascii uppercase conversion";
    const infra_str = try string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try string.asciiUppercase(allocator, infra_str);
        allocator.free(result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("asciiUppercase (48 chars):       {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

// ===== Helper Functions =====

fn naiveContains(haystack: string.String, needle: string.String) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;

    const max_start = haystack.len - needle.len;
    var start: usize = 0;
    while (start <= max_start) : (start += 1) {
        var matches = true;
        for (needle, 0..) |n, i| {
            if (haystack[start + i] != n) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }
    return false;
}
