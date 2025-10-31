const std = @import("std");
const infra = @import("infra");
const List = infra.List;
const OrderedMap = infra.OrderedMap;
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

// ============================================================================
// List Batch Operations Benchmarks
// ============================================================================

fn benchListAppendSliceInline() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const items = [_]u32{ 1, 2, 3 }; // All fit in inline storage (4 capacity)

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.appendSlice(&items);
    }
}

fn benchListAppendSliceMixed() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const items = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }; // Mixed inline/heap

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.appendSlice(&items);
    }
}

fn benchListAppendSliceHeap() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const items = [_]u32{
        1,  2,  3,  4,  5,  6,  7,  8,  9,  10,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    };

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.appendSlice(&items);
    }
}

// Compare appendSlice vs multiple append calls
fn benchListMultipleAppends() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.append(1);
        try list.append(2);
        try list.append(3);
        try list.append(4);
        try list.append(5);
        try list.append(6);
        try list.append(7);
        try list.append(8);
        try list.append(9);
        try list.append(10);
    }
}

// ============================================================================
// String Comparison (eql) Benchmarks
// ============================================================================

fn benchStringEqlShortEqual() !void {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'h', 'e', 'l', 'l', 'o' };

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.eql(&a, &b);
    }
}

fn benchStringEqlShortUnequal() !void {
    const a = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const b = [_]u16{ 'w', 'o', 'r', 'l', 'd' };

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.eql(&a, &b);
    }
}

fn benchStringEqlLongEqual() !void {
    // 64 characters - long enough to benefit from SIMD
    const a = [_]u16{
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ',
        'a', ' ', 'l', 'o', 'n', 'g', ' ', 's',
        't', 'r', 'i', 'n', 'g', ' ', 't', 'h',
        'a', 't', ' ', 'i', 's', ' ', 'u', 's',
        'e', 'd', ' ', 't', 'o', ' ', 't', 'e',
        's', 't', ' ', 'S', 'I', 'M', 'D', ' ',
        'o', 'p', 't', 'i', 'm', 'i', 'z', 'a',
        't', 'i', 'o', 'n', 's', ' ', '!', '!',
    };
    const b = [_]u16{
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ',
        'a', ' ', 'l', 'o', 'n', 'g', ' ', 's',
        't', 'r', 'i', 'n', 'g', ' ', 't', 'h',
        'a', 't', ' ', 'i', 's', ' ', 'u', 's',
        'e', 'd', ' ', 't', 'o', ' ', 't', 'e',
        's', 't', ' ', 'S', 'I', 'M', 'D', ' ',
        'o', 'p', 't', 'i', 'm', 'i', 'z', 'a',
        't', 'i', 'o', 'n', 's', ' ', '!', '!',
    };

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.eql(&a, &b);
    }
}

fn benchStringEqlLongDifferAtEnd() !void {
    const a = [_]u16{
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ',
        'a', ' ', 'l', 'o', 'n', 'g', ' ', 's',
        't', 'r', 'i', 'n', 'g', ' ', 't', 'h',
        'a', 't', ' ', 'i', 's', ' ', 'u', 's',
        'e', 'd', ' ', 't', 'o', ' ', 't', 'e',
        's', 't', ' ', 'S', 'I', 'M', 'D', ' ',
        'o', 'p', 't', 'i', 'm', 'i', 'z', 'a',
        't', 'i', 'o', 'n', 's', ' ', '!', '!',
    };
    const b = [_]u16{
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ',
        'a', ' ', 'l', 'o', 'n', 'g', ' ', 's',
        't', 'r', 'i', 'n', 'g', ' ', 't', 'h',
        'a', 't', ' ', 'i', 's', ' ', 'u', 's',
        'e', 'd', ' ', 't', 'o', ' ', 't', 'e',
        's', 't', ' ', 'S', 'I', 'M', 'D', ' ',
        'o', 'p', 't', 'i', 'm', 'i', 'z', 'a',
        't', 'i', 'o', 'n', 's', ' ', '?', '?', // Different at end
    };

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.eql(&a, &b);
    }
}

// ============================================================================
// String indexOf Benchmarks (basic)
// ============================================================================

fn benchStringIndexOfCharShort() !void {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    const needle: u16 = 'w';

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.indexOf(&haystack, needle);
    }
}

