const std = @import("std");
const infra = @import("infra");
const List = infra.List;

const ITERATIONS = 1_000_000;

fn benchmark(name: []const u8, comptime func: fn () anyerror!void) !void {
    const start = std.time.nanoTimestamp();
    try func();
    const end = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    const per_op = elapsed / @as(f64, @floatFromInt(ITERATIONS));
    std.debug.print("{s}: {d:.2} ms total, {d:.2} ns/op\n", .{ name, elapsed, per_op });
}

fn benchListAppendInline() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.append(1);
        try list.append(2);
        try list.append(3);
    }
}

fn benchListAppendHeap() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        var j: u32 = 0;
        while (j < 10) : (j += 1) {
            try list.append(j);
        }
    }
}

fn benchListPrepend() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.prepend(1);
        try list.prepend(2);
        try list.prepend(3);
    }
}

fn benchListInsert() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.append(1);
        try list.append(3);
        try list.insert(1, 2);
    }
}

fn benchListRemove() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.append(1);
        try list.append(2);
        try list.append(3);
        _ = try list.remove(1);
    }
}

fn benchListGet() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = List(u32).init(allocator);
    defer list.deinit();
    try list.append(1);
    try list.append(2);
    try list.append(3);

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        _ = list.get(1);
    }
}

fn benchListContains() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = List(u32).init(allocator);
    defer list.deinit();
    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try list.append(j);
    }

    var i: usize = 0;
    while (i < ITERATIONS) : (i += 1) {
        _ = list.contains(5);
    }
}

fn benchListClone() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = List(u32).init(allocator);
    defer list.deinit();
    var j: u32 = 0;
    while (j < 10) : (j += 1) {
        try list.append(j);
    }

    var i: usize = 0;
    while (i < ITERATIONS / 100) : (i += 1) {
        var cloned = try list.clone();
        defer cloned.deinit();
    }
}

fn benchListSort() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var i: usize = 0;
    while (i < ITERATIONS / 100) : (i += 1) {
        var list = List(u32).init(allocator);
        defer list.deinit();
        try list.append(9);
        try list.append(2);
        try list.append(7);
        try list.append(4);
        try list.append(1);
        list.sort(struct {
            fn lessThan(a: u32, b: u32) bool {
                return a < b;
            }
        }.lessThan);
    }
}

pub fn main() !void {
    std.debug.print("\n=== List Benchmarks ===\n\n", .{});

    try benchmark("append (inline storage, 3 items)", benchListAppendInline);
    try benchmark("append (heap storage, 10 items)", benchListAppendHeap);
    try benchmark("prepend (3 items)", benchListPrepend);
    try benchmark("insert (middle)", benchListInsert);
    try benchmark("remove (middle)", benchListRemove);
    try benchmark("get (index access)", benchListGet);
    try benchmark("contains (linear search)", benchListContains);
    try benchmark("clone (10 items)", benchListClone);
    try benchmark("sort (5 items)", benchListSort);

    std.debug.print("\n", .{});
}
