const std = @import("std");
const infra = @import("infra");
const OrderedMap = infra.OrderedMap;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== Phase 3: Advanced Optimizations Benchmarks ===\n\n", .{});

    // OrderedMap benchmarks (linear vs hash table threshold)
    try benchMapSetSmall(allocator);
    try benchMapSetMedium(allocator);
    try benchMapSetLarge(allocator);
    try benchMapGetSmall(allocator);
    try benchMapGetMedium(allocator);
    try benchMapGetLarge(allocator);
    try benchMapContainsSmall(allocator);
    try benchMapContainsMedium(allocator);
    try benchMapContainsLarge(allocator);

    // String concatenation benchmarks
    try benchConcatTwo(allocator);
    try benchConcatMany(allocator);
    try benchConcatManyWithSeparator(allocator);

    std.debug.print("\n=== Phase 3 Benchmarks Complete ===\n", .{});
}

// ===== OrderedMap Benchmarks =====

fn benchMapSetSmall(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var map = OrderedMap(u32, u32).init(allocator);
        defer map.deinit();

        // 5 items (well under threshold of 12)
        try map.set(1, 100);
        try map.set(2, 200);
        try map.set(3, 300);
        try map.set(4, 400);
        try map.set(5, 500);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap set (5 items):    {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapSetMedium(allocator: std.mem.Allocator) !void {
    const iterations: usize = 100_000;

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var map = OrderedMap(u32, u32).init(allocator);
        defer map.deinit();

        // 12 items (at threshold)
        var j: u32 = 0;
        while (j < 12) : (j += 1) {
            try map.set(j, j * 100);
        }
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap set (12 items):   {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapSetLarge(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000;

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var map = OrderedMap(u32, u32).init(allocator);
        defer map.deinit();

        // 100 items (well over threshold)
        var j: u32 = 0;
        while (j < 100) : (j += 1) {
            try map.set(j, j * 100);
        }
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap set (100 items):  {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapGetSmall(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    // 5 items
    try map.set(1, 100);
    try map.set(2, 200);
    try map.set(3, 300);
    try map.set(4, 400);
    try map.set(5, 500);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = map.get(3);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap get (5 items):    {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapGetMedium(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    // 12 items
    var j: u32 = 0;
    while (j < 12) : (j += 1) {
        try map.set(j, j * 100);
    }

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = map.get(6);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap get (12 items):   {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapGetLarge(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    // 100 items
    var j: u32 = 0;
    while (j < 100) : (j += 1) {
        try map.set(j, j * 100);
    }

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = map.get(50);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap get (100 items):  {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapContainsSmall(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    // 5 items
    try map.set(1, 100);
    try map.set(2, 200);
    try map.set(3, 300);
    try map.set(4, 400);
    try map.set(5, 500);

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = map.contains(3);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap contains (5):     {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapContainsMedium(allocator: std.mem.Allocator) !void {
    const iterations: usize = 10_000_000;

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    // 12 items
    var j: u32 = 0;
    while (j < 12) : (j += 1) {
        try map.set(j, j * 100);
    }

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = map.contains(6);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap contains (12):    {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchMapContainsLarge(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    // 100 items
    var j: u32 = 0;
    while (j < 100) : (j += 1) {
        try map.set(j, j * 100);
    }

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = map.contains(50);
        std.mem.doNotOptimizeAway(&result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("OrderedMap contains (100):   {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

// ===== String Concatenation Benchmarks =====

fn benchConcatTwo(allocator: std.mem.Allocator) !void {
    const iterations: usize = 1_000_000;
    const string = infra.string;

    const str1 = try string.utf8ToUtf16(allocator, "hello");
    defer allocator.free(str1);
    const str2 = try string.utf8ToUtf16(allocator, "world");
    defer allocator.free(str2);

    const strings = [_]infra.String{ str1, str2 };

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try string.concatenate(allocator, &strings, null);
        allocator.free(result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("concat (2 strings):          {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchConcatMany(allocator: std.mem.Allocator) !void {
    const iterations: usize = 100_000;
    const string = infra.string;

    const str1 = try string.utf8ToUtf16(allocator, "one");
    defer allocator.free(str1);
    const str2 = try string.utf8ToUtf16(allocator, "two");
    defer allocator.free(str2);
    const str3 = try string.utf8ToUtf16(allocator, "three");
    defer allocator.free(str3);
    const str4 = try string.utf8ToUtf16(allocator, "four");
    defer allocator.free(str4);
    const str5 = try string.utf8ToUtf16(allocator, "five");
    defer allocator.free(str5);

    const strings = [_]infra.String{ str1, str2, str3, str4, str5 };

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try string.concatenate(allocator, &strings, null);
        allocator.free(result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("concat (5 strings):          {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}

fn benchConcatManyWithSeparator(allocator: std.mem.Allocator) !void {
    const iterations: usize = 100_000;
    const string = infra.string;

    const str1 = try string.utf8ToUtf16(allocator, "one");
    defer allocator.free(str1);
    const str2 = try string.utf8ToUtf16(allocator, "two");
    defer allocator.free(str2);
    const str3 = try string.utf8ToUtf16(allocator, "three");
    defer allocator.free(str3);
    const str4 = try string.utf8ToUtf16(allocator, "four");
    defer allocator.free(str4);
    const str5 = try string.utf8ToUtf16(allocator, "five");
    defer allocator.free(str5);
    const sep = try string.utf8ToUtf16(allocator, ",");
    defer allocator.free(sep);

    const strings = [_]infra.String{ str1, str2, str3, str4, str5 };

    const start = std.time.milliTimestamp();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try string.concatenate(allocator, &strings, sep);
        allocator.free(result);
    }
    const end = std.time.milliTimestamp();
    const elapsed = end - start;

    const ns_per_op = @as(f64, @floatFromInt(elapsed)) * 1_000_000.0 / @as(f64, @floatFromInt(iterations));
    std.debug.print("concat (5 strings, sep):     {d:6.2}ms total, {d:6.2} ns/op\n", .{ elapsed, ns_per_op });
}
