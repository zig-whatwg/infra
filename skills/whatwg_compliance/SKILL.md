# WHATWG Infra Specification Compliance Skill

## When to use this skill

Load this skill automatically when:
- Implementing Infra primitives
- Understanding Infra data structure definitions
- Verifying spec compliance for Infra operations
- Mapping Infra concepts to Zig types
- Checking algorithm correctness

## What this skill provides

This skill provides **Zig implementation patterns** for WHATWG Infra Standard concepts:

- How to map Infra spec types to Zig types (list, ordered map, ordered set, string, code point)
- Complete implementation examples with numbered steps matching spec
- Documentation patterns with Infra spec references
- Memory management patterns for Infra primitives

**For the actual spec**: Read `specs/infra.md` (see whatwg_spec skill)

**This skill**: Shows HOW to implement spec concepts in idiomatic Zig

---

## What is the WHATWG Infra Standard?

### Official Specification

**Infra**: https://infra.spec.whatwg.org/

**Purpose**: "The Infra Standard aims to define the fundamental concepts upon which standards are built."

### Scope

The Infra Standard defines:

1. **§1-3 Primitives** - Bytes, code points, strings
2. **§4 Strings** - ASCII operations, whitespace, code points
3. **§5 Data structures** - Lists, ordered maps, ordered sets, stacks, queues
4. **§6 JavaScript** - JSON parsing and serialization
5. **§7 Base64** - Encoding and decoding
6. **§8 Namespaces** - HTML, SVG, MathML, XML namespace URIs

### What Infra Does NOT Define

❌ **NO domain-specific operations** - Just foundational primitives
❌ **NO HTTP client** - Just data structures
❌ **NO DOM implementation** - Foundation that DOM depends on

### Why Infra Matters

Infra is **critical for web compatibility**:
- **URL Standard** uses Infra for lists, maps, strings
- **DOM Standard** uses Infra for collections and algorithms
- **Fetch Standard** uses Infra for header maps and body streams
- **HTML Standard** uses Infra for tokens, trees, and collections

**Precision is critical**: All web standards depend on consistent Infra behavior.

---

## Infra → Zig Type Mapping

### Core Principle

Map Infra types to **idiomatic Zig** types that preserve Infra semantics and enable efficient implementation.

### Data Structures (§5)

| Infra Type | Zig Type | Notes | Spec Reference |
|------------|----------|-------|----------------|
| `list` | `std.ArrayList(T)` | Ordered, allows duplicates | §5.1 |
| `ordered map` | `OrderedMap(K, V)` | Preserves insertion order | §5.2 |
| `ordered set` | `OrderedSet(T)` | Unique items, preserves order | §5.3 |
| `stack` | `std.ArrayList(T)` | LIFO with push/pop | §5.1.1 |
| `queue` | `std.ArrayList(T)` | FIFO with enqueue/dequeue | §5.1.2 |

### Strings (§4)

| Infra Type | Zig Type | Notes | Spec Reference |
|------------|----------|-------|----------------|
| `string` | `[]const u16` | UTF-16 code units | §4 |
| `code point` | `u21` | Unicode U+0000 to U+10FFFF | §3 |
| `byte` | `u8` | Single octet | §2 |
| `byte sequence` | `[]const u8` | Sequence of bytes | §2 |

### JSON Values (§6)

| Infra Type | Zig Type | Implementation |
|------------|----------|----------------|
| `null` | `InfraValue{ .null_value = {} }` | JSON null |
| `boolean` | `InfraValue{ .boolean = bool }` | JSON true/false |
| `number` | `InfraValue{ .number = f64 }` | JSON number |
| `string` | `InfraValue{ .string = []const u8 }` | JSON string (UTF-8) |
| `array` | `InfraValue{ .list = ArrayList(InfraValue) }` | JSON array |
| `object` | `InfraValue{ .map = OrderedMap }` | JSON object |

**Implementation**:
```zig
pub const InfraValue = union(enum) {
    null_value: void,
    boolean: bool,
    number: f64,
    string: []const u8,
    list: std.ArrayList(InfraValue),
    map: OrderedMap([]const u8, InfraValue),
    
    pub fn deinit(self: InfraValue, allocator: Allocator) void {
        switch (self) {
            .string => |s| allocator.free(s),
            .list => |*l| {
                for (l.items) |item| item.deinit(allocator);
                l.deinit();
            },
            .map => |*m| m.deinit(),
            else => {},
        }
    }
};
```

---

