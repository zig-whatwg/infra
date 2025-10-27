const std = @import("std");
const infra = @import("infra");
const base64 = infra.base64;

const ITERATIONS = 100_000;

fn benchmark(name: []const u8, comptime func: fn () anyerror!void) !void {
    const start = std.time.nanoTimestamp();
    try func();
    const end = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const per_op = elapsed / @as(f64, @floatFromInt(ITERATIONS));
    std.debug.print("{s}: {d:.2} ms total, {d:.2} ns/op\n", .{ name, elapsed, per_op });
}

fn benchEncodeSmall() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try base64.forgivingBase64Encode(allocator, &data);
        defer allocator.free(result);
    }
}

fn benchEncodeMedium() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
    };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try base64.forgivingBase64Encode(allocator, &data);
        defer allocator.free(result);
    }
}

fn benchEncodeLarge() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var data: [256]u8 = undefined;
    for (&data, 0..) |*byte, idx| {
        byte.* = @intCast(idx);
    }

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        const result = try base64.forgivingBase64Encode(allocator, &data);
        defer allocator.free(result);
    }
}

fn benchDecodeSmall() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const encoded = "aGVsbG8=";
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try base64.forgivingBase64Decode(allocator, encoded);
        defer allocator.free(result);
    }
}

fn benchDecodeMedium() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const encoded = "AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=";
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try base64.forgivingBase64Decode(allocator, encoded);
        defer allocator.free(result);
    }
}

fn benchDecodeLarge() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const encoded =
        \\AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1
        \\Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWpr
        \\bG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6Ch
        \\oqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX
        \\2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w==
    ;

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        const result = try base64.forgivingBase64Decode(allocator, encoded);
        defer allocator.free(result);
    }
}

fn benchDecodeWithWhitespace() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const encoded = "aGVs bG8 =";
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try base64.forgivingBase64Decode(allocator, encoded);
        defer allocator.free(result);
    }
}

fn benchRoundtripSmall() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    var i: usize = 0;
    while (i < ITERATIONS / 2) : (i += 1) {
        const encoded = try base64.forgivingBase64Encode(allocator, &data);
        defer allocator.free(encoded);
        const decoded = try base64.forgivingBase64Decode(allocator, encoded);
        defer allocator.free(decoded);
    }
}

fn benchRoundtripLarge() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var data: [256]u8 = undefined;
    for (&data, 0..) |*byte, idx| {
        byte.* = @intCast(idx);
    }

    var i: usize = 0;
    while (i < ITERATIONS / 20) : (i += 1) {
        const encoded = try base64.forgivingBase64Encode(allocator, &data);
        defer allocator.free(encoded);
        const decoded = try base64.forgivingBase64Decode(allocator, encoded);
        defer allocator.free(decoded);
    }
}

pub fn main() !void {
    std.debug.print("\n=== Base64 Benchmarks ===\n\n", .{});

    try benchmark("encode (small, 5 bytes)", benchEncodeSmall);
    try benchmark("encode (medium, 32 bytes)", benchEncodeMedium);
    try benchmark("encode (large, 256 bytes)", benchEncodeLarge);
    try benchmark("decode (small, 5 bytes)", benchDecodeSmall);
    try benchmark("decode (medium, 32 bytes)", benchDecodeMedium);
    try benchmark("decode (large, 256 bytes)", benchDecodeLarge);
    try benchmark("decode (with whitespace)", benchDecodeWithWhitespace);
    try benchmark("roundtrip (small, 5 bytes)", benchRoundtripSmall);
    try benchmark("roundtrip (large, 256 bytes)", benchRoundtripLarge);

    std.debug.print("\n", .{});
}
