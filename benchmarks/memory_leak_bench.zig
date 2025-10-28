const std = @import("std");
const infra = @import("infra");
const List = infra.List;
const OrderedMap = infra.OrderedMap;
const OrderedSet = infra.OrderedSet;
const Stack = infra.Stack;
const Queue = infra.Queue;

const DURATION_SECONDS = 120;
const WARMUP_SECONDS = 5;

fn intensiveListWorkload(allocator: std.mem.Allocator) !void {
    var list = List(u32).init(allocator);
    defer list.deinit();

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try list.append(i);
    }

    while (list.size() > 0) {
        _ = try list.remove(0);
    }

    i = 0;
    while (i < 50) : (i += 1) {
        try list.prepend(i);
    }

    var cloned = try list.clone();
    defer cloned.deinit();

    list.sort(struct {
        fn lessThan(a: u32, b: u32) bool {
            return a < b;
        }
    }.lessThan);
}

fn intensiveMapWorkload(allocator: std.mem.Allocator) !void {
    var map = OrderedMap([]const u8, u64).init(allocator);
    defer map.deinit();

    var i: u64 = 0;
    while (i < 50) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key_{d}", .{i});
        defer allocator.free(key);
        try map.set(key, i * 100);
    }

    i = 0;
    while (i < 25) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "key_{d}", .{i});
        defer allocator.free(key);
        _ = map.remove(key);
    }

    const keys = [_][]const u8{ "test1", "test2", "test3" };
    for (keys) |key| {
        try map.set(key, 999);
    }

    var cloned = try map.clone();
    defer cloned.deinit();
}

fn intensiveSetWorkload(allocator: std.mem.Allocator) !void {
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        _ = try set.add(i);
    }

    i = 0;
    while (i < 50) : (i += 1) {
        _ = set.remove(i);
    }

    var cloned = try set.clone();
    defer cloned.deinit();
}

fn intensiveStackWorkload(allocator: std.mem.Allocator) !void {
    var stack = Stack(u32).init(allocator);
    defer stack.deinit();

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try stack.push(i);
    }

    while (!stack.isEmpty()) {
        _ = stack.pop();
    }
}

fn intensiveQueueWorkload(allocator: std.mem.Allocator) !void {
    var queue = Queue(u32).init(allocator);
    defer queue.deinit();

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try queue.enqueue(i);
    }

    while (!queue.isEmpty()) {
        _ = queue.dequeue();
    }
}

fn intensiveStringWorkload(allocator: std.mem.Allocator) !void {
    const test_string = "Hello, World! This is a test string with Unicode: 你好世界 🌍";

    const utf16 = try infra.string.utf8ToUtf16(allocator, test_string);
    defer allocator.free(utf16);

    const utf8_back = try infra.string.utf16ToUtf8(allocator, utf16);
    defer allocator.free(utf8_back);

    const ascii_test = try infra.string.utf8ToUtf16(allocator, "Hello World");
    defer allocator.free(ascii_test);

    const lowercased = try infra.string.asciiLowercase(allocator, ascii_test);
    defer allocator.free(lowercased);

    const uppercased = try infra.string.asciiUppercase(allocator, ascii_test);
    defer allocator.free(uppercased);

    const whitespace_test = try infra.string.utf8ToUtf16(allocator, "  test  ");
    defer allocator.free(whitespace_test);

    const stripped = try infra.string.stripLeadingAndTrailingAsciiWhitespace(allocator, whitespace_test);
    defer allocator.free(stripped);

    const newline_test = try infra.string.utf8ToUtf16(allocator, "line1\r\nline2\r\nline3");
    defer allocator.free(newline_test);

    const normalized = try infra.string.normalizeNewlines(allocator, newline_test);
    defer allocator.free(normalized);

    const split_test = try infra.string.utf8ToUtf16(allocator, "one two three four five");
    defer allocator.free(split_test);

    const split = try infra.string.splitOnAsciiWhitespace(allocator, split_test);
    defer {
        for (split) |s| allocator.free(s);
        allocator.free(split);
    }
}

fn intensiveJsonWorkload(allocator: std.mem.Allocator) !void {
    const json_string =
        \\{
        \\  "name": "test",
        \\  "age": 30,
        \\  "active": true,
        \\  "tags": ["one", "two", "three"],
        \\  "metadata": {
        \\    "created": 1234567890,
        \\    "updated": 9876543210
        \\  }
        \\}
    ;

    var parsed = try infra.json.parseJsonString(allocator, json_string);
    defer parsed.deinit(allocator);

    const serialized = try infra.json.serializeInfraValue(allocator, parsed);
    defer allocator.free(serialized);
}

