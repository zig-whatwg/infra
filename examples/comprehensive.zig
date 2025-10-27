//! Comprehensive usage example demonstrating all major Infra features

const std = @import("std");
const infra = @import("infra");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== WHATWG Infra for Zig - Comprehensive Example ===\n\n", .{});

    try stringsExample(allocator);
    try collectionsExample(allocator);
    try jsonExample(allocator);
    try base64Example(allocator);

    std.debug.print("\n=== All examples completed successfully! ===\n", .{});
}

fn stringsExample(allocator: std.mem.Allocator) !void {
    std.debug.print("--- String Operations ---\n", .{});

    const utf8_str = "Hello, 世界! 🌍";
    const infra_str = try infra.string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);

    const lower = try infra.string.asciiLowercase(allocator, infra_str);
    defer allocator.free(lower);

    const back_to_utf8 = try infra.string.utf16ToUtf8(allocator, lower);
    defer allocator.free(back_to_utf8);

    std.debug.print("  Original: {s}\n", .{utf8_str});
    std.debug.print("  Lowercased: {s}\n", .{back_to_utf8});

    const text = "  hello  world  ";
    const text_utf16 = try infra.string.utf8ToUtf16(allocator, text);
    defer allocator.free(text_utf16);

    const stripped = try infra.string.stripLeadingAndTrailingAsciiWhitespace(allocator, text_utf16);
    defer allocator.free(stripped);

    const stripped_utf8 = try infra.string.utf16ToUtf8(allocator, stripped);
    defer allocator.free(stripped_utf8);

    std.debug.print("  Stripped: '{s}'\n\n", .{stripped_utf8});
}

fn collectionsExample(allocator: std.mem.Allocator) !void {
    std.debug.print("--- Collections ---\n", .{});

    var list = infra.List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.prepend(0);

    std.debug.print("  List: ", .{});
    for (list.items()) |item| {
        std.debug.print("{} ", .{item});
    }
    std.debug.print("\n", .{});

    var map = infra.OrderedMap([]const u8, u32).init(allocator);
    defer map.deinit();

    try map.set("first", 1);
    try map.set("second", 2);
    try map.set("third", 3);

    std.debug.print("  Map (preserves insertion order):\n", .{});
    var it = map.iterator();
    while (it.next()) |entry| {
        std.debug.print("    {s} = {}\n", .{ entry.key, entry.value });
    }

    var set = infra.OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(10);
    _ = try set.add(20);
    _ = try set.add(10);

    std.debug.print("  Set (no duplicates): size = {}\n", .{set.size()});

    var stack = infra.Stack(u32).init(allocator);
    defer stack.deinit();

    try stack.push(1);
    try stack.push(2);
    try stack.push(3);

    std.debug.print("  Stack (LIFO): {} {} {}\n\n", .{
        stack.pop().?,
        stack.pop().?,
        stack.pop().?,
    });
}

fn jsonExample(allocator: std.mem.Allocator) !void {
    std.debug.print("--- JSON Operations ---\n", .{});

    const json_str =
        \\{
        \\  "name": "Alice",
        \\  "age": 30,
        \\  "active": true,
        \\  "scores": [95, 87, 92]
        \\}
    ;

    std.debug.print("  Parsing JSON...\n", .{});
    var value = try infra.json.parseJsonString(allocator, json_str);
    defer value.deinit(allocator);

    std.debug.print("  Parsed successfully!\n", .{});

    if (value == .map) {
        const name_key = try infra.string.utf8ToUtf16(allocator, "name");
        defer allocator.free(name_key);

        if (value.map.get(name_key)) |name_ptr| {
            if (name_ptr.* == .string) {
                const name_utf8 = try infra.string.utf16ToUtf8(allocator, name_ptr.string);
                defer allocator.free(name_utf8);
                std.debug.print("  Name: {s}\n", .{name_utf8});
            }
        }

        const age_key = try infra.string.utf8ToUtf16(allocator, "age");
        defer allocator.free(age_key);

        if (value.map.get(age_key)) |age_ptr| {
            if (age_ptr.* == .number) {
                std.debug.print("  Age: {d}\n", .{age_ptr.number});
            }
        }
    }

    const serialized = try infra.json.serializeInfraValue(allocator, value);
    defer allocator.free(serialized);

    std.debug.print("  Serialized: {s}\n\n", .{serialized});
}

fn base64Example(allocator: std.mem.Allocator) !void {
    std.debug.print("--- Base64 Operations ---\n", .{});

    const data = "Hello, World!";
    std.debug.print("  Original: {s}\n", .{data});

    const encoded = try infra.base64.forgivingBase64Encode(allocator, data);
    defer allocator.free(encoded);

    std.debug.print("  Encoded: {s}\n", .{encoded});

    const with_whitespace = "SGVs bG8s IFdv cmxk IQ==";
    const decoded = try infra.base64.forgivingBase64Decode(allocator, with_whitespace);
    defer allocator.free(decoded);

    std.debug.print("  Decoded (forgiving): {s}\n", .{decoded});

    std.debug.print("  HTML namespace: {s}\n", .{infra.namespaces.HTML_NAMESPACE});
    std.debug.print("  SVG namespace: {s}\n\n", .{infra.namespaces.SVG_NAMESPACE});
}