## Infra Algorithm Patterns

### List Operations (§5.1)

**Infra Spec Pattern**:
Lists are ordered collections that can contain duplicate values.

**Zig Pattern**:
```zig
/// Append an item to a list.
///
/// Implements WHATWG Infra "append" per §5.1.
///
/// ## Spec Reference
/// https://infra.spec.whatwg.org/#list-append
///
/// ## Algorithm (Infra §5.1)
/// To append to a list is to add the given item to the end of the list.
pub fn append(list: *std.ArrayList(T), item: T) !void {
    try list.append(item);
}
```

### Example: ASCII Lowercase (§4)

**Infra Spec**:
> To ASCII lowercase a string, replace all ASCII upper alphas in the string with their corresponding code point in ASCII lower alpha.

**Zig Implementation**:
```zig
/// Converts ASCII uppercase letters to lowercase.
///
/// Implements WHATWG Infra "ASCII lowercase" per §4.
///
/// ## Spec Reference
/// https://infra.spec.whatwg.org/#ascii-lowercase
///
/// ## Algorithm (Infra §4)
/// To ASCII lowercase a string, replace all ASCII upper alphas (U+0041 A to 
/// U+005A Z) with their corresponding code point in ASCII lower alpha 
/// (U+0061 a to U+007A z).
///
/// ## Parameters
/// - `allocator`: Allocator for result string
/// - `string`: Input string (UTF-8 encoded)
///
/// ## Returns
/// New string with ASCII uppercase converted to lowercase.
pub fn asciiLowercase(allocator: Allocator, string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, string.len);
    errdefer allocator.free(result);
    
    for (string, 0..) |byte, i| {
        // ASCII upper alpha: U+0041 (A) to U+005A (Z)
        // ASCII lower alpha: U+0061 (a) to U+007A (z)
        // Difference: 0x20
        if (byte >= 'A' and byte <= 'Z') {
            result[i] = byte + 0x20;
        } else {
            result[i] = byte;
        }
    }
    
    return result;
}
```

### Example: Strip Newlines (§4)

**Infra Spec**:
> To strip newlines from a string, remove any U+000A LF and U+000D CR code points from the string.

**Zig Implementation**:
```zig
/// Removes newline characters from a string.
///
/// Implements WHATWG Infra "strip newlines" per §4.
///
/// ## Spec Reference
/// https://infra.spec.whatwg.org/#strip-newlines
///
/// ## Algorithm (Infra §4)
/// To strip newlines from a string, remove any U+000A LF and U+000D CR 
/// code points from the string.
///
/// ## Parameters
/// - `allocator`: Allocator for result string
/// - `string`: Input string
///
/// ## Returns
/// New string with newlines removed.
pub fn stripNewlines(allocator: Allocator, string: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    
    for (string) |byte| {
        // Skip U+000A LF and U+000D CR
        if (byte != '\n' and byte != '\r') {
            try result.append(byte);
        }
    }
    
    return result.toOwnedSlice();
}
```

---

## Ordered Map Implementation

For ordered maps, we need to preserve insertion order. Two approaches:

### Approach 1: Parallel Arrays (Implementation Used)

```zig
/// Ordered map that preserves insertion order.
///
/// Implements WHATWG Infra "ordered map" per §5.2.
///
/// Uses parallel arrays to maintain insertion order. Lookups are O(n) but 
/// iteration is cache-friendly and preserves order.
pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        keys: std.ArrayList(K),
        values: std.ArrayList(V),
        allocator: Allocator,
        
        const Self = @This();
        
        pub fn init(allocator: Allocator) Self {
            return .{
                .keys = std.ArrayList(K).init(allocator),
                .values = std.ArrayList(V).init(allocator),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.keys.deinit();
            self.values.deinit();
        }
        
        /// Set value for a key, updating existing or adding new entry.
        ///
        /// Implements "set" operation per Infra §5.2.
        pub fn set(self: *Self, key: K, value: V) !void {
            // Check if key exists
            for (self.keys.items, 0..) |k, i| {
                if (std.mem.eql(u8, k, key)) {
                    self.values.items[i] = value;
                    return;
                }
            }
            
            // Add new entry
            try self.keys.append(key);
            try self.values.append(value);
        }
        
        /// Get value for a key.
        ///
        /// Returns null if key not found.
        pub fn get(self: Self, key: K) ?V {
            for (self.keys.items, 0..) |k, i| {
                if (std.mem.eql(u8, k, key)) {
                    return self.values.items[i];
                }
            }
            return null;
        }
    };
}
```

