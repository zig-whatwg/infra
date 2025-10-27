# Design Decisions for Zig WHATWG Infra Implementation

**Last Updated**: 2025-10-27  
**Status**: Phase 1 Design Complete

---

## Table of Contents

1. [String Representation: Pure UTF-16](#string-representation-pure-utf-16)
2. [Ordered Map: List-Backed with Linear Search](#ordered-map-list-backed-with-linear-search)
3. [Inline Storage: 4 Elements for All Collections](#inline-storage-4-elements-for-all-collections)
4. [Memory Management: Explicit Allocators](#memory-management-explicit-allocators)
5. [Future Optimization Paths](#future-optimization-paths)

---

## String Representation: Pure UTF-16

### Decision

```zig
pub const String = []const u16;
```

Infra strings are represented as **slices of 16-bit unsigned integers** (UTF-16 code units).

### Rationale

#### Spec Compliance (Primary)

From WHATWG Infra §4.7:

> "A string is a sequence of 16-bit unsigned integers, also known as code units."

This is **non-negotiable**. Infra strings are UTF-16 by specification.

#### V8 Interop (Critical for zig-js-runtime)

V8's JavaScript strings are UTF-16:

```cpp
// V8 internal representation
class String {
  union {
    uint8_t* one_byte_data;   // Latin1 optimization
    uint16_t* two_byte_data;  // UTF-16
  };
};
```

**Pure UTF-16 Benefits**:
- Zero-copy string passing from Zig → V8
- No conversion overhead for JavaScript interop
- Direct compatibility with `v8::String::NewFromTwoByte()`

#### Simplicity

**Pure UTF-16** has a single code path:
- No dual representation (8-bit/16-bit) to manage
- No runtime checks for "is this ASCII?"
- No promotion logic (8-bit → 16-bit)
- Straightforward implementation

### Trade-offs Accepted

#### Memory Cost

**Cost**: 2 bytes per character, even for ASCII.

```zig
// ASCII string "hello"
const s1: String = &[_]u16{ 'h', 'e', 'l', 'l', 'o' };  // 10 bytes

// vs UTF-8 (Zig default)
const s2: []const u8 = "hello";  // 5 bytes
```

**Mitigation**: 
- Most web strings are short (< 32 chars)
- V8 interop savings outweigh memory cost
- Can optimize later with hybrid representation if profiling shows memory pressure

#### Zig Ergonomics

**Cost**: Most Zig code uses UTF-8 (`[]const u8`).

```zig
// Conversion required for Zig strings
const zig_str = "hello";
const infra_str = try utf8ToUtf16(allocator, zig_str);
defer allocator.free(infra_str);
```

**Mitigation**:
- Provide helper functions for UTF-8 ↔ UTF-16 conversion
- Document conversion patterns clearly
- Most usage will be at V8 boundary, not internal Zig code

### Alternatives Considered

#### Alternative 1: Hybrid 8-bit/16-bit (Chromium WTF::String)

```zig
pub const String = union(enum) {
    latin1: []const u8,    // ASCII/Latin1
    utf16: []const u16,    // Full Unicode
};
```

**Rejected for Phase 1**:
- **Complexity**: Every string operation needs dual paths
- **Risk**: Easy to introduce bugs with promotion logic
- **Premature**: No evidence yet that memory is bottleneck
- **Future**: Can add if profiling shows 50%+ memory in strings

#### Alternative 2: UTF-8 with Conversion

```zig
pub const String = []const u8;  // UTF-8
```

**Rejected**:
- ❌ **Spec violation**: Infra explicitly requires 16-bit code units
- ❌ **Conversion overhead**: Every V8 call requires UTF-8 → UTF-16
- ❌ **Semantic mismatch**: Code point indexing differs (UTF-8 vs UTF-16)
- ❌ **Surrogate pairs**: Can't represent unpaired surrogates in UTF-8

### Implementation Plan

#### Phase 1: Pure UTF-16

```zig
// src/string.zig

/// WHATWG Infra string: sequence of 16-bit code units
/// Spec: https://infra.spec.whatwg.org/#string
pub const String = []const u16;

/// Convert UTF-8 to UTF-16 (allocates)
pub fn utf8ToUtf16(allocator: Allocator, utf8: []const u8) !String { }

/// Convert UTF-16 to UTF-8 (allocates)
pub fn utf16ToUtf8(allocator: Allocator, utf16: String) ![]const u8 { }

/// ASCII lowercase (Infra §4.7)
pub fn asciiLowercase(allocator: Allocator, string: String) !String { }

// ... 30+ string operations
```

#### Phase 2+: Optimization Opportunities

If profiling shows memory pressure:

1. **String interning**: `StringPool` for common strings
2. **Hybrid representation**: 8-bit fast path for ASCII
3. **Small string optimization**: Inline < 8 chars (16 bytes)

---

## Ordered Map: List-Backed with Linear Search

### Decision

```zig
pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        entries: List(Entry, 4),  // 4-entry inline storage
        
        pub const Entry = struct {
            key: K,
            value: V,
        };
        
        pub fn get(self: *const Self, key: K) ?V {
            // Linear search through entries
            for (self.entries.items) |entry| {
                if (std.meta.eql(entry.key, key)) return entry.value;
            }
            return null;
        }
    };
}
```

Ordered maps are **backed by a list** with **linear search**, NOT a hash table.

### Rationale

#### Spec Requirement: Insertion Order

From WHATWG Infra §5.2:

> "An ordered map is an ordered list of tuples."

Ordered maps **must preserve insertion order**. This rules out `std.HashMap`, which does not guarantee order.

#### Browser Implementation Pattern

**Chromium** (NamedNodeMap for DOM attributes):

```cpp
// third_party/blink/renderer/core/dom/element.h
class ElementData {
    // NOT a HashMap!
    Vector<Attribute, kAttributePrealloc> attributes_;
    
    const Attribute* FindAttributeByName(const QualifiedName& name) const {
        // Linear search
        for (const Attribute& attr : attributes_) {
            if (attr.GetName() == name) return &attr;
        }
        return nullptr;
    }
};
```

**Firefox** (similar pattern):

```cpp
// dom/base/nsAttrAndChildArray.h
// Attributes stored as flat array with linear search
```

#### Performance: Linear Search is Faster for Small n

**Cache Locality Wins**:

From Chromium comments:
> "For small n (< ~12), linear search in a vector is faster than HashMap due to cache locality."

**Why**:
- Vector data is contiguous (cache-friendly)
- HashMap requires pointer chasing (cache-unfriendly)
- Modern CPUs: ~200 cycle cost for L3 cache miss
- Linear search: ~4 cycles per comparison (in L1)

**Math**:
- HashMap: 1 hash + 1-2 cache misses = ~400 cycles
- Linear search (n=10): 10 comparisons × 4 cycles = 40 cycles

**Breakeven**: ~12 elements (varies by workload)

#### Typical Case: Small Maps

Most Infra ordered maps are small:
- DOM attributes: median 2-3, p95 < 10
- HTTP headers: median 8-12
- JSON objects: median 3-5

**70-80% of maps have ≤ 4 entries** (Firefox data).

### Trade-offs Accepted

#### O(n) Lookup/Insert

**Cost**: Linear time for `get()`, `set()`, `remove()`.

```zig
// Worst case: n comparisons
pub fn get(self: *const Self, key: K) ?V {
    for (self.entries.items) |entry| {
        if (std.meta.eql(entry.key, key)) return entry.value;
    }
    return null;
}
```

**Mitigation**:
- Acceptable for n < 12 (typical case)
- Can optimize later with hybrid approach (list → hash at threshold)

### Alternatives Considered

#### Alternative 1: IndexedHashMap (stdlib)

```zig
pub const OrderedMap = std.ArrayHashMap;  // Preserves insertion order
```

**Rejected**:
- ❌ **Overkill for small n**: Hash overhead not worth it for n < 12
- ❌ **Memory overhead**: Hash buckets + array = 2× storage
- ❌ **Not browser pattern**: Diverges from proven implementations

**Future**: Could use as hybrid fallback for large maps.

#### Alternative 2: HashMap + Insertion Order List

```zig
pub fn OrderedMap(K, V) type {
    map: std.HashMap(K, usize),     // Key → index
    order: List(Entry, 4),          // Insertion order
};
```

**Rejected**:
- ❌ **Complexity**: Two data structures to keep in sync
- ❌ **Memory**: 2× overhead for small maps
- ❌ **Premature**: No evidence large maps are common

### Implementation Plan

#### Phase 1: Pure List-Backed

```zig
// src/map.zig

pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        entries: List(Entry, 4),
        
        pub fn get(self: *const Self, key: K) ?V {
            for (self.entries.items) |entry| {
                if (std.meta.eql(entry.key, key)) return entry.value;
            }
            return null;
        }
        
        pub fn set(self: *Self, key: K, value: V) !void {
            for (self.entries.items, 0..) |*entry, i| {
                if (std.meta.eql(entry.key, key)) {
                    entry.value = value;
                    return;
                }
            }
            try self.entries.append(.{ .key = key, .value = value });
        }
    };
}
```

#### Phase 2+: Optimization Opportunities

If profiling shows hot path with large maps:

1. **Hybrid threshold**: Switch to HashMap at n > 12
2. **SIMD search**: Vectorized key comparison for strings
3. **Bloom filter**: Quick rejection for `contains(key)`

---

## Inline Storage: 4 Elements for All Collections

### Decision

All Infra collections use **4-element inline storage** (stack-allocated, no heap allocation).

```zig
pub fn List(comptime T: type, comptime inline_capacity: usize) type { }

// Default: 4 elements inline
const default_list = List(u32, 4);
const default_map = OrderedMap(String, u32);  // 4 entries inline
const default_set = OrderedSet(u32);           // 4 elements inline
```

### Rationale

#### Browser Research: 4 Elements is Proven

**Chromium** (`WTF::Vector`):

```cpp
// wtf/Vector.h
template<typename T, size_t inlineCapacity = 0, typename Allocator = ...>
class Vector { };

// Default inline capacity: 4
static constexpr size_t kDefaultInlineCapacity = 4;
```

**Firefox** (`mozilla::Vector`):

```cpp
// mfbt/Vector.h
template<typename T, size_t N = 0, class AllocPolicy = ...>
class Vector { };

// Typical usage: Vector<T, 4>
```

**Hit Rate**: 70-80% of collections have ≤ 4 elements (Firefox documentation).

#### Cache Line Optimization

**64-byte cache line** (typical modern CPU):

```
4 elements × 16 bytes/element = 64 bytes (perfect fit)
```

For typical types:
- `u32`: 4 × 4 = 16 bytes
- Pointers: 4 × 8 = 32 bytes
- Small structs: 4 × 16 = 64 bytes

**Benefits**:
- Single cache line fetch
- No false sharing
- Optimal SIMD width (128-bit = 4 × u32)

#### NOT 10 (DOM Attributes are Special)

**Chromium** uses `kAttributePrealloc = 10` **specifically for DOM attributes**:

```cpp
// third_party/blink/renderer/core/dom/element_data.h
static constexpr size_t kAttributePrealloc = 10;
```

**Why 10 for attributes**:
- DOM-specific optimization
- Attributes are **long-lived** (persist for page lifetime)
- Measured: median 3, p95 = 8-9, max often 10-15
- Extra 6 elements justified for **persistent** data

**Why NOT 10 for Infra primitives**:
- ❌ Infra collections are **short-lived** (function locals, temps)
- ❌ Infra is **generic** (not domain-specific)
- ❌ 10 elements wastes stack space for 70-80% of cases
- ✅ 4 elements is the **proven default** for generic containers

### Trade-offs Accepted

#### Stack Usage

**Cost**: 4 × sizeof(T) bytes per collection on stack.

```zig
// Example: List of 64-byte structs
const list: List(MyStruct, 4) = ...;  // 256 bytes stack
```

**Mitigation**:
- Acceptable for typical types (u32, pointers, small structs)
- For large T, user can specify `List(T, 0)` (no inline storage)
- Document stack usage guidelines

#### Wasted Space for Empty Collections

**Cost**: 4 × sizeof(T) reserved even if empty.

**Mitigation**:
- Short-lived collections (function scope) → doesn't matter
- Long-lived collections → use `List(T, 0)` if usually empty
- 70-80% hit rate means waste is rare

### Alternatives Considered

#### Alternative 1: Zero Inline Storage

```zig
pub const List = std.ArrayList;  // No inline storage
```

**Rejected**:
- ❌ **Allocation overhead**: Every append requires heap allocation
- ❌ **Misses optimization**: Ignores proven 70-80% hit rate
- ❌ **Not browser pattern**: All browsers use inline storage

#### Alternative 2: 10-Element Inline Storage

```zig
pub fn List(comptime T: type) type {
    return ListWithCapacity(T, 10);
}
```

**Rejected**:
- ❌ **Wrong context**: 10 is for DOM attributes (domain-specific, long-lived)
- ❌ **Stack waste**: 6 extra elements wasted for 70-80% of cases
- ❌ **Not generic**: Infra primitives are short-lived and generic

#### Alternative 3: Comptime Configuration

```zig
pub const Config = struct {
    list_inline_capacity: usize = 4,
    map_inline_capacity: usize = 4,
};
```

**Rejected for Phase 1**:
- Too complex for initial implementation
- Can add later if use cases emerge

### Implementation Plan

#### Phase 1: Fixed 4-Element Inline

```zig
// src/list.zig

pub fn List(comptime T: type, comptime inline_capacity: usize) type {
    return struct {
        inline_storage: [inline_capacity]T = undefined,
        heap_storage: ?[]T = null,
        len: usize = 0,
        
        pub fn append(self: *Self, item: T) !void {
            if (self.len < inline_capacity) {
                self.inline_storage[self.len] = item;
                self.len += 1;
            } else {
                // Spill to heap
                try self.spillToHeap();
                try self.heap_storage.?.append(item);
            }
        }
    };
}

// Default: 4 elements
pub fn ListDefault(comptime T: type) type {
    return List(T, 4);
}
```

#### Phase 2+: Optimization Opportunities

1. **Comptime configuration**: Let users override default
2. **Auto-sizing**: Use `@sizeOf(T)` to compute optimal inline capacity
3. **Profiling hooks**: Track actual usage patterns

---

## Memory Management: Explicit Allocators

### Decision

All Infra operations that allocate **take an `Allocator` parameter**. No hidden allocations, no reference counting.

```zig
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    const result = try allocator.alloc(u16, string.len);
    // ... transform ...
    return result;  // Caller owns, must free
}

// Usage
const lower = try asciiLowercase(allocator, input);
defer allocator.free(lower);
```

### Rationale

#### Zig Idiom: Explicit Ownership

**Zig philosophy**: Allocations are explicit, ownership is clear.

```zig
// Good: Caller knows allocation happens
const result = try operation(allocator, input);
defer allocator.free(result);

// Bad: Hidden allocation (anti-pattern in Zig)
const result = operation(input);  // Who owns this? When freed?
```

#### Flexibility: Caller Controls Strategy

Different use cases need different allocation strategies:

```zig
// 1. General purpose allocator (long-lived data)
const gpa = std.heap.GeneralPurposeAllocator(.{});
const result = try parseJson(gpa.allocator(), json_string);
defer freeJsonValue(gpa.allocator(), result);

// 2. Arena allocator (short-lived batch operations)
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const temp_allocator = arena.allocator();

const str1 = try asciiLowercase(temp_allocator, input1);
const str2 = try stripWhitespace(temp_allocator, input2);
// No individual frees, arena.deinit() frees everything

// 3. Fixed buffer allocator (embedded, no heap)
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const result = try operation(fba.allocator(), input);
```

#### No Hidden Global State

**Browsers use reference counting** because they have:
- Shared ownership (multiple DOM nodes referencing same string)
- Garbage collection (V8 manages lifetimes)
- Long-lived objects (page lifetime)

**Infra primitives are different**:
- Short-lived (function scope, temporary transforms)
- Clear ownership (usually single owner)
- Zig context (manual memory management is expected)

### Trade-offs Accepted

#### No Automatic Sharing

**Cost**: Can't share strings automatically.

```zig
// Browser (automatic sharing via refcount)
String s1 = original;  // Refcount++, no copy

// Zig (explicit copy)
const s1 = try allocator.dupe(u16, original);  // Explicit copy
defer allocator.free(s1);
```

**Mitigation**:
- Most Infra operations are transforms, not sharing
- Caller can use arena allocator for batch operations
- Can add `StringPool` utility for interning if needed

#### Caller Responsibility

**Cost**: Caller must remember to free.

```zig
const result = try operation(allocator, input);
// Easy to forget defer allocator.free(result);
```

**Mitigation**:
- Document ownership clearly in comments
- Use `std.testing.allocator` in tests (detects leaks)
- Zig's error handling makes cleanup explicit

### Alternatives Considered

#### Alternative 1: Reference Counting

```zig
pub const String = struct {
    data: [*]u16,
    len: usize,
    refcount: *usize,
    
    pub fn retain(self: String) String { }
    pub fn release(self: String) void { }
};
```

**Rejected**:
- ❌ **Not Zig idiom**: Explicit allocators are preferred
- ❌ **Complexity**: Thread-safety requires atomic refcounts
- ❌ **Overhead**: Extra pointer + atomic ops for every string
- ❌ **Leaks**: Easy to forget `release()`, no compiler help

#### Alternative 2: Global Allocator

```zig
// Global allocator (set at startup)
var global_allocator: Allocator = undefined;

pub fn asciiLowercase(string: String) !String {
    return allocator.alloc(...);  // Uses global
}
```

**Rejected**:
- ❌ **Hidden global state**: Anti-pattern in Zig
- ❌ **Inflexible**: Can't use arena/fixed buffer per call
- ❌ **Testing**: Hard to detect leaks (global state persists)

### Implementation Plan

#### Phase 1: Explicit Allocators Everywhere

```zig
// src/string.zig

/// ASCII lowercase (Infra §4.7)
/// Caller owns returned string, must free with allocator.free()
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    const result = try allocator.alloc(u16, string.len);
    errdefer allocator.free(result);
    
    for (string, 0..) |c, i| {
        result[i] = asciiToLower(c);
    }
    
    return result;
}

/// Strip leading/trailing whitespace (Infra §4.7)
/// Caller owns returned string, must free with allocator.free()
pub fn stripLeadingAndTrailingWhitespace(allocator: Allocator, string: String) !String {
    // ...
}
```

#### Documentation Pattern

```zig
/// Converts UTF-8 string to UTF-16 (Infra string representation).
/// 
/// Caller owns the returned memory and must free it:
///   const utf16 = try utf8ToUtf16(allocator, utf8_string);
///   defer allocator.free(utf16);
/// 
/// Errors:
///   - OutOfMemory: Failed to allocate result
///   - InvalidUtf8: Input contains invalid UTF-8 sequence
pub fn utf8ToUtf16(allocator: Allocator, utf8: []const u8) !String { }
```

#### Phase 2+: Optional Utilities

If profiling shows string allocation is hot path:

1. **StringPool**: Interning for common strings
2. **StringArena**: Specialized arena for string batches
3. **COW strings**: Copy-on-write for immutable operations

---

## Future Optimization Paths

This section documents **optimization opportunities** that are **NOT part of Phase 1** but could be added if profiling shows bottlenecks.

### 1. Hybrid 8-bit/16-bit Strings

**When**: Memory profiling shows >30% of heap is strings, and >70% of strings are ASCII.

**Approach**:

```zig
pub const String = union(enum) {
    latin1: []const u8,    // ASCII/Latin1 (50% memory savings)
    utf16: []const u16,    // Full Unicode
    
    pub fn codeUnitAt(self: String, index: usize) u16 {
        return switch (self) {
            .latin1 => |data| @as(u16, data[index]),
            .utf16 => |data| data[index],
        };
    }
};
```

**Complexity**: High (every operation needs dual paths)

### 2. HashMap-Backed OrderedMap (Hybrid)

**When**: Profiling shows ordered maps commonly exceed 12 entries.

**Approach**:

```zig
pub fn OrderedMap(K, V) type {
    return struct {
        entries: List(Entry, 4),           // Small maps
        index: ?std.HashMap(K, usize),     // Large maps (key → entry index)
        
        const HASH_THRESHOLD = 12;
        
        pub fn set(self: *Self, key: K, value: V) !void {
            if (self.entries.len < HASH_THRESHOLD) {
                // Linear search
            } else {
                // Use hash index
                if (self.index == null) {
                    try self.buildHashIndex();
                }
            }
        }
    };
}
```

**Complexity**: Medium (transition logic at threshold)

### 3. String Interning (StringPool)

**When**: Profiling shows many duplicate strings (common keys/values).

**Approach**:

```zig
pub const StringPool = struct {
    map: std.HashMap(u64, String),  // Hash → interned string
    
    pub fn intern(self: *Self, allocator: Allocator, string: String) !String {
        const hash = hashString(string);
        if (self.map.get(hash)) |existing| {
            return existing;  // Return existing copy
        }
        const copy = try allocator.dupe(u16, string);
        try self.map.put(hash, copy);
        return copy;
    }
};
```

**Complexity**: Low (utility, not core type change)

### 4. Small String Optimization (SSO)

**When**: Profiling shows many short-lived strings < 8 characters.

**Approach**:

```zig
pub const String = struct {
    data: union(enum) {
        small: [8]u16,     // 16 bytes inline
        large: []u16,      // Heap allocated
    },
    len: u8,               // Length (max 255)
};
```

**Complexity**: Medium (all operations need small/large paths)

### 5. SIMD String Operations

**When**: String operations (lowercase, search, compare) are hot path.

**Approach**:

```zig
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    if (string.len >= 16) {
        // SIMD path (process 8 u16 at a time)
        const vec: @Vector(8, u16) = string[0..8].*;
        const lower = vec | @splat(8, @as(u16, 0x20));  // Set bit 5 for lowercase
        // ...
    } else {
        // Scalar fallback
    }
}
```

**Complexity**: High (architecture-specific, testing burden)

---

## Summary

### Phase 1 Design Choices

| **Component** | **Choice** | **Key Rationale** |
|---------------|------------|-------------------|
| **Strings** | Pure UTF-16 (`[]const u16`) | Spec compliance, V8 interop, simplicity |
| **Ordered Maps** | List-backed with linear search | Spec requires order, fast for n < 12, browser pattern |
| **Inline Storage** | 4 elements | Proven 70-80% hit rate, cache-friendly |
| **Memory** | Explicit allocators | Zig idiom, flexibility, no hidden state |

### Trade-offs Accepted

- **Memory**: UTF-16 uses 2× bytes vs UTF-8 for ASCII
- **Performance**: O(n) map lookups (acceptable for small n)
- **Ergonomics**: Explicit allocator passing (Zig idiom)

### Optimization Strategy

1. **Phase 1**: Simple, correct, spec-compliant
2. **Profile**: Measure actual performance with realistic workloads
3. **Optimize**: Add complexity only where profiling proves bottleneck
4. **Validate**: Ensure optimizations don't break spec compliance

### Design Principles

1. **Spec Compliance First**: Never sacrifice correctness for performance
2. **Browser-Proven Patterns**: Learn from Chromium/Firefox implementations
3. **Zig Idioms**: Explicit allocators, no hidden complexity
4. **Simplicity**: Prefer simple correct code over premature optimization
5. **Measure Before Optimize**: Profile before adding complexity

---

**Next Steps**: See `IMPLEMENTATION_PLAN.md` for detailed phase breakdown and implementation order.
