const std = @import("std");
const infra = @import("infra");
const string = infra.string;

const ITERATIONS = 100_000;

fn benchmark(name: []const u8, comptime func: fn () anyerror!void) !void {
    const start = std.time.nanoTimestamp();
    try func();
    const end = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const per_op = elapsed / @as(f64, @floatFromInt(ITERATIONS));
    std.debug.print("{s}: {d:.2} ms total, {d:.2} ns/op\n", .{ name, elapsed, per_op });
}

fn benchUtf8ToUtf16Ascii() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = "hello world this is a test string";
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.utf8ToUtf16(allocator, input);
        defer allocator.free(result);
    }
}

fn benchUtf8ToUtf16Unicode() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = "héllo wörld 世界 💩";
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.utf8ToUtf16(allocator, input);
        defer allocator.free(result);
    }
}

fn benchUtf16ToUtf8Ascii() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.utf16ToUtf8(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchUtf16ToUtf8Unicode() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'h', 0x00E9, 'l', 'l', 'o', ' ', 0xD83D, 0xDCA9 };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.utf16ToUtf8(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchAsciiLowercase() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.asciiLowercase(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchAsciiUppercase() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.asciiUppercase(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchIsAsciiCaseInsensitiveMatch() !void {
    const a = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.isAsciiCaseInsensitiveMatch(&a, &b);
    }
}

fn benchStripWhitespace() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ ' ', '\t', 'h', 'e', 'l', 'l', 'o', ' ', '\n' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.stripLeadingAndTrailingAsciiWhitespace(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchStripNewlines() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'h', 'e', '\n', 'l', 'l', '\r', 'o', '\n' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.stripNewlines(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchNormalizeNewlines() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'h', 'i', '\r', '\n', 't', 'h', 'e', 'r', 'e', '\r', 'n', 'o', 'w' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.normalizeNewlines(allocator, &input);
        defer allocator.free(result);
    }
}

fn benchSplitOnWhitespace() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', '\t', 'f', 'o', 'o' };
    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        const result = try string.splitOnAsciiWhitespace(allocator, &input);
        defer {
            for (result) |token| {
                allocator.free(token);
            }
            allocator.free(result);
        }
    }
}

fn benchSplitOnCommas() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = [_]u16{ 'a', ',', 'b', ',', 'c', ',', 'd' };
    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        const result = try string.splitOnCommas(allocator, &input);
        defer {
            for (result) |token| {
                allocator.free(token);
            }
            allocator.free(result);
        }
    }
}

fn benchConcatenate() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const str1 = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const str2 = [_]u16{' '};
    const str3 = [_]u16{ 'w', 'o', 'r', 'l', 'd' };
    const strings = [_][]const u16{ &str1, &str2, &str3 };

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try string.concatenate(allocator, &strings, null);
        defer allocator.free(result);
    }
}

pub fn main() !void {
    std.debug.print("\n=== String Benchmarks ===\n\n", .{});

    try benchmark("utf8ToUtf16 (ASCII)", benchUtf8ToUtf16Ascii);
    try benchmark("utf8ToUtf16 (Unicode)", benchUtf8ToUtf16Unicode);
    try benchmark("utf16ToUtf8 (ASCII)", benchUtf16ToUtf8Ascii);
    try benchmark("utf16ToUtf8 (Unicode)", benchUtf16ToUtf8Unicode);
    try benchmark("asciiLowercase", benchAsciiLowercase);
    try benchmark("asciiUppercase", benchAsciiUppercase);
    try benchmark("isAsciiCaseInsensitiveMatch", benchIsAsciiCaseInsensitiveMatch);
    try benchmark("stripWhitespace", benchStripWhitespace);
    try benchmark("stripNewlines", benchStripNewlines);
    try benchmark("normalizeNewlines", benchNormalizeNewlines);
    try benchmark("splitOnWhitespace", benchSplitOnWhitespace);
    try benchmark("splitOnCommas", benchSplitOnCommas);
    try benchmark("concatenate", benchConcatenate);

    std.debug.print("\n", .{});
}