---

## JSON Operations (§6)

### Parse JSON String to Infra Value

**Zig Implementation**:
```zig
/// Parses a JSON string into an Infra value.
///
/// Implements WHATWG Infra "parse JSON string to Infra value" per §6.
///
/// ## Spec Reference
/// https://infra.spec.whatwg.org/#parse-json-string-to-infra-value
///
/// ## Parameters
/// - `allocator`: Allocator for Infra value
/// - `json_string`: JSON string to parse
///
/// ## Returns
/// Infra value, or error if JSON is invalid.
pub fn parseJsonStringToInfraValue(
    allocator: Allocator,
    json_string: []const u8,
) !InfraValue {
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();
    
    return try convertJsonValueToInfraValue(allocator, parsed.value);
}

fn convertJsonValueToInfraValue(
    allocator: Allocator,
    json_value: std.json.Value,
) !InfraValue {
    switch (json_value) {
        .null => return .{ .null_value = {} },
        .bool => |b| return .{ .boolean = b },
        .integer => |i| return .{ .number = @floatFromInt(i) },
        .float => |f| return .{ .number = f },
        .string => |s| {
            const copy = try allocator.dupe(u8, s);
            return .{ .string = copy };
        },
        .array => |arr| {
            var list = std.ArrayList(InfraValue).init(allocator);
            errdefer {
                for (list.items) |item| item.deinit(allocator);
                list.deinit();
            }
            
            for (arr.items) |item| {
                const infra_item = try convertJsonValueToInfraValue(allocator, item);
                try list.append(infra_item);
            }
            
            return .{ .list = list };
        },
        .object => |obj| {
            var map = OrderedMap([]const u8, InfraValue).init(allocator);
            errdefer {
                for (map.values.items) |item| item.deinit(allocator);
                map.deinit();
            }
            
            var iter = obj.iterator();
            while (iter.next()) |entry| {
                const key = try allocator.dupe(u8, entry.key_ptr.*);
                const value = try convertJsonValueToInfraValue(allocator, entry.value_ptr.*);
                try map.set(key, value);
            }
            
            return .{ .map = map };
        },
        else => return error.InvalidJson,
    }
}
```

---

## Base64 Operations (§7)

### Forgiving Base64 Decode

**Infra Spec** (simplified):
> 1. Remove all ASCII whitespace from data.
> 2. If data's code point length divides by 4 leaving no remainder, remove trailing '=' characters.
> 3. If data's code point length divides by 4 leaving a remainder of 1, return failure.
> 4. Validate character set.
> 5. Decode using base64 alphabet.

**Zig Implementation**:
```zig
/// Decodes a base64 string with forgiving error handling.
///
/// Implements WHATWG Infra "forgiving-base64 decode" per §7.
///
/// ## Spec Reference
/// https://infra.spec.whatwg.org/#forgiving-base64-decode
///
/// ## Parameters
/// - `allocator`: Allocator for output bytes
/// - `data`: Base64 string to decode
///
/// ## Returns
/// Decoded byte sequence, or error if invalid base64.
pub fn forgivingBase64Decode(
    allocator: Allocator,
    data: []const u8,
) ![]u8 {
    // 1. Remove all ASCII whitespace from data
    const cleaned = try removeAsciiWhitespace(allocator, data);
    defer allocator.free(cleaned);
    
    var working = cleaned;
    
    // 2. If length divides by 4 with no remainder, remove trailing '='
    if (working.len % 4 == 0) {
        if (working.len >= 2 and 
            working[working.len - 1] == '=' and 
            working[working.len - 2] == '=') {
            working = working[0..working.len - 2];
        } else if (working.len >= 1 and working[working.len - 1] == '=') {
            working = working[0..working.len - 1];
        }
    }
    
    // 3. If length divides by 4 leaving remainder of 1, return error
    if (working.len % 4 == 1) {
        return error.InvalidBase64;
    }
    
    // 4. Validate characters
    for (working) |byte| {
        if (!isBase64Char(byte)) {
            return error.InvalidBase64;
        }
    }
    
    // 5. Decode using standard base64
    const decoder = std.base64.standard.Decoder;
    const max_size = try decoder.calcSizeForSlice(working);
    const output = try allocator.alloc(u8, max_size);
    errdefer allocator.free(output);
    
    const decoded_len = try decoder.decode(output, working);
    return try allocator.realloc(output, decoded_len);
}
```

---

## Implementation Workflow

