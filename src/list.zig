//! WHATWG Infra List Operations
//!
//! Spec: https://infra.spec.whatwg.org/#list
//! WHATWG Infra Standard §5.1 lines 828-908
//!
//! A list is an ordered sequence of items. This implementation uses
//! 4-element inline storage (stack-allocated) before spilling to heap,
//! matching browser implementations (Chromium WTF::Vector, Firefox mozilla::Vector).
//!
//! # Design
//!
//! - **Inline storage**: First 4 elements stored on stack (70-80% hit rate)
//! - **Heap fallback**: Allocates on heap when capacity > 4
//! - **Cache-friendly**: 4 elements fit in single cache line (64 bytes)
//!
//! # Usage
//!
//! ```zig
//! const std = @import("std");
//! const List = @import("list.zig").List;
//!
//! var list = List(u32).init(allocator);
//! defer list.deinit();
//!
//! try list.append(42);
//! try list.prepend(10);
//! const item = list.get(0);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn List(comptime T: type) type {
    return ListWithCapacity(T, 4);
}

pub fn ListWithCapacity(comptime T: type, comptime inline_capacity: usize) type {
    return struct {
        const Self = @This();

        inline_storage: if (inline_capacity > 0) [inline_capacity]T else void = if (inline_capacity > 0) undefined else {},
        heap_storage: ?std.ArrayList(T) = null,
        len: usize = 0,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.heap_storage) |*heap| {
                heap.deinit(self.allocator);
            }
        }

        pub fn append(self: *Self, item: T) !void {
            if (comptime inline_capacity > 0) {
                if (self.len < inline_capacity) {
                    self.inline_storage[self.len] = item;
                    self.len += 1;
                    return;
                }
            }
            try self.ensureHeap();
            try self.heap_storage.?.append(self.allocator, item);
            self.len += 1;
        }

        /// Append multiple items at once (batch operation).
        /// More efficient than calling append() in a loop.
        pub fn appendSlice(self: *Self, slice: []const T) !void {
            if (comptime inline_capacity > 0) {
                if (self.len + slice.len <= inline_capacity) {
                    // Fast path: all fit in inline storage
                    @memcpy(
                        self.inline_storage[self.len..][0..slice.len],
                        slice,
                    );
                    self.len += slice.len;
                    return;
                } else if (self.len < inline_capacity) {
                    // Mixed: some in inline, rest in heap
                    const inline_space = inline_capacity - self.len;
                    @memcpy(
                        self.inline_storage[self.len..][0..inline_space],
                        slice[0..inline_space],
                    );
                    self.len = inline_capacity;

                    try self.ensureHeap();
                    try self.heap_storage.?.appendSlice(self.allocator, slice[inline_space..]);
                    self.len += slice.len - inline_space;
                    return;
                }
            }
            // All in heap
            try self.ensureHeap();
            try self.heap_storage.?.appendSlice(self.allocator, slice);
            self.len += slice.len;
        }

        pub fn prepend(self: *Self, item: T) !void {
            try self.insert(0, item);
        }

        pub fn insert(self: *Self, index: usize, item: T) !void {
            if (index > self.len) {
                return error.IndexOutOfBounds;
            }

            if (comptime inline_capacity > 0) {
                if (self.len < inline_capacity) {
                    var i = self.len;
                    while (i > index) : (i -= 1) {
                        self.inline_storage[i] = self.inline_storage[i - 1];
                    }
                    self.inline_storage[index] = item;
                    self.len += 1;
                    return;
                }
            }
            try self.ensureHeap();
            try self.heap_storage.?.insert(self.allocator, index, item);
            self.len += 1;
        }

        pub fn remove(self: *Self, index: usize) !T {
            if (index >= self.len) {
                return error.IndexOutOfBounds;
            }

            if (self.heap_storage) |*heap| {
                const item = heap.orderedRemove(index);
                self.len -= 1;
                return item;
            } else {
                const item = self.inline_storage[index];
                var i = index;
                while (i < self.len - 1) : (i += 1) {
                    self.inline_storage[i] = self.inline_storage[i + 1];
                }
                self.len -= 1;
                return item;
            }
        }

        pub fn replace(self: *Self, index: usize, item: T) !T {
            if (index >= self.len) {
                return error.IndexOutOfBounds;
            }

            if (self.heap_storage) |*heap| {
                const old = heap.items[index];
                heap.items[index] = item;
                return old;
            } else {
                const old = self.inline_storage[index];
                self.inline_storage[index] = item;
                return old;
            }
        }

        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len) {
                return null;
            }

            if (self.heap_storage) |heap| {
                return heap.items[index];
            } else {
                return self.inline_storage[index];
            }
        }

        pub fn contains(self: *const Self, item: T) bool {
            if (self.heap_storage) |heap| {
                for (heap.items) |elem| {
                    if (std.meta.eql(elem, item)) return true;
                }
            } else {
                for (self.inline_storage[0..self.len]) |elem| {
                    if (std.meta.eql(elem, item)) return true;
                }
            }
            return false;
        }

        pub fn size(self: *const Self) usize {
            return self.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Clear all items from the list.
        /// WHATWG Infra Standard §5.1 line 882: "To **empty** a list is to remove all of its items."
        pub fn clear(self: *Self) void {
            if (self.heap_storage) |*heap| {
                heap.clearRetainingCapacity();
            }
            self.len = 0;
        }

        /// Alias for clear(). Remove all items from the list.
        /// WHATWG Infra Standard §5.1 line 882: "To **empty** a list is to remove all of its items."
        pub const empty = clear;

        pub fn clone(self: *const Self) !Self {
            var new_list = Self.init(self.allocator);

            if (self.heap_storage) |heap| {
                for (heap.items) |item| {
                    try new_list.append(item);
                }
            } else {
                for (self.inline_storage[0..self.len]) |item| {
                    try new_list.append(item);
                }
            }

            return new_list;
        }

        pub fn extend(self: *Self, other: *const Self) !void {
            if (other.heap_storage) |heap| {
                for (heap.items) |item| {
                    try self.append(item);
                }
            } else {
                for (other.inline_storage[0..other.len]) |item| {
                    try self.append(item);
                }
            }
        }

        pub fn sort(self: *Self, comptime lessThan: fn (T, T) bool) void {
            if (self.heap_storage) |*heap| {
                std.mem.sort(T, heap.items, {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(a, b);
                    }
                }.inner);
            } else {
                std.mem.sort(T, self.inline_storage[0..self.len], {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(a, b);
                    }
                }.inner);
            }
        }

        pub fn sortDescending(self: *Self, comptime lessThan: fn (T, T) bool) void {
            if (self.heap_storage) |*heap| {
                std.mem.sort(T, heap.items, {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(b, a);
                    }
                }.inner);
            } else {
                std.mem.sort(T, self.inline_storage[0..self.len], {}, struct {
                    fn inner(_: void, a: T, b: T) bool {
                        return lessThan(b, a);
                    }
                }.inner);
            }
        }

        pub fn getIndices(self: *const Self, allocator: Allocator) ![]const usize {
            const indices = try allocator.alloc(usize, self.len);
            for (0..self.len) |i| {
                indices[i] = i;
            }
            return indices;
        }

        /// Replace all items matching a condition with a given item.
        /// WHATWG Infra Standard §5.1 line 870: "To **replace** within a list that is not
        /// an ordered set is to replace all items from the list that match a given condition
        /// with the given item, or do nothing if none do."
        pub fn replaceMatching(self: *Self, condition: fn (T) bool, item: T) void {
            if (self.heap_storage) |*heap| {
                for (heap.items, 0..) |elem, i| {
                    if (condition(elem)) {
                        heap.items[i] = item;
                    }
                }
            } else {
                for (self.inline_storage[0..self.len], 0..) |elem, i| {
                    if (condition(elem)) {
                        self.inline_storage[i] = item;
                    }
                }
            }
        }

        /// Remove all items matching a condition from the list.
        /// WHATWG Infra Standard §5.1 line 876: "To **remove** zero or more items from
        /// a list is to remove all items from the list that match a given condition,
        /// or do nothing if none do."
        pub fn removeMatching(self: *Self, condition: fn (T) bool) void {
            var i: usize = 0;
            while (i < self.len) {
                const elem = if (self.heap_storage) |heap| heap.items[i] else self.inline_storage[i];
                if (condition(elem)) {
                    _ = self.remove(i) catch unreachable;
                } else {
                    i += 1;
                }
            }
        }

        pub fn items(self: *const Self) []const T {
            if (self.heap_storage) |heap| {
                return heap.items;
            } else {
                return self.inline_storage[0..self.len];
            }
        }

        pub fn ensureCapacity(self: *Self, capacity: usize) !void {
            if (capacity <= inline_capacity) {
                return;
            }

            try self.ensureHeap();

            if (self.heap_storage) |*heap| {
                if (heap.capacity < capacity) {
                    try heap.ensureTotalCapacity(self.allocator, capacity);
                }
            }
        }

        fn ensureHeap(self: *Self) !void {
            if (self.heap_storage == null) {
                var heap = try std.ArrayList(T).initCapacity(self.allocator, inline_capacity * 2);
                for (self.inline_storage[0..self.len]) |item| {
                    try heap.append(self.allocator, item);
                }
                self.heap_storage = heap;
            }
        }
    };
}

