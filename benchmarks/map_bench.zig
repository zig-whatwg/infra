const std = @import("std");
const infra = @import("infra");
const OrderedMap = infra.OrderedMap;

const ITERATIONS = 1_000_000;

fn benchmark(name: []const u8, comptime func: fn () anyerror!void) !void {
    const start = std.time.nanoTimestamp();
    try func();
    const end = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const per_op = elapsed / @as(f64, @floatFromInt(ITERATIONS));
    std.debug.print("{s}: {d:.2} ms total, {d:.2} ns/op\n", .{ name, elapsed, per_op });
}

fn benchMapSetSmall() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var map = OrderedMap(u32, u32).init(allocator);
        defer map.deinit();
        try map.set(1, 100);
        try map.set(2, 200);
        try map.set(3, 300);
    }
}

fn benchMapSetLarge() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        var map = OrderedMap(u32, u32).init(allocator);
        defer map.deinit();
        var j: u32 = 0;
        while (j < 20) : (j += 1) {
            try map.set(j, j * 100);
        }
    }
}

fn benchMapGet() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();
    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try map.set(j, j * 100);
    }

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        _ = map.get(5);
    }
}

fn benchMapContains() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();
    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try map.set(j, j * 100);
    }

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        _ = map.contains(5);
    }
}

fn benchMapRemove() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var map = OrderedMap(u32, u32).init(allocator);
        defer map.deinit();
        try map.set(1, 100);
        try map.set(2, 200);
        try map.set(3, 300);
        _ = map.remove(2);
    }
}

fn benchMapIteration() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();
    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try map.set(j, j * 100);
    }

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        var it = map.iterator();
        while (it.next()) |entry| {
            _ = entry;
        }
    }
}

fn benchMapClone() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();
    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try map.set(j, j * 100);
    }

    var i: usize = 0;
    while (i < ITERATIONS / 100) : (i += 1) {
        var cloned = try map.clone();
        defer cloned.deinit();
    }
}

fn benchMapStringKey() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const keys = [_][]const u8{ "foo", "bar", "baz", "qux" };

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        var map = OrderedMap([]const u8, u32).init(allocator);
        defer map.deinit();
        for (keys, 0..) |key, idx| {
            try map.set(key, @intCast(idx));
        }
    }
}

pub fn main() !void {
    std.debug.print("\n=== OrderedMap Benchmarks ===\n\n", .{});

    try benchmark("set (small, 3 entries)", benchMapSetSmall);
    try benchmark("set (large, 20 entries)", benchMapSetLarge);
    try benchmark("get (10 entries)", benchMapGet);
    try benchmark("contains (10 entries)", benchMapContains);
    try benchmark("remove (3 entries)", benchMapRemove);
    try benchmark("iteration (10 entries)", benchMapIteration);
    try benchmark("clone (10 entries)", benchMapClone);
    try benchmark("string keys (4 entries)", benchMapStringKey);

    std.debug.print("\n", .{});
}