### Step 1: Read Complete Infra Section

**NEVER use grep**. Load complete section from `specs/infra.md`:
1. **Section introduction** - Understand context and purpose
2. **ALL algorithm steps** - Don't skip any steps
3. **Related algorithms** - Cross-references matter
4. **Examples** - Show expected behavior

### Step 2: Map Types to Zig

Use the type mapping table in this skill:
- Identify input types
- Identify output types
- Identify intermediate types
- Choose appropriate Zig types

### Step 3: Implement Algorithm Precisely

**Follow spec steps exactly**:
```zig
pub fn algorithmName(...) !ReturnType {
    // 1. [First step from spec - use numbered comment]
    
    // 2. [Second step from spec]
    
    // 3. [Third step from spec]
    
    // Return [what spec says to return]
}
```

### Step 4: Document with Spec References

**Required documentation**:
1. Brief description
2. "Implements WHATWG Infra [algorithm] per §X"
3. Spec reference URL
4. Complete algorithm (paste from spec or summarize)
5. Parameter descriptions
6. Return value description

### Step 5: Test Thoroughly

Write tests for:
- Happy path (normal case)
- Edge cases (empty, boundary values)
- Error cases (invalid input)
- Memory safety (no leaks with std.testing.allocator)

---

## Verification Checklist

Before marking any implementation complete:

- [ ] Read **complete** Infra section (not grep snippet)
- [ ] Read **all algorithm steps** (don't skip any)
- [ ] Checked type mapping (Infra → Zig)
- [ ] Implemented all steps precisely (numbered comments)
- [ ] Tested happy path, edge cases, errors
- [ ] No memory leaks (verified with std.testing.allocator)
- [ ] Documentation includes spec reference URL
- [ ] Documentation includes complete algorithm from spec
- [ ] Code matches spec behavior exactly

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Wrong Type Mapping

```zig
// WRONG: Using HashMap for ordered map (doesn't preserve order!)
pub const OrderedMap = std.StringHashMap(Value);

// RIGHT: Custom implementation that preserves insertion order
pub const OrderedMap = struct {
    keys: std.ArrayList([]const u8),
    values: std.ArrayList(Value),
    // Preserves order!
};
```

### ❌ Mistake 2: Incomplete Algorithm

```zig
// WRONG: Only removing \n, not \r
pub fn stripNewlines(allocator: Allocator, string: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    for (string) |byte| {
        if (byte != '\n') try result.append(byte);
    }
    return result.toOwnedSlice();
}

// RIGHT: Following spec completely
pub fn stripNewlines(allocator: Allocator, string: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    for (string) |byte| {
        // Spec: "remove any U+000A LF and U+000D CR"
        if (byte != '\n' and byte != '\r') {
            try result.append(byte);
        }
    }
    return result.toOwnedSlice();
}
```

---

## Best Practices

1. **Read complete sections** - Context prevents bugs
2. **Number comments match spec steps** - Makes verification easy
3. **Paste algorithm into docs** - Ensures you don't miss steps
4. **Check cross-references** - Spec often references related algorithms
5. **Use exact terminology** - If spec says "list", call it list, not array

---

## Integration with Other Skills

This skill coordinates with:
- **zig_standards** - Provides Zig idioms for implementing algorithms
- **testing_requirements** - Defines how to test spec compliance
- **documentation_standards** - Format for spec references in docs
- **performance_optimization** - When to optimize beyond spec requirements

Load all relevant skills together for complete implementation guidance.

---

## Quick Reference

### Type Mapping Quick Lookup

```
list            → std.ArrayList(T)
ordered map     → OrderedMap(K, V) (custom, preserves order)
ordered set     → OrderedSet(T) (custom, preserves order)
string          → []const u16 (UTF-16)
code point      → u21
byte            → u8
byte sequence   → []const u8
```

### Algorithm Template

```zig
/// [Brief description]
///
/// Implements WHATWG Infra "[name]" per §X.
///
/// ## Spec Reference
/// https://infra.spec.whatwg.org/#[anchor]
///
/// ## Algorithm (Infra §X)
/// [Paste complete algorithm or summarize steps]
///
/// ## Parameters
/// - `param`: Description
///
/// ## Returns
/// Description of return value
pub fn name(param: Type) !ReturnType {
    // 1. [First step]
    // 2. [Second step]
    // ...
}
```

---

**Remember**: Infra is the foundation for all WHATWG specs. Precision is critical because bugs cascade to every dependent specification.
