//! WHATWG Infra JSON Operations
//!
//! Spec: https://infra.spec.whatwg.org/#json
//!
//! Parse JSON strings into Infra values and serialize Infra values to JSON.

const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const OrderedMap = @import("map.zig").OrderedMap;
const List = @import("list.zig").List;

pub const InfraValue = union(enum) {
    null_value,
    boolean: bool,
    number: f64,
    string: String,
    list: *List(*InfraValue),
    map: *OrderedMap(String, *InfraValue),

    pub fn deinit(self: *InfraValue, allocator: Allocator) void {
        switch (self.*) {
            .null_value, .boolean, .number => {},
            .string => |s| allocator.free(s),
            .list => |l| {
                for (l.items()) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                l.deinit();
                allocator.destroy(l);
            },
            .map => |m| {
                var it = m.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key);
                    entry.value.deinit(allocator);
                    allocator.destroy(entry.value);
                }
                m.deinit();
                allocator.destroy(m);
            },
        }
    }
};

pub const JsonError = error{
    InvalidJson,
    OutOfMemory,
};

pub fn parseJsonString(allocator: Allocator, json_string: []const u8) !InfraValue {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_string, .{});
    defer parsed.deinit();

    return try jsonValueToInfra(allocator, parsed.value);
}

fn jsonValueToInfra(allocator: Allocator, value: std.json.Value) !InfraValue {
    return switch (value) {
        .null => .null_value,
        .bool => |b| .{ .boolean = b },
        .integer => |i| .{ .number = @floatFromInt(i) },
        .float => |f| .{ .number = f },
        .number_string => |_| JsonError.InvalidJson,
        .string => |s| blk: {
            const string_module = @import("string.zig");
            const utf16_string = try string_module.utf8ToUtf16(allocator, s);
            break :blk .{ .string = utf16_string };
        },
        .array => |arr| blk: {
            const list_ptr = try allocator.create(List(*InfraValue));
            list_ptr.* = List(*InfraValue).init(allocator);
            errdefer {
                for (list_ptr.items()) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                list_ptr.deinit();
                allocator.destroy(list_ptr);
            }

            try list_ptr.ensureCapacity(arr.items.len);

            for (arr.items) |item| {
                const infra_item_ptr = try allocator.create(InfraValue);
                errdefer allocator.destroy(infra_item_ptr);
                infra_item_ptr.* = try jsonValueToInfra(allocator, item);
                errdefer infra_item_ptr.deinit(allocator);
                try list_ptr.append(infra_item_ptr);
            }

            break :blk .{ .list = list_ptr };
        },
        .object => |obj| blk: {
            const map_ptr = try allocator.create(OrderedMap(String, *InfraValue));
            map_ptr.* = OrderedMap(String, *InfraValue).init(allocator);
            errdefer {
                var it = map_ptr.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key);
                    entry.value.deinit(allocator);
                    allocator.destroy(entry.value);
                }
                map_ptr.deinit();
                allocator.destroy(map_ptr);
            }

            var it = obj.iterator();
            while (it.next()) |entry| {
                const string_module = @import("string.zig");
                const key = try string_module.utf8ToUtf16(allocator, entry.key_ptr.*);
                errdefer allocator.free(key);
                const val_ptr = try allocator.create(InfraValue);
                errdefer allocator.destroy(val_ptr);
                val_ptr.* = try jsonValueToInfra(allocator, entry.value_ptr.*);
                errdefer val_ptr.deinit(allocator);
                try map_ptr.set(key, val_ptr);
            }

            break :blk .{ .map = map_ptr };
        },
    };
}

pub fn serializeInfraValue(allocator: Allocator, value: InfraValue) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 0);
    errdefer result.deinit(allocator);

    try serializeValue(allocator, &result, value);

    return result.toOwnedSlice(allocator);
}

