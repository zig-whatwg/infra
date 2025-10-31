const std = @import("std");
const infra = @import("infra");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n❌ MEMORY LEAK DETECTED!\n", .{});
            std.process.exit(1);
        }
    }
    const allocator = gpa.allocator();

    std.debug.print("\n=== 2-Minute Memory Stress Test ===\n", .{});
    std.debug.print("Creating and destroying all Infra types rapidly...\n\n", .{});

    const start_time = std.time.milliTimestamp();
    const duration_ms: i64 = 120_000; // 2 minutes

    var iteration: usize = 0;

    while (std.time.milliTimestamp() - start_time < duration_ms) {
        iteration += 1;

        // List operations
        try stressList(allocator);

        // OrderedMap operations
        try stressOrderedMap(allocator);

        // OrderedSet operations
        try stressOrderedSet(allocator);

        // Stack operations
        try stressStack(allocator);

        // Queue operations
        try stressQueue(allocator);

        // String operations
        try stressString(allocator);

        // Bytes operations
        try stressBytes(allocator);

        // JSON operations
        try stressJson(allocator);

        // Base64 operations
        try stressBase64(allocator);

        // Progress indicator every 1000 iterations
        if (iteration % 1000 == 0) {
            const elapsed = std.time.milliTimestamp() - start_time;
            const remaining = duration_ms - elapsed;
            std.debug.print("Iteration {d:6} | Elapsed: {d:3}s | Remaining: {d:3}s\n", .{
                iteration,
                @divTrunc(elapsed, 1000),
                @divTrunc(remaining, 1000),
            });
        }
    }

    const total_time = std.time.milliTimestamp() - start_time;
    std.debug.print("\n=== Stress Test Complete ===\n", .{});
    std.debug.print("Total iterations: {d}\n", .{iteration});
    std.debug.print("Total time: {d}ms ({d}s)\n", .{ total_time, @divTrunc(total_time, 1000) });
    std.debug.print("Iterations per second: {d}\n", .{@divTrunc(iteration * 1000, @as(usize, @intCast(total_time)))});
    std.debug.print("\n✅ Memory returned to baseline (no leaks detected)\n", .{});
}

fn stressList(allocator: std.mem.Allocator) !void {
    // Test different capacity configurations
    var list0 = infra.ListWithCapacity(u32, 0).init(allocator);
    defer list0.deinit();
    try list0.append(1);
    try list0.append(2);
    try list0.append(3);

    var list4 = infra.List(u32).init(allocator);
    defer list4.deinit();
    try list4.append(10);
    try list4.append(20);
    try list4.append(30);
    try list4.append(40);
    try list4.append(50);

    var list16 = infra.ListWithCapacity(u32, 16).init(allocator);
    defer list16.deinit();
    for (0..20) |i| {
        try list16.append(@intCast(i));
    }

    // Test batch operations
    const slice = [_]u32{ 100, 200, 300 };
    try list4.appendSlice(&slice);

    // Test other operations
    _ = list4.get(0);
    _ = list4.contains(20);
    _ = try list4.remove(1);
    _ = try list4.replace(0, 999);
    var cloned = try list4.clone();
    defer cloned.deinit();
    list4.clear();
}

fn stressOrderedMap(allocator: std.mem.Allocator) !void {
    // Integer keys
    var map_int = infra.OrderedMap(u32, u32).init(allocator);
    defer map_int.deinit();
    for (0..50) |i| {
        try map_int.set(@intCast(i), @intCast(i * 100));
    }
    _ = map_int.get(25);
    _ = map_int.contains(30);
    _ = map_int.remove(10);
    var cloned_int = try map_int.clone();
    defer cloned_int.deinit();
    map_int.clear();

    // String keys
    var map_str = infra.OrderedMap([]const u8, u32).init(allocator);
    defer map_str.deinit();
    try map_str.set("key1", 100);
    try map_str.set("key2", 200);
    try map_str.set("key3", 300);
    _ = map_str.get("key2");
    _ = map_str.contains("key1");
    _ = map_str.remove("key3");
}

fn stressOrderedSet(allocator: std.mem.Allocator) !void {
    var set = infra.OrderedSet(u32).init(allocator);
    defer set.deinit();
    for (0..30) |i| {
        try set.append(@intCast(i));
    }
    _ = set.contains(15);
    _ = set.remove(10);
    var cloned = try set.clone();
    defer cloned.deinit();
    set.clear();
}

fn stressStack(allocator: std.mem.Allocator) !void {
    var stack = infra.Stack(u32).init(allocator);
    defer stack.deinit();
    for (0..20) |i| {
        try stack.push(@intCast(i));
    }
    while (!stack.isEmpty()) {
        _ = stack.pop();
    }
}

fn stressQueue(allocator: std.mem.Allocator) !void {
    var queue = infra.Queue(u32).init(allocator);
    defer queue.deinit();
    for (0..20) |i| {
        try queue.enqueue(@intCast(i));
    }
    while (!queue.isEmpty()) {
        _ = queue.dequeue();
    }
}