fn intensiveBase64Workload(allocator: std.mem.Allocator) !void {
    const data = "This is some test data that will be base64 encoded and decoded multiple times to stress test memory allocation patterns.";

    const encoded = try infra.base64.forgivingBase64Encode(allocator, data);
    defer allocator.free(encoded);

    const decoded = try infra.base64.forgivingBase64Decode(allocator, encoded);
    defer allocator.free(decoded);

    const with_whitespace = try std.fmt.allocPrint(allocator, "  {s}  \n  ", .{encoded});
    defer allocator.free(with_whitespace);

    const decoded_forgiving = try infra.base64.forgivingBase64Decode(allocator, with_whitespace);
    defer allocator.free(decoded_forgiving);
}

fn runAllWorkloads(allocator: std.mem.Allocator) !void {
    try intensiveListWorkload(allocator);
    try intensiveMapWorkload(allocator);
    try intensiveSetWorkload(allocator);
    try intensiveStackWorkload(allocator);
    try intensiveQueueWorkload(allocator);
    try intensiveStringWorkload(allocator);
    try intensiveJsonWorkload(allocator);
    try intensiveBase64Workload(allocator);
}

pub fn main() !void {
    std.debug.print("\n=== Memory Leak Benchmark ===\n\n", .{});
    std.debug.print("Duration: {} seconds of intensive workload\n", .{DURATION_SECONDS});
    std.debug.print("Warmup: {} seconds\n\n", .{WARMUP_SECONDS});
    std.debug.print("This benchmark tests long-term memory stability by creating and\n", .{});
    std.debug.print("destroying Infra types repeatedly. Memory should return to baseline\n", .{});
    std.debug.print("after the workload completes, verified by GPA leak detection.\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n❌ FAIL: Memory leaks detected by GPA!\n", .{});
        } else {
            std.debug.print("\n✅ SUCCESS: No memory leaks detected by GPA!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    std.debug.print("Phase 1: Warmup ({} seconds)\n", .{WARMUP_SECONDS});
    const warmup_start = std.time.milliTimestamp();
    var warmup_iterations: usize = 0;
    while (std.time.milliTimestamp() - warmup_start < WARMUP_SECONDS * 1000) {
        try runAllWorkloads(allocator);
        warmup_iterations += 1;
    }
    std.debug.print("Completed {} warmup iterations\n\n", .{warmup_iterations});

    std.debug.print("Phase 2: Intensive Workload ({} seconds)\n", .{DURATION_SECONDS});
    std.debug.print("Running continuous create/destroy cycles...\n\n", .{});

    const start_time = std.time.milliTimestamp();
    var iterations: usize = 0;
    var last_report = start_time;

    while (std.time.milliTimestamp() - start_time < DURATION_SECONDS * 1000) {
        try runAllWorkloads(allocator);
        iterations += 1;

        const now = std.time.milliTimestamp();
        if (now - last_report >= 10000) {
            const elapsed_seconds = @divTrunc(now - start_time, 1000);
            std.debug.print(
                "[{d:3}s] Completed {d:8} iterations\n",
                .{ elapsed_seconds, iterations },
            );
            last_report = now;
        }
    }

    const end_time = std.time.milliTimestamp();
    const actual_duration = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;

    std.debug.print("\n", .{});
    std.debug.print("=== Results ===\n\n", .{});
    std.debug.print("Total iterations: {}\n", .{iterations});
    std.debug.print("Actual duration: {d:.2} seconds\n", .{actual_duration});
    std.debug.print("Iterations per second: {d:.2}\n", .{@as(f64, @floatFromInt(iterations)) / actual_duration});
    std.debug.print("\n", .{});

    std.debug.print("Each iteration performed:\n", .{});
    std.debug.print("  - List: 100 appends, removes, 50 prepends, clone, sort\n", .{});
    std.debug.print("  - OrderedMap: 50 sets, 25 removes, clone (with string keys)\n", .{});
    std.debug.print("  - OrderedSet: 100 adds, 50 removes, clone\n", .{});
    std.debug.print("  - Stack: 100 pushes, 100 pops\n", .{});
    std.debug.print("  - Queue: 100 enqueues, 100 dequeues\n", .{});
    std.debug.print("  - String: UTF-8↔UTF-16, case transforms, splitting\n", .{});
    std.debug.print("  - JSON: Parse/serialize nested structures\n", .{});
    std.debug.print("  - Base64: Encode/decode with forgiving whitespace\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Memory leak check will be performed on exit...\n", .{});
}