fn serializeValue(allocator: Allocator, writer: *std.ArrayList(u8), value: InfraValue) !void {
    switch (value) {
        .null_value => try writer.appendSlice(allocator, "null"),
        .boolean => |b| {
            if (b) {
                try writer.appendSlice(allocator, "true");
            } else {
                try writer.appendSlice(allocator, "false");
            }
        },
        .number => |n| {
            var buf: [64]u8 = undefined;
            const s = try std.fmt.bufPrint(&buf, "{d}", .{n});
            try writer.appendSlice(allocator, s);
        },
        .string => |s| {
            const string_module = @import("string.zig");
            const utf8_string = try string_module.utf16ToUtf8(allocator, s);
            defer allocator.free(utf8_string);

            try writer.append(allocator, '"');
            for (utf8_string) |c| {
                switch (c) {
                    '"' => try writer.appendSlice(allocator, "\\\""),
                    '\\' => try writer.appendSlice(allocator, "\\\\"),
                    '\n' => try writer.appendSlice(allocator, "\\n"),
                    '\r' => try writer.appendSlice(allocator, "\\r"),
                    '\t' => try writer.appendSlice(allocator, "\\t"),
                    else => try writer.append(allocator, c),
                }
            }
            try writer.append(allocator, '"');
        },
        .list => |l| {
            try writer.append(allocator, '[');
            const items_slice = l.items();
            for (items_slice, 0..) |item, i| {
                if (i > 0) try writer.append(allocator, ',');
                try serializeValue(allocator, writer, item.*);
            }
            try writer.append(allocator, ']');
        },
        .map => |m| {
            try writer.append(allocator, '{');
            var it = m.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try writer.append(allocator, ',');
                first = false;

                try serializeValue(allocator, writer, .{ .string = entry.key });
                try writer.append(allocator, ':');
                try serializeValue(allocator, writer, entry.value.*);
            }
            try writer.append(allocator, '}');
        },
    }
}

test "parseJson - null" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "null");
    defer result.deinit(allocator);

    try std.testing.expect(result == .null_value);
}

test "parseJson - boolean true" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "true");
    defer result.deinit(allocator);

    try std.testing.expect(result == .boolean);
    try std.testing.expect(result.boolean == true);
}

test "parseJson - boolean false" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "false");
    defer result.deinit(allocator);

    try std.testing.expect(result == .boolean);
    try std.testing.expect(result.boolean == false);
}

test "parseJson - number integer" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "42");
    defer result.deinit(allocator);

    try std.testing.expect(result == .number);
    try std.testing.expectEqual(@as(f64, 42.0), result.number);
}

test "parseJson - number float" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "3.14");
    defer result.deinit(allocator);

    try std.testing.expect(result == .number);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), result.number, 0.001);
}

test "parseJson - string ASCII" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "\"hello\"");
    defer result.deinit(allocator);

    try std.testing.expect(result == .string);
    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result.string);
}

test "parseJson - array empty" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "[]");
    defer result.deinit(allocator);

    try std.testing.expect(result == .list);
    try std.testing.expectEqual(@as(usize, 0), result.list.size());
}

test "parseJson - array mixed types" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "[1, \"hello\", true, null]");
    defer result.deinit(allocator);

    try std.testing.expect(result == .list);
    try std.testing.expectEqual(@as(usize, 4), result.list.size());
}

test "parseJson - object empty" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "{}");
    defer result.deinit(allocator);

    try std.testing.expect(result == .map);
    try std.testing.expectEqual(@as(usize, 0), result.map.size());
}

test "parseJson - object simple" {
    const allocator = std.testing.allocator;
    var result = try parseJsonString(allocator, "{\"name\":\"Alice\",\"age\":30}");
    defer result.deinit(allocator);

    try std.testing.expect(result == .map);
    try std.testing.expectEqual(@as(usize, 2), result.map.size());
}

test "serializeJson - null" {
    const allocator = std.testing.allocator;
    const value = InfraValue.null_value;
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("null", result);
}

test "serializeJson - boolean true" {
    const allocator = std.testing.allocator;
    const value = InfraValue{ .boolean = true };
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("true", result);
}

test "serializeJson - boolean false" {
    const allocator = std.testing.allocator;
    const value = InfraValue{ .boolean = false };
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("false", result);
}

test "serializeJson - number" {
    const allocator = std.testing.allocator;
    const value = InfraValue{ .number = 42.0 };
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("42", result);
}

test "serializeJson - string" {
    const allocator = std.testing.allocator;
    const str = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    const value = InfraValue{ .string = &str };
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("\"hello\"", result);
}

test "serializeJson - array empty" {
    const allocator = std.testing.allocator;
    const list_ptr = try allocator.create(List(*InfraValue));
    list_ptr.* = List(*InfraValue).init(allocator);
    defer {
        list_ptr.deinit();
        allocator.destroy(list_ptr);
    }

    const value = InfraValue{ .list = list_ptr };
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("[]", result);
}

test "serializeJson - object empty" {
    const allocator = std.testing.allocator;
    const map_ptr = try allocator.create(OrderedMap(String, *InfraValue));
    map_ptr.* = OrderedMap(String, *InfraValue).init(allocator);
    defer {
        map_ptr.deinit();
        allocator.destroy(map_ptr);
    }

    const value = InfraValue{ .map = map_ptr };
    const result = try serializeInfraValue(allocator, value);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("{}", result);
}
