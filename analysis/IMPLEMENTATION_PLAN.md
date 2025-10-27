# Implementation Plan: Zig WHATWG Infra

**Last Updated**: 2025-10-27  
**Status**: Phase 1 Ready to Start

---

## Table of Contents

1. [Overview](#overview)
2. [Phase Breakdown](#phase-breakdown)
3. [Phase 1: Foundation - Strings & Primitives](#phase-1-foundation---strings--primitives)
4. [Phase 2: Collections](#phase-2-collections)
5. [Phase 3: Advanced Primitives](#phase-3-advanced-primitives)
6. [Phase 4: Serialization & Encoding](#phase-4-serialization--encoding)
7. [Phase 5: Integration & Polish](#phase-5-integration--polish)
8. [Testing Strategy](#testing-strategy)
9. [File Organization](#file-organization)

---

## Overview

### Goals

1. **Complete WHATWG Infra implementation** (~120 operations from spec)
2. **Production-ready quality** (zero leaks, full test coverage, comprehensive docs)
3. **V8 interop ready** (UTF-16 strings, zero-copy where possible)
4. **Zig idiomatic** (explicit allocators, error handling, comptime)

### Implementation Approach

- **TDD (Test-Driven Development)**: Write tests first, then implement
- **Incremental**: Build in phases, each phase fully tested
- **Spec-first**: Implement algorithms exactly as specified
- **Document as you go**: Inline docs + CHANGELOG updates

### Success Criteria

Each phase complete when:
- ✅ All operations implemented and tested
- ✅ Zero memory leaks (verified with `std.testing.allocator`)
- ✅ Full documentation (inline + examples)
- ✅ CHANGELOG.md updated
- ✅ Integration tests pass

---

## Phase Breakdown

| **Phase** | **Focus** | **Operations** | **Files** | **Est. Time** |
|-----------|-----------|----------------|-----------|---------------|
| **1** | Strings & Primitives | 40+ | `string.zig`, `code_point.zig`, `bytes.zig` | 2 weeks |
| **2** | Collections | 25+ | `list.zig`, `map.zig`, `set.zig`, `stack.zig`, `queue.zig` | 1 week |
| **3** | Advanced Primitives | 15+ | `struct.zig`, `tuple.zig` | 3 days |
| **4** | Serialization & Encoding | 20+ | `json.zig`, `base64.zig`, `namespaces.zig` | 1 week |
| **5** | Integration & Polish | - | `infra.zig`, examples, docs | 3 days |

**Total Estimated Time**: 4-5 weeks for complete implementation

---

## Phase 1: Foundation - Strings & Primitives

**Goal**: Implement core string operations and primitive types.

### 1.1 String Type & Conversion (Priority: Critical)

**File**: `src/string.zig`

**Operations**:
1. `String` type definition (`[]const u16`)
2. `utf8ToUtf16()` - Convert UTF-8 → UTF-16
3. `utf16ToUtf8()` - Convert UTF-16 → UTF-8

**Tests** (`tests/unit/string_conversion_test.zig`):
```zig
test "utf8ToUtf16 - ASCII string" { }
test "utf8ToUtf16 - Unicode (BMP)" { }
test "utf8ToUtf16 - Unicode (surrogate pairs)" { }
test "utf8ToUtf16 - invalid UTF-8" { }
test "utf16ToUtf8 - ASCII string" { }
test "utf16ToUtf8 - Unicode (BMP)" { }
test "utf16ToUtf8 - surrogate pairs" { }
test "utf16ToUtf8 - unpaired surrogates" { }
test "conversion roundtrip - ASCII" { }
test "conversion roundtrip - Unicode" { }
```

**Dependencies**: None

**Completion Criteria**:
- ✅ UTF-8 ↔ UTF-16 bidirectional conversion
- ✅ Surrogate pair handling (encode/decode U+10000..U+10FFFF)
- ✅ Invalid input error handling
- ✅ Zero memory leaks

### 1.2 String Operations - ASCII (Priority: High)

**File**: `src/string.zig`

**Operations** (Infra §4.7):
1. `asciiLowercase()` - Convert ASCII uppercase → lowercase
2. `asciiUppercase()` - Convert ASCII lowercase → uppercase
3. `isAsciiString()` - Check if all code units are ASCII
4. `isAsciiCaseInsensitiveMatch()` - Compare strings ignoring ASCII case
5. `asciiByteLength()` - Length in bytes (error if non-ASCII)

**Tests** (`tests/unit/string_ascii_test.zig`):
```zig
test "asciiLowercase - ASCII uppercase" { }
test "asciiLowercase - mixed case" { }
test "asciiLowercase - already lowercase" { }
test "asciiLowercase - non-ASCII unchanged" { }
test "asciiUppercase - ASCII lowercase" { }
test "isAsciiString - pure ASCII" { }
test "isAsciiString - contains Unicode" { }
test "isAsciiCaseInsensitiveMatch - match" { }
test "isAsciiCaseInsensitiveMatch - no match" { }
test "asciiByteLength - ASCII string" { }
test "asciiByteLength - non-ASCII error" { }
```

**Dependencies**: String type (1.1)

**Completion Criteria**:
- ✅ All ASCII operations implemented
- ✅ Non-ASCII characters preserved (lowercasing doesn't affect them)
- ✅ Memory safety (allocations freed)

### 1.3 String Operations - Whitespace (Priority: High)

**File**: `src/string.zig`

**Operations** (Infra §4.7):
1. `isAsciiWhitespace()` - Check if code unit is whitespace (U+0009..U+000D, U+0020)
2. `stripLeadingAndTrailingAsciiWhitespace()` - Remove leading/trailing whitespace
3. `stripNewlines()` - Remove U+000A and U+000D
4. `normalizeNewlines()` - Replace U+000D U+000A and U+000D with U+000A

**Tests** (`tests/unit/string_whitespace_test.zig`):
```zig
test "isAsciiWhitespace - tab, newline, space" { }
test "isAsciiWhitespace - non-whitespace" { }
test "stripLeadingAndTrailingAsciiWhitespace - both ends" { }
test "stripLeadingAndTrailingAsciiWhitespace - leading only" { }
test "stripLeadingAndTrailingAsciiWhitespace - trailing only" { }
test "stripLeadingAndTrailingAsciiWhitespace - none" { }
test "stripNewlines - LF and CR" { }
test "stripNewlines - no newlines" { }
test "normalizeNewlines - CRLF to LF" { }
test "normalizeNewlines - CR to LF" { }
test "normalizeNewlines - LF unchanged" { }
```

**Dependencies**: String type (1.1)

### 1.4 String Operations - Parsing (Priority: High)

**File**: `src/string.zig`

**Operations** (Infra §4.7):
1. `splitOnAsciiWhitespace()` - Split on whitespace, skip empty
2. `splitOnCommas()` - Split on U+002C, strip whitespace
3. `collectCodePoints()` - Match predicate, return matched positions
4. `concatenate()` - Join multiple strings

**Tests** (`tests/unit/string_parsing_test.zig`):
```zig
test "splitOnAsciiWhitespace - single space" { }
test "splitOnAsciiWhitespace - multiple spaces" { }
test "splitOnAsciiWhitespace - mixed whitespace" { }
test "splitOnAsciiWhitespace - empty string" { }
test "splitOnCommas - basic" { }
test "splitOnCommas - with whitespace" { }
test "splitOnCommas - empty string" { }
test "collectCodePoints - match predicate" { }
test "concatenate - multiple strings" { }
test "concatenate - empty list" { }
```

**Dependencies**: String type (1.1)

### 1.5 Code Point Operations (Priority: High)

**File**: `src/code_point.zig`

**Operations** (Infra §4.6):

**Type Predicates**:
1. `isSurrogate()` - U+D800..U+DFFF
2. `isScalarValue()` - Not a surrogate
3. `isNoncharacter()` - 66 noncharacter code points
4. `isAsciiCodePoint()` - U+0000..U+007F
5. `isAsciiTabOrNewline()` - U+0009, U+000A, U+000D
6. `isAsciiWhitespaceCodePoint()` - U+0009..U+000D, U+0020
7. `isC0Control()` - U+0000..U+001F
8. `isC0ControlOrSpace()` - C0 control or U+0020
9. `isControl()` - C0 control or U+007F..U+009F
10. `isAsciiDigit()` - U+0030..U+0039
11. `isAsciiUpperHexDigit()` - U+0030..U+0039, U+0041..U+0046
12. `isAsciiLowerHexDigit()` - U+0030..U+0039, U+0061..U+0066
13. `isAsciiHexDigit()` - Upper or lower hex digit
14. `isAsciiUpperAlpha()` - U+0041..U+005A
15. `isAsciiLowerAlpha()` - U+0061..U+007A
16. `isAsciiAlpha()` - Upper or lower alpha
17. `isAsciiAlphanumeric()` - Alpha or digit

**Surrogate Pair Operations**:
18. `isLeadSurrogate()` - U+D800..U+DBFF
19. `isTrailSurrogate()` - U+DC00..U+DFFF
20. `encodeSurrogatePair()` - Encode U+10000..U+10FFFF as pair
21. `decodeSurrogatePair()` - Decode pair to code point

**Tests** (`tests/unit/code_point_test.zig`):
```zig
// 19 predicate tests (happy path + edge cases)
test "isSurrogate - lead surrogate" { }
test "isSurrogate - trail surrogate" { }
test "isSurrogate - non-surrogate" { }
// ... 16 more predicates

// Surrogate pair encoding/decoding
test "encodeSurrogatePair - U+10000" { }
test "encodeSurrogatePair - U+10FFFF" { }
test "encodeSurrogatePair - invalid (too large)" { }
test "decodeSurrogatePair - valid pair" { }
test "decodeSurrogatePair - invalid pair" { }
test "surrogate roundtrip - encode then decode" { }
```

**Dependencies**: None

### 1.6 Byte Sequences (Priority: Medium)

**File**: `src/bytes.zig`

**Operations** (Infra §4.5):
1. `ByteSequence` type (`[]const u8`)
2. `byteLessThan()` - Lexicographic comparison
3. `isAsciiByteSequence()` - All bytes < 0x80
4. `decodeAsUtf8()` - Decode to string (UTF-16)
5. `utf8Encode()` - Encode string (UTF-16) to UTF-8 bytes
6. `isomorphicDecode()` - Convert byte sequence to string (1:1 mapping)
7. `isomorphicEncode()` - Convert string to byte sequence (error if > 0xFF)

**Tests** (`tests/unit/bytes_test.zig`):
```zig
test "byteLessThan - less than" { }
test "byteLessThan - equal" { }
test "byteLessThan - greater than" { }
test "isAsciiByteSequence - pure ASCII" { }
test "isAsciiByteSequence - contains high byte" { }
test "decodeAsUtf8 - valid UTF-8" { }
test "decodeAsUtf8 - invalid UTF-8" { }
test "utf8Encode - ASCII" { }
test "utf8Encode - Unicode BMP" { }
test "utf8Encode - surrogate pairs" { }
test "isomorphicDecode - byte sequence to string" { }
test "isomorphicEncode - string to bytes" { }
test "isomorphicEncode - error on high code unit" { }
```

**Dependencies**: String type (1.1), Code point operations (1.5)

### Phase 1 Completion Checklist

- [ ] All operations implemented (40+)
- [ ] All tests passing (100+ test cases)
- [ ] Zero memory leaks (verified with `std.testing.allocator`)
- [ ] Inline documentation complete (spec references)
- [ ] CHANGELOG.md updated
- [ ] README.md updated (Phase 1 complete)

---

## Phase 2: Collections

**Goal**: Implement Infra data structures (list, map, set, stack, queue).

### 2.1 List Operations (Priority: Critical)

**File**: `src/list.zig`

**Type Definition**:
```zig
pub fn List(comptime T: type, comptime inline_capacity: usize) type {
    return struct {
        inline_storage: [inline_capacity]T,
        heap_storage: ?std.ArrayList(T),
        len: usize,
        allocator: Allocator,
    };
}

pub fn ListDefault(comptime T: type) type {
    return List(T, 4);  // 4-element inline storage
}
```

**Operations** (Infra §5.1):
1. `init()` / `deinit()` - Create/destroy list
2. `append()` - Add item to end
3. `prepend()` - Add item to start (insert at index 0)
4. `insert()` - Insert at arbitrary index
5. `remove()` - Remove item at index
6. `replace()` - Replace item at index
7. `contains()` - Check if item exists
8. `size()` - Number of items (`.len`)
9. `isEmpty()` - Check if size is 0
10. `clear()` - Remove all items
11. `clone()` - Deep copy
12. `extend()` - Append another list
13. `sort()` - Sort with comparator

**Tests** (`tests/unit/list_test.zig`):
```zig
test "List - init and deinit" { }
test "List - append to inline storage" { }
test "List - append exceeds inline (spill to heap)" { }
test "List - prepend" { }
test "List - insert at middle" { }
test "List - insert at start" { }
test "List - insert at end" { }
test "List - remove from middle" { }
test "List - replace" { }
test "List - contains" { }
test "List - size and isEmpty" { }
test "List - clear" { }
test "List - clone" { }
test "List - extend" { }
test "List - sort" { }
test "List - no memory leaks" { }
```

**Dependencies**: None (uses stdlib ArrayList for heap)

### 2.2 Ordered Map Operations (Priority: Critical)

**File**: `src/map.zig`

**Type Definition**:
```zig
pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return struct {
        entries: List(Entry, 4),  // 4-entry inline storage
        allocator: Allocator,
        
        pub const Entry = struct {
            key: K,
            value: V,
        };
    };
}
```

**Operations** (Infra §5.2):
1. `init()` / `deinit()` - Create/destroy map
2. `get()` - Get value by key (returns `?V`)
3. `set()` - Set key-value pair (insert or update)
4. `remove()` - Remove entry by key
5. `contains()` - Check if key exists
6. `keys()` - Iterator over keys (insertion order)
7. `values()` - Iterator over values (insertion order)
8. `entries()` - Iterator over (key, value) pairs (insertion order)
9. `size()` - Number of entries
10. `isEmpty()` - Check if size is 0
11. `clear()` - Remove all entries
12. `clone()` - Deep copy

**Tests** (`tests/unit/map_test.zig`):
```zig
test "OrderedMap - init and deinit" { }
test "OrderedMap - set and get" { }
test "OrderedMap - set updates existing key" { }
test "OrderedMap - get nonexistent key returns null" { }
test "OrderedMap - remove existing key" { }
test "OrderedMap - remove nonexistent key (no-op)" { }
test "OrderedMap - contains" { }
test "OrderedMap - keys preserves insertion order" { }
test "OrderedMap - values preserves insertion order" { }
test "OrderedMap - entries preserves insertion order" { }
test "OrderedMap - size and isEmpty" { }
test "OrderedMap - clear" { }
test "OrderedMap - clone" { }
test "OrderedMap - inline storage (4 entries)" { }
test "OrderedMap - exceeds inline storage (spill to heap)" { }
test "OrderedMap - no memory leaks" { }
```

**Dependencies**: List (2.1)

### 2.3 Ordered Set Operations (Priority: High)

**File**: `src/set.zig`

**Type Definition**:
```zig
pub fn OrderedSet(comptime T: type) type {
    return struct {
        items: List(T, 4),  // 4-element inline storage
        allocator: Allocator,
    };
}
```

**Operations** (Infra §5.1.3):
1. `init()` / `deinit()` - Create/destroy set
2. `add()` - Add item (no duplicates)
3. `remove()` - Remove item
4. `contains()` - Check if item exists
5. `size()` - Number of items
6. `isEmpty()` - Check if size is 0
7. `clear()` - Remove all items
8. `iterator()` - Iterate in insertion order
9. `clone()` - Deep copy

**Tests** (`tests/unit/set_test.zig`):
```zig
test "OrderedSet - init and deinit" { }
test "OrderedSet - add unique items" { }
test "OrderedSet - add duplicate (no-op)" { }
test "OrderedSet - remove existing item" { }
test "OrderedSet - remove nonexistent item (no-op)" { }
test "OrderedSet - contains" { }
test "OrderedSet - size and isEmpty" { }
test "OrderedSet - clear" { }
test "OrderedSet - iterator preserves insertion order" { }
test "OrderedSet - clone" { }
test "OrderedSet - no memory leaks" { }
```

**Dependencies**: List (2.1)

### 2.4 Stack and Queue (Priority: Medium)

**File**: `src/stack.zig`, `src/queue.zig`

**Stack Operations** (Infra §5.3):
1. `init()` / `deinit()` - Create/destroy stack
2. `push()` - Push item on top
3. `pop()` - Pop item from top (returns `?T`)
4. `peek()` - View top item without removing (returns `?T`)
5. `isEmpty()` - Check if empty

**Queue Operations** (Infra §5.4):
1. `init()` / `deinit()` - Create/destroy queue
2. `enqueue()` - Add item to back
3. `dequeue()` - Remove item from front (returns `?T`)
4. `peek()` - View front item without removing (returns `?T`)
5. `isEmpty()` - Check if empty

**Tests** (`tests/unit/stack_test.zig`, `tests/unit/queue_test.zig`):
```zig
// Stack
test "Stack - push and pop" { }
test "Stack - pop empty returns null" { }
test "Stack - peek" { }
test "Stack - isEmpty" { }
test "Stack - LIFO order" { }
test "Stack - no memory leaks" { }

// Queue
test "Queue - enqueue and dequeue" { }
test "Queue - dequeue empty returns null" { }
test "Queue - peek" { }
test "Queue - isEmpty" { }
test "Queue - FIFO order" { }
test "Queue - no memory leaks" { }
```

**Dependencies**: List (2.1) - stack/queue are thin wrappers

### Phase 2 Completion Checklist

- [ ] All operations implemented (25+)
- [ ] All tests passing (60+ test cases)
- [ ] Zero memory leaks
- [ ] Inline documentation complete
- [ ] CHANGELOG.md updated
- [ ] README.md updated (Phase 2 complete)

---

## Phase 3: Advanced Primitives

**Goal**: Implement structs and tuples.

### 3.1 Struct Operations (Priority: Medium)

**File**: `src/struct.zig`

**Type Pattern**:
```zig
// Infra struct maps to Zig struct with named fields
pub fn InfraStruct(comptime fields: []const FieldDef) type {
    return struct {
        // Comptime-generated fields
    };
}

pub const FieldDef = struct {
    name: []const u8,
    type: type,
};
```

**Operations** (Infra §5.5):
1. `createStruct()` - Define struct with named fields
2. `getField()` - Access field by name
3. `setField()` - Update field by name

**Tests** (`tests/unit/struct_test.zig`):
```zig
test "Struct - create with fields" { }
test "Struct - get field" { }
test "Struct - set field" { }
test "Struct - field not found" { }
```

**Dependencies**: None

### 3.2 Tuple Operations (Priority: Medium)

**File**: `src/tuple.zig`

**Type Pattern**:
```zig
// Infra tuple maps to Zig tuple (anonymous struct with indexed fields)
pub fn Tuple(comptime types: []const type) type {
    // Returns tuple type with indexed access
}
```

**Operations** (Infra §5.6):
1. `createTuple()` - Create tuple with ordered values
2. `getElement()` - Access element by index
3. `setElement()` - Update element by index

**Tests** (`tests/unit/tuple_test.zig`):
```zig
test "Tuple - create with values" { }
test "Tuple - get element by index" { }
test "Tuple - set element by index" { }
test "Tuple - index out of bounds" { }
```

**Dependencies**: None

### Phase 3 Completion Checklist

- [ ] All operations implemented (6)
- [ ] All tests passing (8+ test cases)
- [ ] Inline documentation complete
- [ ] CHANGELOG.md updated

---

## Phase 4: Serialization & Encoding

**Goal**: Implement JSON parsing/serialization and Base64 encoding/decoding.

### 4.1 JSON - Infra Value Type (Priority: High)

**File**: `src/json.zig`

**Type Definition**:
```zig
pub const InfraValue = union(enum) {
    null_value,
    boolean: bool,
    number: f64,
    string: String,                    // UTF-16
    list: List(InfraValue, 4),
    map: OrderedMap(String, InfraValue),
    
    pub fn deinit(self: InfraValue, allocator: Allocator) void { }
};
```

**Dependencies**: String, List, OrderedMap

### 4.2 JSON - Parsing (Priority: High)

**File**: `src/json.zig`

**Operations** (Infra §6.2):
1. `parseJsonString()` - Parse JSON string to InfraValue
2. `parseJsonBytes()` - Parse JSON bytes to InfraValue

**Spec Algorithm** (Infra §6.2):
1. Let `jsonText` be result of running UTF-8 decode on bytes
2. Parse `jsonText` according to JSON grammar (RFC 8259)
3. Return abstract data structure

**Tests** (`tests/unit/json_parse_test.zig`):
```zig
test "parseJson - null" { }
test "parseJson - boolean (true, false)" { }
test "parseJson - number (integer)" { }
test "parseJson - number (float)" { }
test "parseJson - string (ASCII)" { }
test "parseJson - string (Unicode)" { }
test "parseJson - string (escape sequences)" { }
test "parseJson - array (empty)" { }
test "parseJson - array (mixed types)" { }
test "parseJson - object (empty)" { }
test "parseJson - object (simple)" { }
test "parseJson - object (nested)" { }
test "parseJson - invalid JSON (syntax error)" { }
test "parseJson - no memory leaks" { }
```

**Dependencies**: InfraValue (4.1), String

### 4.3 JSON - Serialization (Priority: High)

**File**: `src/json.zig`

**Operations** (Infra §6.3):
1. `serializeInfraValue()` - Serialize InfraValue to JSON string

**Spec Algorithm** (Infra §6.3):
1. Let `result` be empty string
2. Serialize value according to type:
   - null → "null"
   - boolean → "true" or "false"
   - number → ASCII representation
   - string → quoted, escaped
   - list → [ ... ]
   - map → { ... } (preserves insertion order)
3. Return result

**Tests** (`tests/unit/json_serialize_test.zig`):
```zig
test "serializeJson - null" { }
test "serializeJson - boolean (true, false)" { }
test "serializeJson - number (integer)" { }
test "serializeJson - number (float)" { }
test "serializeJson - string (ASCII)" { }
test "serializeJson - string (Unicode)" { }
test "serializeJson - string (escape sequences)" { }
test "serializeJson - list (empty)" { }
test "serializeJson - list (mixed types)" { }
test "serializeJson - map (empty)" { }
test "serializeJson - map (simple)" { }
test "serializeJson - map (preserves insertion order)" { }
test "serializeJson - roundtrip (parse then serialize)" { }
test "serializeJson - no memory leaks" { }
```

**Dependencies**: InfraValue (4.1), String

### 4.4 Base64 Encoding/Decoding (Priority: Medium)

**File**: `src/base64.zig`

**Operations** (Infra §7):
1. `forgivingBase64Encode()` - Encode bytes to Base64 string
2. `forgivingBase64Decode()` - Decode Base64 string to bytes (ignores whitespace)

**Spec Algorithm** (Infra §7):
1. **Encode**: Standard Base64 (RFC 4648 §4)
2. **Decode**: "Forgiving" - strips ASCII whitespace before decoding

**Tests** (`tests/unit/base64_test.zig`):
```zig
test "base64Encode - empty" { }
test "base64Encode - single byte" { }
test "base64Encode - multiple bytes" { }
test "base64Encode - padding (1 byte)" { }
test "base64Encode - padding (2 bytes)" { }
test "base64Decode - empty" { }
test "base64Decode - valid Base64" { }
test "base64Decode - forgiving (whitespace)" { }
test "base64Decode - invalid characters" { }
test "base64Decode - roundtrip" { }
test "base64 - no memory leaks" { }
```

**Dependencies**: Bytes

### 4.5 Namespaces (Priority: Low)

**File**: `src/namespaces.zig`

**Operations** (Infra §8):
```zig
pub const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
pub const MATHML_NAMESPACE = "http://www.w3.org/1998/Math/MathML";
pub const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
pub const XLINK_NAMESPACE = "http://www.w3.org/1999/xlink";
pub const XML_NAMESPACE = "http://www.w3.org/XML/1998/namespace";
pub const XMLNS_NAMESPACE = "http://www.w3.org/2000/xmlns/";
```

**Tests** (`tests/unit/namespaces_test.zig`):
```zig
test "HTML namespace constant" { }
test "MathML namespace constant" { }
test "SVG namespace constant" { }
test "XLink namespace constant" { }
test "XML namespace constant" { }
test "XMLNS namespace constant" { }
```

**Dependencies**: None

### Phase 4 Completion Checklist

- [ ] All operations implemented (20+)
- [ ] All tests passing (50+ test cases)
- [ ] Zero memory leaks
- [ ] Inline documentation complete
- [ ] CHANGELOG.md updated
- [ ] README.md updated (Phase 4 complete)

---

## Phase 5: Integration & Polish

**Goal**: Create unified API, examples, and final documentation.

### 5.1 Unified API (Priority: High)

**File**: `src/infra.zig`

**Purpose**: Single import for all Infra operations.

```zig
// src/infra.zig

// Re-export all modules
pub const string = @import("string.zig");
pub const bytes = @import("bytes.zig");
pub const code_point = @import("code_point.zig");
pub const list = @import("list.zig");
pub const map = @import("map.zig");
pub const set = @import("set.zig");
pub const stack = @import("stack.zig");
pub const queue = @import("queue.zig");
pub const json = @import("json.zig");
pub const base64 = @import("base64.zig");
pub const namespaces = @import("namespaces.zig");

// Common types
pub const String = string.String;
pub const ByteSequence = bytes.ByteSequence;
pub const InfraValue = json.InfraValue;

pub fn List(comptime T: type) type {
    return list.ListDefault(T);
}

pub fn OrderedMap(comptime K: type, comptime V: type) type {
    return map.OrderedMap(K, V);
}

pub fn OrderedSet(comptime T: type) type {
    return set.OrderedSet(T);
}
```

**Usage**:
```zig
const infra = @import("infra");

const allocator = std.heap.page_allocator;

// String operations
const lower = try infra.string.asciiLowercase(allocator, input);
defer allocator.free(lower);

// Collections
var list = infra.List(u32).init(allocator);
defer list.deinit();
try list.append(42);

// JSON
const value = try infra.json.parseJsonString(allocator, json_str);
defer value.deinit(allocator);
```

### 5.2 Integration Tests (Priority: High)

**File**: `tests/integration/infra_integration_test.zig`

**Purpose**: Test realistic workflows using multiple Infra operations together.

**Test Scenarios**:
```zig
test "Integration - parse JSON, transform strings, serialize" {
    // Parse JSON object
    const json_str = "{\"name\": \"ALICE\", \"age\": 30}";
    const value = try parseJsonString(allocator, json_str);
    defer value.deinit(allocator);
    
    // Extract map
    const map = value.map;
    
    // Transform name to lowercase
    const name = map.get("name").?.string;
    const lower = try asciiLowercase(allocator, name);
    defer allocator.free(lower);
    
    // Build new value
    var result_map = OrderedMap(String, InfraValue).init(allocator);
    try result_map.set("name", .{ .string = lower });
    try result_map.set("age", .{ .number = 30 });
    
    // Serialize back to JSON
    const result_json = try serializeInfraValue(allocator, .{ .map = result_map });
    defer allocator.free(result_json);
    
    // Verify
    try expectEqualStrings("{\"name\":\"alice\",\"age\":30}", result_json);
}

test "Integration - Base64 encode data, parse as JSON" { }
test "Integration - List operations with string values" { }
test "Integration - OrderedMap with complex values" { }
```

### 5.3 Examples (Priority: Medium)

**Files**: `examples/*.zig`

**Examples**:
1. `string_processing.zig` - String conversions and transforms
2. `json_parsing.zig` - Parse and serialize JSON
3. `collections.zig` - Working with lists, maps, sets
4. `base64_encoding.zig` - Encode/decode Base64

### 5.4 Documentation Polish (Priority: High)

**Files to Update**:
1. `README.md` - Complete usage guide, API overview
2. `CHANGELOG.md` - v0.1.0 release notes
3. `CONTRIBUTING.md` - Development workflow, testing
4. `docs/API.md` - Complete API reference (generated from inline docs)

**README.md Structure**:
```markdown
# WHATWG Infra for Zig

Complete implementation of WHATWG Infra Standard in Zig.

## Features

- ✅ Strings (UTF-16, 30+ operations)
- ✅ Collections (List, OrderedMap, OrderedSet, Stack, Queue)
- ✅ JSON (parse, serialize)
- ✅ Base64 (forgiving encode/decode)
- ✅ Zero dependencies (except Zig stdlib)
- ✅ Memory safe (zero leaks)
- ✅ Production ready (full test coverage)

## Installation

## Quick Start

## API Overview

## Examples

## Contributing

## License
```

### Phase 5 Completion Checklist

- [ ] Unified API (`src/infra.zig`)
- [ ] Integration tests (5+ scenarios)
- [ ] Examples (4+ examples)
- [ ] README.md complete
- [ ] API.md generated
- [ ] CONTRIBUTING.md updated
- [ ] CHANGELOG.md (v0.1.0 release)
- [ ] All documentation reviewed

---

## Testing Strategy

### Test Organization

```
tests/
├── unit/
│   ├── string_conversion_test.zig
│   ├── string_ascii_test.zig
│   ├── string_whitespace_test.zig
│   ├── string_parsing_test.zig
│   ├── code_point_test.zig
│   ├── bytes_test.zig
│   ├── list_test.zig
│   ├── map_test.zig
│   ├── set_test.zig
│   ├── stack_test.zig
│   ├── queue_test.zig
│   ├── json_parse_test.zig
│   ├── json_serialize_test.zig
│   ├── base64_test.zig
│   └── namespaces_test.zig
└── integration/
    └── infra_integration_test.zig
```

### Test Coverage Requirements

Each operation must have tests for:
1. **Happy path** - Normal usage
2. **Edge cases** - Empty input, boundary values, large input
3. **Error cases** - Invalid input, out of bounds, allocation failure
4. **Memory safety** - Zero leaks (verified with `std.testing.allocator`)

### TDD Workflow

For each operation:
1. **Write test first** (failing test)
2. **Implement operation** (make test pass)
3. **Verify memory safety** (no leaks)
4. **Document operation** (inline docs with spec reference)
5. **Update CHANGELOG.md**

### Example Test Pattern

```zig
test "operation_name - scenario" {
    const allocator = std.testing.allocator;  // Detects leaks
    
    // Setup
    const input = ...;
    
    // Execute
    const result = try operation(allocator, input);
    defer allocator.free(result);  // Cleanup
    
    // Verify
    try std.testing.expectEqual(expected, result);
}
```

### Memory Leak Detection

**All tests must use `std.testing.allocator`**:

```zig
test "example - no leaks" {
    const allocator = std.testing.allocator;
    
    const data = try allocator.alloc(u8, 100);
    defer allocator.free(data);  // If missing, test FAILS
    
    // ... use data ...
}
```

If cleanup is missing, test fails with:
```
Test failed: memory leak detected
```

---

## File Organization

### Final Directory Structure

```
src/
├── infra.zig               # Unified API (Phase 5)
├── string.zig              # String operations (Phase 1)
├── code_point.zig          # Code point predicates (Phase 1)
├── bytes.zig               # Byte sequence operations (Phase 1)
├── list.zig                # List operations (Phase 2)
├── map.zig                 # Ordered map operations (Phase 2)
├── set.zig                 # Ordered set operations (Phase 2)
├── stack.zig               # Stack operations (Phase 2)
├── queue.zig               # Queue operations (Phase 2)
├── struct.zig              # Struct operations (Phase 3)
├── tuple.zig               # Tuple operations (Phase 3)
├── json.zig                # JSON operations (Phase 4)
├── base64.zig              # Base64 operations (Phase 4)
└── namespaces.zig          # Namespace constants (Phase 4)

tests/
├── unit/                   # Unit tests (Phases 1-4)
│   ├── string_*.zig
│   ├── code_point_test.zig
│   ├── bytes_test.zig
│   ├── list_test.zig
│   ├── map_test.zig
│   ├── set_test.zig
│   ├── stack_test.zig
│   ├── queue_test.zig
│   ├── struct_test.zig
│   ├── tuple_test.zig
│   ├── json_*.zig
│   ├── base64_test.zig
│   └── namespaces_test.zig
└── integration/            # Integration tests (Phase 5)
    └── infra_integration_test.zig

examples/                   # Usage examples (Phase 5)
├── string_processing.zig
├── json_parsing.zig
├── collections.zig
└── base64_encoding.zig

analysis/                   # Design documents (complete)
├── COMPLETE_INFRA_CATALOG.md
├── BROWSER_IMPLEMENTATION_RESEARCH.md
├── COMPARISON_MATRICES.md
├── DESIGN_DECISIONS.md
└── IMPLEMENTATION_PLAN.md (this file)

skills/                     # Agent skills (for future work)
docs/                       # Generated API docs (Phase 5)

Root:
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── AGENTS.md
├── build.zig
└── build.zig.zon
```

---

## CHANGELOG Updates

Each phase adds entries to `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-XX-XX

### Added

#### Phase 1: Foundation - Strings & Primitives
- String type (`[]const u16`) - WHATWG Infra UTF-16 representation
- UTF-8 ↔ UTF-16 conversion (`utf8ToUtf16`, `utf16ToUtf8`)
- ASCII string operations (30+): lowercase, uppercase, whitespace, parsing
- Code point operations (19 predicates, surrogate pair encoding/decoding)
- Byte sequence operations (7 operations)

#### Phase 2: Collections
- List with 4-element inline storage
- OrderedMap (list-backed, preserves insertion order)
- OrderedSet (preserves insertion order)
- Stack (LIFO)
- Queue (FIFO)

#### Phase 3: Advanced Primitives
- Struct operations
- Tuple operations

#### Phase 4: Serialization & Encoding
- InfraValue union type (JSON representation)
- JSON parsing (`parseJsonString`, `parseJsonBytes`)
- JSON serialization (`serializeInfraValue`)
- Base64 encoding/decoding (forgiving)
- Namespace constants (HTML, MathML, SVG, etc.)

#### Phase 5: Integration & Polish
- Unified API (`src/infra.zig`)
- Integration tests
- Usage examples
- Complete documentation

### Technical Details
- Zero dependencies (Zig stdlib only)
- Memory safe (zero leaks, verified with `std.testing.allocator`)
- 200+ unit tests, 100% coverage
- Full inline documentation with WHATWG Infra spec references

[0.1.0]: https://github.com/zig-js/whatwg-infra/releases/tag/v0.1.0
```

---

## Next Steps

### Immediate Actions (Start Phase 1)

1. **Create build files** (`build.zig`, `build.zig.zon`)
2. **Start Phase 1.1**: String type and conversion
   - Create `src/string.zig`
   - Create `tests/unit/string_conversion_test.zig`
   - Write tests first
   - Implement `utf8ToUtf16()` and `utf16ToUtf8()`
   - Verify zero leaks
3. **Document progress** in CHANGELOG.md

### Weekly Milestones

- **Week 1**: Phase 1.1-1.3 complete (strings, ASCII, whitespace)
- **Week 2**: Phase 1.4-1.6 complete (parsing, code points, bytes)
- **Week 3**: Phase 2 complete (all collections)
- **Week 4**: Phase 3-4 complete (structs, tuples, JSON, Base64)
- **Week 5**: Phase 5 complete (integration, examples, docs)

### Success Metrics

- ✅ All ~120 operations from Infra spec implemented
- ✅ 200+ tests passing
- ✅ Zero memory leaks
- ✅ Complete documentation
- ✅ v0.1.0 release ready

---

**Ready to start Phase 1.1: String Type & Conversion**

Let's begin with:
1. Create `build.zig` and `build.zig.zon`
2. Create `src/string.zig` (basic structure)
3. Create `tests/unit/string_conversion_test.zig` (TDD: tests first)
4. Implement UTF-8 ↔ UTF-16 conversion

**Estimated time for Phase 1.1**: 2-3 days
