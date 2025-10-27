const std = @import("std");
const infra = @import("infra");
const json = infra.json;

const ITERATIONS = 10_000;

fn benchmark(name: []const u8, comptime func: fn () anyerror!void) !void {
    const start = std.time.nanoTimestamp();
    try func();
    const end = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const per_op = elapsed / @as(f64, @floatFromInt(ITERATIONS));
    std.debug.print("{s}: {d:.2} ms total, {d:.2} ns/op\n", .{ name, elapsed, per_op });
}

fn benchParseNull() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var result = try json.parseJsonString(allocator, "null");
        defer result.deinit(allocator);
    }
}

fn benchParseBoolean() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var result = try json.parseJsonString(allocator, "true");
        defer result.deinit(allocator);
    }
}

fn benchParseNumber() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var result = try json.parseJsonString(allocator, "42.5");
        defer result.deinit(allocator);
    }
}

fn benchParseString() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var result = try json.parseJsonString(allocator, "\"hello world\"");
        defer result.deinit(allocator);
    }
}

fn benchParseArraySmall() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var result = try json.parseJsonString(allocator, "[1, 2, 3]");
        defer result.deinit(allocator);
    }
}

fn benchParseArrayLarge() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        var result = try json.parseJsonString(allocator, "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]");
        defer result.deinit(allocator);
    }
}

fn benchParseObjectSmall() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var result = try json.parseJsonString(allocator, "{\"name\":\"Alice\",\"age\":30}");
        defer result.deinit(allocator);
    }
}

fn benchParseObjectLarge() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const large_json =
        \\{"name":"Alice","age":30,"city":"NYC","active":true,"score":95.5,
        \\"tags":["foo","bar","baz"],"meta":{"key1":"val1","key2":"val2"}}
    ;

    var i: usize = 0;
    while (i < ITERATIONS / 10) : (i += 1) {
        var result = try json.parseJsonString(allocator, large_json);
        defer result.deinit(allocator);
    }
}

fn benchSerializeNull() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const value = json.InfraValue.null_value;
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try json.serializeInfraValue(allocator, value);
        defer allocator.free(result);
    }
}

fn benchSerializeBoolean() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const value = json.InfraValue{ .boolean = true };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try json.serializeInfraValue(allocator, value);
        defer allocator.free(result);
    }
}

fn benchSerializeNumber() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const value = json.InfraValue{ .number = 42.5 };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try json.serializeInfraValue(allocator, value);
        defer allocator.free(result);
    }
}

fn benchSerializeString() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const str = [_]u16{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' };
    const value = json.InfraValue{ .string = &str };
    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        const result = try json.serializeInfraValue(allocator, value);
        defer allocator.free(result);
    }
}

pub fn main() !void {
    std.debug.print("\n=== JSON Benchmarks ===\n\n", .{});

    try benchmark("parse null", benchParseNull);
    try benchmark("parse boolean", benchParseBoolean);
    try benchmark("parse number", benchParseNumber);
    try benchmark("parse string", benchParseString);
    try benchmark("parse array (small, 3 items)", benchParseArraySmall);
    try benchmark("parse array (large, 20 items)", benchParseArrayLarge);
    try benchmark("parse object (small, 2 keys)", benchParseObjectSmall);
    try benchmark("parse object (large, nested)", benchParseObjectLarge);
    try benchmark("serialize null", benchSerializeNull);
    try benchmark("serialize boolean", benchSerializeBoolean);
    try benchmark("serialize number", benchSerializeNumber);
    try benchmark("serialize string", benchSerializeString);

    std.debug.print("\n", .{});
}