test "List - init and deinit" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.size());
    try std.testing.expect(list.isEmpty());
}

test "List - append to inline storage" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try std.testing.expectEqual(@as(usize, 3), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(2).?);
}

test "List - append exceeds inline (spill to heap)" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.append(4);
    try list.append(5);

    try std.testing.expectEqual(@as(usize, 5), list.size());
    try std.testing.expect(list.heap_storage != null);

    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 5), list.get(4).?);
}

test "List - prepend" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(2);
    try list.append(3);
    try list.prepend(1);

    try std.testing.expectEqual(@as(usize, 3), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(2).?);
}

test "List - insert at middle" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(3);
    try list.insert(1, 2);

    try std.testing.expectEqual(@as(usize, 3), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(2).?);
}

test "List - insert at start" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(2);
    try list.insert(0, 1);

    try std.testing.expectEqual(@as(usize, 2), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(1).?);
}

test "List - insert at end" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.insert(1, 2);

    try std.testing.expectEqual(@as(usize, 2), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(1).?);
}

test "List - insert out of bounds" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    const result = list.insert(5, 2);
    try std.testing.expectError(error.IndexOutOfBounds, result);
}

test "List - remove from middle" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    const removed = try list.remove(1);
    try std.testing.expectEqual(@as(u32, 2), removed);
    try std.testing.expectEqual(@as(usize, 2), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(1).?);
}