fn stressString(allocator: std.mem.Allocator) !void {
    // UTF-8 to UTF-16 conversion
    const str1 = try infra.string.utf8ToUtf16(allocator, "Hello, World! 你好世界 🌍");
    defer allocator.free(str1);

    const str2 = try infra.string.utf8ToUtf16(allocator, "Testing string operations");
    defer allocator.free(str2);

    // UTF-16 to UTF-8 conversion
    const utf8_back = try infra.string.utf16ToUtf8(allocator, str1);
    defer allocator.free(utf8_back);

    // String operations
    _ = infra.string.indexOf(str2, 'i');
    _ = infra.string.eql(str1, str2);
    _ = infra.string.contains(str2, str1);
    _ = infra.string.isAsciiString(str2);

    // ASCII operations
    const upper = try infra.string.asciiUppercase(allocator, str2);
    defer allocator.free(upper);

    const lower = try infra.string.asciiLowercase(allocator, str2);
    defer allocator.free(lower);

    // Whitespace operations
    const with_ws = try infra.string.utf8ToUtf16(allocator, "  hello  ");
    defer allocator.free(with_ws);

    const stripped = try infra.string.stripLeadingAndTrailingAsciiWhitespace(allocator, with_ws);
    defer allocator.free(stripped);

    // Split operations
    const to_split = try infra.string.utf8ToUtf16(allocator, "one,two,three");
    defer allocator.free(to_split);

    const split_result = try infra.string.splitOnCommas(allocator, to_split);
    defer {
        for (split_result) |part| {
            allocator.free(part);
        }
        allocator.free(split_result);
    }

    // Concatenation
    const strings = [_]infra.String{ str1, str2 };
    const sep = try infra.string.utf8ToUtf16(allocator, " | ");
    defer allocator.free(sep);

    const concat = try infra.string.concatenate(allocator, &strings, sep);
    defer allocator.free(concat);
}

fn stressBytes(allocator: std.mem.Allocator) !void {
    const data = "Hello, bytes!";

    const lower = try infra.bytes.byteLowercase(allocator, data);
    defer allocator.free(lower);

    const upper = try infra.bytes.byteUppercase(allocator, data);
    defer allocator.free(upper);

    _ = infra.bytes.byteCaseInsensitiveMatch("HELLO", "hello");
    _ = infra.bytes.isPrefix("Hel", "Hello");

    // Isomorphic encode/decode
    const str = try infra.string.utf8ToUtf16(allocator, "Test");
    defer allocator.free(str);

    const encoded = try infra.bytes.isomorphicEncode(allocator, str);
    defer allocator.free(encoded);

    const decoded = try infra.bytes.isomorphicDecode(allocator, encoded);
    defer allocator.free(decoded);
}

fn stressJson(allocator: std.mem.Allocator) !void {
    // Parse various JSON structures
    var null_json = try infra.json.parseJsonString(allocator, "null");
    defer null_json.deinit(allocator);

    var bool_json = try infra.json.parseJsonString(allocator, "true");
    defer bool_json.deinit(allocator);

    var number_json = try infra.json.parseJsonString(allocator, "42.5");
    defer number_json.deinit(allocator);

    var string_json = try infra.json.parseJsonString(allocator, "\"hello\"");
    defer string_json.deinit(allocator);

    var array_json = try infra.json.parseJsonString(allocator, "[1,2,3]");
    defer array_json.deinit(allocator);

    var object_json = try infra.json.parseJsonString(allocator, "{\"key\":\"value\"}");
    defer object_json.deinit(allocator);

    // Serialize back
    const serialized = try infra.json.serializeInfraValue(allocator, object_json);
    defer allocator.free(serialized);

    // Complex nested structure
    var complex_json = try infra.json.parseJsonString(
        allocator,
        "{\"users\":[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}],\"count\":2}",
    );
    defer complex_json.deinit(allocator);
}

fn stressBase64(allocator: std.mem.Allocator) !void {
    const data1 = "Hello, World!";
    const encoded1 = try infra.base64.forgivingBase64Encode(allocator, data1);
    defer allocator.free(encoded1);

    const decoded1 = try infra.base64.forgivingBase64Decode(allocator, encoded1);
    defer allocator.free(decoded1);

    // Different sizes
    const data2 = "A";
    const encoded2 = try infra.base64.forgivingBase64Encode(allocator, data2);
    defer allocator.free(encoded2);

    const decoded2 = try infra.base64.forgivingBase64Decode(allocator, encoded2);
    defer allocator.free(decoded2);

    const data3 = "This is a longer string that needs more base64 encoding space";
    const encoded3 = try infra.base64.forgivingBase64Encode(allocator, data3);
    defer allocator.free(encoded3);

    const decoded3 = try infra.base64.forgivingBase64Decode(allocator, encoded3);
    defer allocator.free(decoded3);
}
