# Implementation Comparison Matrices

**Purpose**: Detailed comparison of browser implementations vs proposed Zig implementations for each Infra data type.

**Date**: 2025-01-27

---

## Table of Contents

1. [Strings (§4.7)](#strings-47)
2. [Byte Sequences (§4.5)](#byte-sequences-45)
3. [Lists (§5.1)](#lists-51)
4. [Ordered Maps (§5.2)](#ordered-maps-52)
5. [Ordered Sets (§5.1.3)](#ordered-sets-513)
6. [JSON Operations (§6)](#json-operations-6)
7. [Memory Management](#memory-management)

---

## Strings (§4.7)

### Spec Requirement

**WHATWG Infra §4.7**:
> A string is a sequence of **16-bit unsigned integers**, also known as **code units**.

### Implementation Comparison

| Aspect | Chromium | Firefox | **Zig (Proposed)** |
|--------|----------|---------|-------------------|
| **Storage** | Hybrid 8-bit/16-bit | Pure 16-bit | **Pure 16-bit** |
| **Type** | `String` (refcounted) | `nsAString` (variants) | **`[]const u16`** (slice) |
| **Representation** | `LChar*` or `UChar*` | `char16_t*` | **`[]const u16`** |
| **Memory (ASCII)** | 1 byte/char | 2 bytes/char | **2 bytes/char** |
| **Memory (Non-ASCII)** | 2 bytes/char | 2 bytes/char | **2 bytes/char** |
| **Mutability** | Immutable (COW) | Mutable variants | **Immutable** |
| **Ownership** | Refcounted | Variants (owned/borrowed) | **Caller-owned (allocator)** |
| **UTF-8 Interop** | `FromUTF8()` / `Utf8()` | `NS_ConvertUTF8toUTF16` | **`fromUtf8()` / `toUtf8()`** |
| **JS Interop** | Direct (V8) | Direct (SpiderMonkey) | **Direct (V8 via zig-js-runtime)** |
| **Code Complexity** | High (dual paths) | Medium | **Low (single path)** |

### String Operations Coverage

| Operation (Infra §4.7) | Chromium | Firefox | Zig Implementation |
|------------------------|----------|---------|-------------------|
| **convert to scalar value** | ✅ | ✅ | `replaceInvalid(allocator, []const u16) ![]u16` |
| **is / identical to** | ✅ | ✅ | `std.mem.eql(u16, a, b)` |
| **code unit prefix** | ✅ | ✅ | `std.mem.startsWith(u16, input, prefix)` |
| **code unit suffix** | ✅ | ✅ | `std.mem.endsWith(u16, input, suffix)` |
| **code unit less than** | ✅ | ✅ | `codeUnitLessThan(a, b) bool` |
| **code unit substring** | ✅ | ✅ | `input[start..end]` (slice) |
| **code point substring** | ✅ | ✅ | `codePointSubstring(allocator, input, start, len) ![]u16` |
| **isomorphic encode** | ✅ | ✅ | `isomorphicEncode(allocator, []const u16) ![]u8` |
| **ASCII lowercase** | ✅ | ✅ | `asciiLowercase(allocator, []const u16) ![]u16` |
| **ASCII uppercase** | ✅ | ✅ | `asciiUppercase(allocator, []const u16) ![]u16` |
| **ASCII case-insensitive** | ✅ | ✅ | `asciiCaseInsensitiveMatch(a, b) bool` |
| **strip newlines** | ✅ | ✅ | `stripNewlines(allocator, []const u16) ![]u16` |
| **normalize newlines** | ✅ | ✅ | `normalizeNewlines(allocator, []const u16) ![]u16` |
| **strip whitespace** | ✅ | ✅ | `stripWhitespace(allocator, []const u16) ![]u16` |
| **split on whitespace** | ✅ | ✅ | `splitOnWhitespace(allocator, []const u16) ![][]const u16` |
| **split on commas** | ✅ | ✅ | `splitOnCommas(allocator, []const u16) ![][]const u16` |
| **concatenate** | ✅ | ✅ | `std.mem.concat(allocator, u16, slices)` |

### Zig-Specific Considerations

| Consideration | Decision | Rationale |
|---------------|----------|-----------|
| **Use `[]const u16`** | ✅ Yes | Spec-compliant, direct V8 interop, simple |
| **Refcounting** | ❌ No | Use Zig allocators (explicit ownership) |
| **Hybrid 8/16-bit** | ❌ Not Phase 1 | Adds complexity, optimize later if needed |
| **UTF-8 conversion** | ✅ Yes | Helper functions for Zig API boundaries |
| **String interning** | ⚠️ Optional | Provide `StringPool` utility (not core) |
| **Inline storage** | ❌ No | Strings are slices (no storage in type) |

### Example Zig API

```zig
// String type is just a UTF-16 slice
pub const String = []const u16;

// UTF-8 conversion
pub fn fromUtf8(allocator: Allocator, utf8: []const u8) !String {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, utf8);
}

pub fn toUtf8(allocator: Allocator, string: String) ![]u8 {
    return std.unicode.utf16LeToUtf8Alloc(allocator, string);
}

// String operations
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    const result = try allocator.alloc(u16, string.len);
    for (string, 0..) |code_unit, i| {
        // ASCII upper alpha: 0x0041 (A) to 0x005A (Z)
        if (code_unit >= 0x0041 and code_unit <= 0x005A) {
            result[i] = code_unit + 0x20;
        } else {
            result[i] = code_unit;
        }
    }
    return result;
}

pub fn codeUnitLessThan(a: String, b: String) bool {
    // Implement Infra algorithm exactly
    // ...
}
```

---

## Byte Sequences (§4.5)

### Spec Requirement

**WHATWG Infra §4.5**:
> A byte sequence is a sequence of bytes.

**Critical**: Byte sequences are **NOT strings**. No encoding assumed.

### Implementation Comparison

| Aspect | Chromium | Firefox | **Zig (Proposed)** |
|--------|----------|---------|-------------------|
| **Type** | `Vector<uint8_t>` | `nsTArray<uint8_t>` | **`[]const u8`** |
| **Encoding** | None (raw bytes) | None (raw bytes) | **None (raw bytes)** |
| **Distinct from String** | ✅ Yes | ✅ Yes | **✅ Yes** |
| **Inline storage** | ✅ Vector (4 elem) | ✅ (varies) | **✅ List(u8, 4)** |

### Byte Sequence Operations

| Operation (Infra §4.5) | Zig Implementation |
|------------------------|-------------------|
| **length** | `bytes.len` |
| **byte-lowercase** | `byteLowercase(allocator, []const u8) ![]u8` |
| **byte-uppercase** | `byteUppercase(allocator, []const u8) ![]u8` |
| **byte-case-insensitive** | `byteCaseInsensitiveMatch(a, b) bool` |
| **prefix** | `std.mem.startsWith(u8, input, prefix)` |
| **byte less than** | `byteLessThan(a, b) bool` (spec algorithm) |
| **isomorphic decode** | `isomorphicDecode(allocator, []const u8) ![]u16` |

### Example Zig API

```zig
// Byte sequence is just a byte slice
pub const ByteSequence = []const u8;

pub fn byteLowercase(allocator: Allocator, bytes: ByteSequence) !ByteSequence {
    const result = try allocator.alloc(u8, bytes.len);
    for (bytes, 0..) |byte, i| {
        // Increase 0x41-0x5A by 0x20
        if (byte >= 0x41 and byte <= 0x5A) {
            result[i] = byte + 0x20;
        } else {
            result[i] = byte;
        }
    }
    return result;
}

pub fn isomorphicDecode(allocator: Allocator, bytes: ByteSequence) !String {
    const result = try allocator.alloc(u16, bytes.len);
    for (bytes, 0..) |byte, i| {
        result[i] = byte; // Direct cast to u16
    }
    return result;
}
```

---

## Lists (§5.1)

### Spec Requirement

**WHATWG Infra §5.1**:
> A list is a specification type consisting of a finite ordered sequence of items.

### Implementation Comparison

| Aspect | Chromium | Firefox | **Zig (Proposed)** |
|--------|----------|---------|-------------------|
| **Base Type** | `WTF::Vector<T>` | `mozilla::Vector<T>` | **`std.ArrayList(T)` wrapper** |
| **Inline Storage** | 4 elements default | 4 elements default | **4 elements default** |
| **Inline Capacity** | Configurable | Configurable | **Configurable (comptime)** |
| **Heap Migration** | Lazy (auto) | Lazy (auto) | **Lazy (manual wrapper)** |
| **Memory Management** | Allocator-based | Allocator-based | **Allocator-based** |
| **Growth Strategy** | 2x capacity | 2x capacity | **2x capacity (ArrayList)** |

### List Operations Coverage

| Operation (Infra §5.1) | Chromium | Firefox | Zig Implementation |
|------------------------|----------|---------|-------------------|
| **append** | ✅ | ✅ | `try list.append(item)` |
| **extend** | ✅ | ✅ | `try list.appendSlice(other)` |
| **prepend** | ✅ | ✅ | `try list.insert(0, item)` |
| **replace** | ✅ | ✅ | `replace(list, old, new)` |
| **insert** | ✅ | ✅ | `try list.insert(index, item)` |
| **remove** | ✅ | ✅ | `removeItem(list, item)` |
| **empty** | ✅ | ✅ | `list.clearRetainingCapacity()` |
| **contains** | ✅ | ✅ | `contains(list, item) bool` |
| **size** | ✅ | ✅ | `list.items.len` |
| **is empty** | ✅ | ✅ | `list.items.len == 0` |
| **iterate** | ✅ | ✅ | `for (list.items) \|item\| {}` |
| **clone** | ✅ | ✅ | `try list.clone()` |
| **sort** | ✅ | ✅ | `std.sort.pdq(T, list.items, {}, lessThan)` |

### Example Zig API

```zig
/// List with inline storage optimization
pub fn List(comptime T: type, comptime inline_capacity: usize) type {
    return struct {
        const Self = @This();
        
        inline_storage: [inline_capacity]T = undefined,
        heap_storage: ?std.ArrayList(T) = null,
        len: usize = 0,
        allocator: Allocator,
        
        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }
        
        pub fn deinit(self: *Self) void {
            if (self.heap_storage) |*heap| {
                heap.deinit();
            }
        }
        
        pub fn append(self: *Self, item: T) !void {
            if (self.len < inline_capacity) {
                // Fast path: inline storage
                self.inline_storage[self.len] = item;
                self.len += 1;
                return;
            }
            
            if (self.heap_storage == null) {
                // Migrate to heap
                var heap = std.ArrayList(T).init(self.allocator);
                try heap.appendSlice(self.inline_storage[0..inline_capacity]);
                self.heap_storage = heap;
            }
            
            try self.heap_storage.?.append(item);
            self.len += 1;
        }
        
        pub fn items(self: Self) []const T {
            if (self.heap_storage) |heap| {
                return heap.items;
            }
            return self.inline_storage[0..self.len];
        }
    };
}

// Default: 4-element inline capacity
pub fn DefaultList(comptime T: type) type {
    return List(T, 4);
}
```

---

## Ordered Maps (§5.2)

### Spec Requirement

**WHATWG Infra §5.2**:
> An ordered map is a specification type consisting of a finite ordered sequence of tuples, each consisting of a key and a value, with no key appearing twice.

**Critical**: Must preserve **insertion order**.

### Implementation Comparison

| Aspect | Chromium (Attributes) | Firefox (Attributes) | **Zig (Proposed)** |
|--------|----------------------|---------------------|-------------------|
| **Backing Storage** | `Vector<Attribute>` | Array/Vector | **`List(Entry, 4)`** |
| **Lookup Strategy** | Linear search | Linear search | **Linear search** |
| **Insertion Order** | Natural (list) | Natural (list) | **Natural (list)** |
| **Preallocation** | 10 (attributes) | Varies | **4 (generic)** |
| **Hash Table** | ❌ No | ❌ No | **❌ No (Phase 1)** |
| **Complexity** | O(n) lookup | O(n) lookup | **O(n) lookup** |

### Design Rationale

**Why Linear Search?**
- ✅ Simple and correct
- ✅ Fast for small n (< 10-12) - typical case
- ✅ Cache-friendly (sequential access)
- ✅ Insertion order free (no separate index)
- ✅ Matches browser implementations

**Browser Benchmarks** (Chromium):
> Linear search faster than HashMap for n < 12 due to cache locality and no hashing overhead.

### Ordered Map Operations

| Operation (Infra §5.2) | Zig Implementation |
|------------------------|-------------------|
| **get** | `get(map, key) ?V` (linear search) |
| **set** | `try set(map, key, value)` (update or append) |
| **remove** | `remove(map, key) bool` |
| **clear** | `clear(map)` |
| **contains** | `contains(map, key) bool` |
| **keys** | `keys(map) OrderedSet(K)` |
| **values** | `values(map) List(V)` |
| **size** | `map.entries.len` |
| **iterate** | `for (map.entries()) \|entry\| {}` |
| **clone** | `try clone(map, allocator)` |
| **sort** | `sortBy(map, allocator, lessThan)` |

### Example Zig API

```zig
/// Ordered map with insertion-order preservation
pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        
        pub const Entry = struct {
            key: K,
            value: V,
        };
        
        entries: List(Entry, 4), // 4-entry inline storage
        
        pub fn init(allocator: Allocator) Self {
            return .{ .entries = List(Entry, 4).init(allocator) };
        }
        
        pub fn deinit(self: *Self) void {
            self.entries.deinit();
        }
        
        pub fn set(self: *Self, key: K, value: V) !void {
            // Linear search for existing key
            for (self.entries.items(), 0..) |*entry, i| {
                if (std.meta.eql(entry.key, key)) {
                    // Update existing
                    entry.value = value;
                    return;
                }
            }
            // Append new entry (insertion order preserved)
            try self.entries.append(.{ .key = key, .value = value });
        }
        
        pub fn get(self: Self, key: K) ?V {
            for (self.entries.items()) |entry| {
                if (std.meta.eql(entry.key, key)) {
                    return entry.value;
                }
            }
            return null;
        }
        
        pub fn remove(self: *Self, key: K) bool {
            for (self.entries.items(), 0..) |entry, i| {
                if (std.meta.eql(entry.key, key)) {
                    _ = self.entries.orderedRemove(i);
                    return true;
                }
            }
            return false;
        }
    };
}
```

### Future Optimization (Phase 2+)

If profiling shows large maps are common, consider:

**Option 1**: HashMap + Index List
```zig
pub fn OptimizedOrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        map: std.HashMap(K, V),      // O(1) lookup
        insertion_order: List(K, 4), // Preserve order
    };
}
```

**Threshold**: Switch to HashMap when n > 12 (browser benchmark threshold).

---

## Ordered Sets (§5.1.3)

### Spec Requirement

**WHATWG Infra §5.1.3**:
> An ordered set is a list with the additional semantic that it must not contain the same item twice.

### Implementation Comparison

| Aspect | Chromium | Firefox | **Zig (Proposed)** |
|--------|----------|---------|-------------------|
| **Backing Storage** | `Vector<T>` | Vector/Array | **`List(T, 4)`** |
| **Deduplication** | On append | On append | **On append/prepend** |
| **Lookup Strategy** | Linear search | Linear search | **Linear search** |
| **Insertion Order** | Natural (list) | Natural (list) | **Natural (list)** |

### Ordered Set Operations

| Operation (Infra §5.1.3) | Zig Implementation |
|--------------------------|-------------------|
| **create** | `createSet(allocator, list) !OrderedSet(T)` |
| **append** | `try append(set, item)` (deduplicate) |
| **extend** | `try extend(set, other)` (deduplicate) |
| **prepend** | `try prepend(set, item)` (deduplicate) |
| **replace** | `try replace(set, old, new)` |
| **subset** | `isSubset(a, b) bool` |
| **superset** | `isSuperset(a, b) bool` |
| **equal** | `equal(a, b) bool` |
| **intersection** | `try intersection(allocator, a, b)` |
| **union** | `try union(allocator, a, b)` |
| **difference** | `try difference(allocator, a, b)` |
| **range** | `range(n, m, inclusive) OrderedSet(usize)` |

### Example Zig API

```zig
/// Ordered set with deduplication
pub fn OrderedSet(comptime T: type) type {
    return struct {
        const Self = @This();
        
        items: List(T, 4), // 4-element inline storage
        
        pub fn init(allocator: Allocator) Self {
            return .{ .items = List(T, 4).init(allocator) };
        }
        
        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }
        
        pub fn append(self: *Self, item: T) !void {
            // Only append if not already present (deduplication)
            if (self.contains(item)) return;
            try self.items.append(item);
        }
        
        pub fn contains(self: Self, item: T) bool {
            for (self.items.items()) |existing| {
                if (std.meta.eql(existing, item)) return true;
            }
            return false;
        }
        
        pub fn union(allocator: Allocator, a: Self, b: Self) !Self {
            var result = Self.init(allocator);
            errdefer result.deinit();
            
            // Add all from a
            for (a.items.items()) |item| {
                try result.append(item);
            }
            
            // Add all from b (deduplicated)
            for (b.items.items()) |item| {
                try result.append(item);
            }
            
            return result;
        }
    };
}
```

---

## JSON Operations (§6)

### Spec Requirement

**WHATWG Infra §6**:
> Convert between JSON and Infra values (null, boolean, number, string, list, ordered map).

### Implementation Comparison

| Aspect | Chromium | Firefox | **Zig (Proposed)** |
|--------|----------|---------|-------------------|
| **JSON Parser** | V8's JSON.parse | SpiderMonkey | **`std.json`** |
| **Infra Value Type** | Not exposed | Not exposed | **`InfraValue` union** |
| **Object → Map** | N/A (JS realm) | N/A (JS realm) | **OrderedMap (preserve order!)** |
| **Array → List** | N/A (JS realm) | N/A (JS realm) | **List** |

### InfraValue Type

```zig
pub const InfraValue = union(enum) {
    null_value: void,
    boolean: bool,
    number: f64,        // JavaScript numbers are f64
    string: String,     // []const u16
    list: List(InfraValue, 4),
    map: OrderedMap(String, InfraValue),
    
    pub fn deinit(self: InfraValue, allocator: Allocator) void {
        switch (self) {
            .string => |s| allocator.free(s),
            .list => |*l| {
                for (l.items()) |item| {
                    item.deinit(allocator);
                }
                l.deinit();
            },
            .map => |*m| {
                for (m.entries.items()) |entry| {
                    allocator.free(entry.key);
                    entry.value.deinit(allocator);
                }
                m.deinit();
            },
            else => {},
        }
    }
};
```

### JSON Operations

| Operation (Infra §6) | Zig Implementation |
|----------------------|-------------------|
| **parse JSON to Infra value** | `parseJsonToInfra(allocator, []const u8) !InfraValue` |
| **serialize Infra to JSON** | `serializeInfraToJson(allocator, InfraValue) ![]u8` |
| **convert JS → Infra** | N/A (JS bridge handles) |
| **convert Infra → JS** | N/A (JS bridge handles) |

---

## Memory Management

### Comparison

| Aspect | Chromium | Firefox | **Zig (Proposed)** |
|--------|----------|---------|-------------------|
| **Strings** | Refcounted | Refcounted/Owned | **Caller-owned (allocator)** |
| **Collections** | Allocator-based | Allocator-based | **Allocator-based** |
| **Inline Storage** | ✅ 4 elements | ✅ 4 elements | **✅ 4 elements** |
| **Reference Counting** | ✅ Strings | ✅ Strings/DOM | **❌ No (explicit ownership)** |
| **Arena Allocation** | ✅ For temps | ✅ For temps | **✅ For temps** |
| **Leak Detection** | ASan/LSan | Valgrind | **`std.testing.allocator`** |

### Zig Memory Patterns

```zig
// Pattern 1: Caller owns result
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    const result = try allocator.alloc(u16, string.len);
    // ... populate result ...
    return result; // Caller must free
}

// Pattern 2: Arena for temporaries
pub fn complexOperation(arena: Allocator, input: String) !String {
    const temp1 = try asciiLowercase(arena, input);
    const temp2 = try stripWhitespace(arena, temp1);
    // temp1, temp2 freed when arena deinit()
    return temp2;
}

// Pattern 3: In-place mutation (when possible)
pub fn sortInPlace(list: *List(u32, 4)) void {
    std.sort.pdq(u32, list.items(), {}, lessThan);
}
```

---

## Summary: Zig vs Browsers

### What We Adopt from Browsers

| Pattern | Browsers | Zig |
|---------|----------|-----|
| **UTF-16 strings** | ✅ | ✅ |
| **Inline storage (4 elem)** | ✅ | ✅ |
| **List-backed ordered maps** | ✅ | ✅ |
| **Linear search (small n)** | ✅ | ✅ |
| **Lazy heap migration** | ✅ | ✅ |

### What We Adapt for Zig

| Pattern | Browsers | Zig |
|---------|----------|-----|
| **Reference counting** | ✅ | ❌ (explicit ownership) |
| **Hybrid 8/16-bit strings** | ✅ Chromium | ❌ (Phase 1: pure UTF-16) |
| **Complex string variants** | ✅ | ❌ (just slices) |
| **Inheritance hierarchies** | ✅ C++ | ❌ (composition) |

### What We Add (Zig Superpowers)

| Feature | Browsers | Zig |
|---------|----------|-----|
| **Comptime inline capacity** | ❌ | ✅ |
| **Explicit allocators** | ⚠️ (abstracted) | ✅ |
| **Zero-cost abstractions** | ⚠️ (some) | ✅ |
| **Leak detection (testing)** | ⚠️ (ASan) | ✅ (`std.testing.allocator`) |
| **No hidden allocations** | ❌ | ✅ |

---

**Status**: Comparison matrices complete. Ready for design decisions document.

**Next**: Document design decisions with full rationale and implementation plan.
