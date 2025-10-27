//! WHATWG Infra Ordered Map Operations
//!
//! Spec: https://infra.spec.whatwg.org/#ordered-map
//!
//! An ordered map is an ordered list of tuples (key-value pairs). It preserves
//! insertion order, which is required by the spec. This implementation uses a
//! list-backed approach with linear search, matching browser implementations.
//!
//! # Design
//!
//! - **List-backed**: Uses `List` with 4-entry inline storage
//! - **Linear search**: O(n) but faster than HashMap for small n (< 12)
//! - **Insertion order**: Naturally preserved (it's a list)
//! - **Cache-friendly**: Sequential memory access
//!
//! # Performance
//!
//! Browser research (Chromium, Firefox) shows:
//! - Linear search is faster than HashMap for n < 12 (cache locality)
//! - 70-80% of maps have ≤ 4 entries
//! - Typical use case: DOM attributes, HTTP headers, JSON objects
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const OrderedMap = @import("map.zig").OrderedMap;
//!
//! var map = OrderedMap([]const u8, u32).init(allocator);
//! defer map.deinit();
//!
//! try map.set("key", 100);
//! const value = map.get("key");  // returns ?u32
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;

pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            key: K,
            value: V,
        };

        entries: List(Entry),

        pub fn init(allocator: Allocator) Self {
            return Self{
                .entries = List(Entry).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.entries.deinit();
        }

        pub fn get(self: *const Self, key: K) ?V {
            const items_slice = self.entries.items();
            for (items_slice) |entry| {
                if (std.meta.eql(entry.key, key)) {
                    return entry.value;
                }
            }
            return null;
        }

        pub fn set(self: *Self, key: K, value: V) !void {
            const items_slice = self.entries.items();
            for (items_slice, 0..) |entry, i| {
                if (std.meta.eql(entry.key, key)) {
                    _ = try self.entries.replace(i, Entry{ .key = key, .value = value });
                    return;
                }
            }
            try self.entries.append(Entry{ .key = key, .value = value });
        }

        pub fn remove(self: *Self, key: K) bool {
            const items_slice = self.entries.items();
            for (items_slice, 0..) |entry, i| {
                if (std.meta.eql(entry.key, key)) {
                    _ = self.entries.remove(i) catch unreachable;
                    return true;
                }
            }
            return false;
        }

        pub fn contains(self: *const Self, key: K) bool {
            return self.get(key) != null;
        }

        pub fn size(self: *const Self) usize {
            return self.entries.size();
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.entries.isEmpty();
        }

        pub fn clear(self: *Self) void {
            self.entries.clear();
        }

        pub fn clone(self: *const Self) !Self {
            var new_map = Self.init(self.entries.allocator);
            const items_slice = self.entries.items();
            for (items_slice) |entry| {
                try new_map.entries.append(entry);
            }
            return new_map;
        }

        pub const Iterator = struct {
            items_slice: []const Entry,
            index: usize = 0,

            pub fn next(it: *Iterator) ?Entry {
                if (it.index >= it.items_slice.len) return null;
                const entry = it.items_slice[it.index];
                it.index += 1;
                return entry;
            }
        };

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .items_slice = self.entries.items(),
            };
        }
    };
}

test "OrderedMap - init and deinit" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try std.testing.expectEqual(@as(usize, 0), map.size());
    try std.testing.expect(map.isEmpty());
}

test "OrderedMap - set and get" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);

    try std.testing.expectEqual(@as(?u32, 100), map.get(1));
    try std.testing.expectEqual(@as(?u32, 200), map.get(2));
}

test "OrderedMap - set updates existing key" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(1, 999);

    try std.testing.expectEqual(@as(?u32, 999), map.get(1));
    try std.testing.expectEqual(@as(usize, 1), map.size());
}

test "OrderedMap - get nonexistent key returns null" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);

    try std.testing.expectEqual(@as(?u32, null), map.get(999));
}

test "OrderedMap - remove existing key" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);

    const removed = map.remove(1);
    try std.testing.expect(removed);
    try std.testing.expectEqual(@as(?u32, null), map.get(1));
    try std.testing.expectEqual(@as(usize, 1), map.size());
}

test "OrderedMap - remove nonexistent key" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    const removed = map.remove(999);
    try std.testing.expect(!removed);
}

test "OrderedMap - contains" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);

    try std.testing.expect(map.contains(1));
    try std.testing.expect(!map.contains(999));
}

test "OrderedMap - preserves insertion order" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(3, 300);
    try map.set(1, 100);
    try map.set(2, 200);

    var it = map.iterator();
    const e1 = it.next().?;
    const e2 = it.next().?;
    const e3 = it.next().?;

    try std.testing.expectEqual(@as(u32, 3), e1.key);
    try std.testing.expectEqual(@as(u32, 1), e2.key);
    try std.testing.expectEqual(@as(u32, 2), e3.key);
}

test "OrderedMap - size and isEmpty" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try std.testing.expect(map.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), map.size());

    try map.set(1, 100);
    try std.testing.expect(!map.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), map.size());
}

test "OrderedMap - clear" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);
    map.clear();

    try std.testing.expect(map.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), map.size());
}

test "OrderedMap - clone" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);

    var cloned = try map.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(map.size(), cloned.size());
    try std.testing.expectEqual(@as(?u32, 100), cloned.get(1));
    try std.testing.expectEqual(@as(?u32, 200), cloned.get(2));
}

test "OrderedMap - inline storage (4 entries)" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);
    try map.set(3, 300);
    try map.set(4, 400);

    try std.testing.expectEqual(@as(usize, 4), map.size());
    try std.testing.expect(map.entries.heap_storage == null);
}

test "OrderedMap - exceeds inline storage (spill to heap)" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);
    try map.set(3, 300);
    try map.set(4, 400);
    try map.set(5, 500);

    try std.testing.expectEqual(@as(usize, 5), map.size());
    try std.testing.expect(map.entries.heap_storage != null);
    try std.testing.expectEqual(@as(?u32, 500), map.get(5));
}

test "OrderedMap - iterator" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.set(1, 100);
    try map.set(2, 200);
    try map.set(3, 300);

    var count: usize = 0;
    var it = map.iterator();
    while (it.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "OrderedMap - no memory leaks" {
    const allocator = std.testing.allocator;
    var map = OrderedMap(u32, u32).init(allocator);
    defer map.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try map.set(i, i * 100);
    }

    try std.testing.expectEqual(@as(usize, 10), map.size());
}