test "List - remove out of bounds" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    const result = list.remove(0);
    try std.testing.expectError(error.IndexOutOfBounds, result);
}

test "List - replace" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    const old = try list.replace(1, 99);
    try std.testing.expectEqual(@as(u32, 2), old);
    try std.testing.expectEqual(@as(u32, 99), list.get(1).?);
}

test "List - contains" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try std.testing.expect(list.contains(2));
    try std.testing.expect(!list.contains(99));
}

test "List - size and isEmpty" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try std.testing.expect(list.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), list.size());

    try list.append(1);
    try std.testing.expect(!list.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), list.size());
}

test "List - clear" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    list.clear();

    try std.testing.expect(list.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), list.size());
}

test "List - empty alias" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    list.empty();

    try std.testing.expect(list.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), list.size());
}

test "List - clone" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    var cloned = try list.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(list.size(), cloned.size());
    try std.testing.expectEqual(@as(u32, 1), cloned.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), cloned.get(1).?);
    try std.testing.expectEqual(@as(u32, 3), cloned.get(2).?);
}

test "List - extend" {
    const allocator = std.testing.allocator;
    var list1 = List(u32).init(allocator);
    defer list1.deinit();
    var list2 = List(u32).init(allocator);
    defer list2.deinit();

    try list1.append(1);
    try list1.append(2);
    try list2.append(3);
    try list2.append(4);

    try list1.extend(&list2);

    try std.testing.expectEqual(@as(usize, 4), list1.size());
    try std.testing.expectEqual(@as(u32, 1), list1.get(0).?);
    try std.testing.expectEqual(@as(u32, 4), list1.get(3).?);
}

test "List - sort" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(3);
    try list.append(1);
    try list.append(4);
    try list.append(2);

    list.sort(struct {
        fn lessThan(a: u32, b: u32) bool {
            return a < b;
        }
    }.lessThan);

    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(2).?);
    try std.testing.expectEqual(@as(u32, 4), list.get(3).?);
}

test "List - get out of bounds returns null" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try std.testing.expectEqual(@as(?u32, null), list.get(5));
}

test "List - no memory leaks with heap storage" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try list.append(i);
    }

    try std.testing.expectEqual(@as(usize, 10), list.size());
}

test "List - sortDescending" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(3);
    try list.append(1);
    try list.append(4);
    try list.append(2);

    list.sortDescending(struct {
        fn lessThan(a: u32, b: u32) bool {
            return a < b;
        }
    }.lessThan);

    try std.testing.expectEqual(@as(u32, 4), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 2), list.get(2).?);
    try std.testing.expectEqual(@as(u32, 1), list.get(3).?);
}

test "List - replaceMatching" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.append(2);

    list.replaceMatching(struct {
        fn isTwo(x: u32) bool {
            return x == 2;
        }
    }.isTwo, 99);

    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 99), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(2).?);
    try std.testing.expectEqual(@as(u32, 99), list.get(3).?);
}

test "List - removeMatching" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.append(2);
    try list.append(4);

    list.removeMatching(struct {
        fn isTwo(x: u32) bool {
            return x == 2;
        }
    }.isTwo);

    try std.testing.expectEqual(@as(usize, 3), list.size());
    try std.testing.expectEqual(@as(u32, 1), list.get(0).?);
    try std.testing.expectEqual(@as(u32, 3), list.get(1).?);
    try std.testing.expectEqual(@as(u32, 4), list.get(2).?);
}

test "List - getIndices" {
    const allocator = std.testing.allocator;
    var list = List(u32).init(allocator);
    defer list.deinit();

    try list.append(10);
    try list.append(20);
    try list.append(30);

    const indices = try list.getIndices(allocator);
    defer allocator.free(indices);

    try std.testing.expectEqual(@as(usize, 3), indices.len);
    try std.testing.expectEqual(@as(usize, 0), indices[0]);
    try std.testing.expectEqual(@as(usize, 1), indices[1]);
    try std.testing.expectEqual(@as(usize, 2), indices[2]);
}