fn benchStringIndexOfCharLong() !void {
    const haystack = [_]u16{
        'T', 'h', 'i', 's', ' ', 'i', 's', ' ',
        'a', ' ', 'l', 'o', 'n', 'g', ' ', 's',
        't', 'r', 'i', 'n', 'g', ' ', 't', 'h',
        'a', 't', ' ', 'i', 's', ' ', 'u', 's',
        'e', 'd', ' ', 't', 'o', ' ', 't', 'e',
        's', 't', ' ', 'S', 'I', 'M', 'D', ' ',
        'o', 'p', 't', 'i', 'm', 'i', 'z', 'a',
        't', 'i', 'o', 'n', 's', ' ', '!', '!',
    };
    const needle: u16 = '!';

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.indexOf(&haystack, needle);
    }
}

fn benchStringIndexOfCharNotFound() !void {
    const haystack = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    const needle: u16 = 'z';

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.indexOf(&haystack, needle);
    }
}

// ============================================================================
// ASCII Detection (standalone) Benchmarks
// ============================================================================

fn benchIsAsciiShort() !void {
    const input = "hello world";

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.isAscii(input);
    }
}

fn benchIsAsciiMedium() !void {
    const input = "This is a medium length ASCII string for testing SIMD detection!";

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.isAscii(input);
    }
}

fn benchIsAsciiLong() !void {
    const input = "This is a very long ASCII string that should benefit from SIMD optimizations when checking if all bytes are within the ASCII range. It contains multiple cache lines worth of data to properly stress test the vectorized implementation.";

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.isAscii(input);
    }
}

fn benchIsAsciiNonAscii() !void {
    const input = "This has Unicode: 世界";

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = string.isAscii(input);
    }
}

// ============================================================================
// Map Key Type Specialization Benchmarks
// ============================================================================

fn benchMapGetIntegerKey() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try map.set(j, j * 10);
    }

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = map.get(5);
    }
}

fn benchMapGetStringKey() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = OrderedMap([]const u8, u32).init(allocator);
    defer map.deinit();

    try map.set("key0", 0);
    try map.set("key1", 1);
    try map.set("key2", 2);
    try map.set("key3", 3);
    try map.set("key4", 4);
    try map.set("key5", 5);
    try map.set("key6", 6);
    try map.set("key7", 7);
    try map.set("key8", 8);
    try map.set("key9", 9);

    var i: usize = 0;
    while (i < ITERATIONS * 10) : (i += 1) {
        _ = map.get("key5");
    }
}

pub fn main() !void {
    std.debug.print("\n=== Phase 1 Benchmarks (Missing Operations) ===\n\n", .{});

    std.debug.print("--- List Batch Operations ---\n", .{});
    try benchmark("appendSlice (3 items, inline)", benchListAppendSliceInline);
    try benchmark("appendSlice (10 items, mixed)", benchListAppendSliceMixed);
    try benchmark("appendSlice (20 items, heap)", benchListAppendSliceHeap);
    try benchmark("multiple appends (10 calls)", benchListMultipleAppends);

    std.debug.print("\n--- String Comparison (eql) ---\n", .{});
    try benchmark("eql (short, equal)", benchStringEqlShortEqual);
    try benchmark("eql (short, unequal)", benchStringEqlShortUnequal);
    try benchmark("eql (long 64 chars, equal)", benchStringEqlLongEqual);
    try benchmark("eql (long 64 chars, differ at end)", benchStringEqlLongDifferAtEnd);

    std.debug.print("\n--- String indexOf ---\n", .{});
    try benchmark("indexOf (char, short string)", benchStringIndexOfCharShort);
    try benchmark("indexOf (char, long string)", benchStringIndexOfCharLong);
    try benchmark("indexOf (char, not found)", benchStringIndexOfCharNotFound);

    std.debug.print("\n--- ASCII Detection ---\n", .{});
    try benchmark("isAscii (short, 11 chars)", benchIsAsciiShort);
    try benchmark("isAscii (medium, 64 chars)", benchIsAsciiMedium);
    try benchmark("isAscii (long, 256 chars)", benchIsAsciiLong);
    try benchmark("isAscii (non-ASCII, fail fast)", benchIsAsciiNonAscii);

    std.debug.print("\n--- Map Key Type Specialization ---\n", .{});
    try benchmark("get (integer key)", benchMapGetIntegerKey);
    try benchmark("get (string key)", benchMapGetStringKey);

    std.debug.print("\n", .{});
}
