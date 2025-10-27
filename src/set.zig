//! WHATWG Infra Ordered Set Operations
//!
//! Spec: https://infra.spec.whatwg.org/#ordered-set
//!
//! An ordered set is a list that contains no duplicates and preserves
//! insertion order.

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;

pub fn OrderedSet(comptime T: type) type {
    return struct {
        const Self = @This();

        items_list: List(T),

        pub fn init(allocator: Allocator) Self {
            return Self{
                .items_list = List(T).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.items_list.deinit();
        }

        pub fn add(self: *Self, item: T) !bool {
            if (self.contains(item)) {
                return false;
            }
            try self.items_list.append(item);
            return true;
        }

        pub fn remove(self: *Self, item: T) bool {
            const items_slice = self.items_list.items();
            for (items_slice, 0..) |elem, i| {
                if (std.meta.eql(elem, item)) {
                    _ = self.items_list.remove(i) catch unreachable;
                    return true;
                }
            }
            return false;
        }

        pub fn contains(self: *const Self, item: T) bool {
            return self.items_list.contains(item);
        }

        pub fn size(self: *const Self) usize {
            return self.items_list.size();
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items_list.isEmpty();
        }

        pub fn clear(self: *Self) void {
            self.items_list.clear();
        }

        pub fn clone(self: *const Self) !Self {
            var new_set = Self.init(self.items_list.allocator);
            const items_slice = self.items_list.items();
            for (items_slice) |item| {
                try new_set.items_list.append(item);
            }
            return new_set;
        }

        pub const Iterator = struct {
            items_slice: []const T,
            index: usize = 0,

            pub fn next(it: *Iterator) ?T {
                if (it.index >= it.items_slice.len) return null;
                const item = it.items_slice[it.index];
                it.index += 1;
                return item;
            }
        };

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .items_slice = self.items_list.items(),
            };
        }
    };
}

test "OrderedSet - init and deinit" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.size());
    try std.testing.expect(set.isEmpty());
}

test "OrderedSet - add unique items" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    const added1 = try set.add(1);
    const added2 = try set.add(2);

    try std.testing.expect(added1);
    try std.testing.expect(added2);
    try std.testing.expectEqual(@as(usize, 2), set.size());
}

test "OrderedSet - add duplicate (no-op)" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    const added = try set.add(1);

    try std.testing.expect(!added);
    try std.testing.expectEqual(@as(usize, 1), set.size());
}

test "OrderedSet - remove existing item" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);

    const removed = set.remove(1);
    try std.testing.expect(removed);
    try std.testing.expect(!set.contains(1));
    try std.testing.expectEqual(@as(usize, 1), set.size());
}

test "OrderedSet - remove nonexistent item (no-op)" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    const removed = set.remove(999);
    try std.testing.expect(!removed);
}

test "OrderedSet - contains" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);

    try std.testing.expect(set.contains(1));
    try std.testing.expect(!set.contains(999));
}

test "OrderedSet - preserves insertion order" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(3);
    _ = try set.add(1);
    _ = try set.add(2);

    var it = set.iterator();
    try std.testing.expectEqual(@as(?u32, 3), it.next());
    try std.testing.expectEqual(@as(?u32, 1), it.next());
    try std.testing.expectEqual(@as(?u32, 2), it.next());
    try std.testing.expectEqual(@as(?u32, null), it.next());
}

test "OrderedSet - clear" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    set.clear();

    try std.testing.expect(set.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), set.size());
}

test "OrderedSet - clone" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);

    var cloned = try set.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(set.size(), cloned.size());
    try std.testing.expect(cloned.contains(1));
    try std.testing.expect(cloned.contains(2));
}

test "OrderedSet - no memory leaks" {
    const allocator = std.testing.allocator;
    var set = OrderedSet(u32).init(allocator);
    defer set.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        _ = try set.add(i);
    }

    try std.testing.expectEqual(@as(usize, 10), set.size());
}
