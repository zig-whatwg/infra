# Complete WHATWG Infra Standard Catalog

**Source**: https://infra.spec.whatwg.org/
**Date Cataloged**: 2025-01-27
**Purpose**: Comprehensive inventory of all Infra types, data structures, algorithms, and operations for Zig implementation planning

---

## Table of Contents

1. [Algorithms (§3)](#algorithms-3)
2. [Primitive Data Types (§4)](#primitive-data-types-4)
3. [Data Structures (§5)](#data-structures-5)
4. [JSON Operations (§6)](#json-operations-6)
5. [Forgiving Base64 (§7)](#forgiving-base64-7)
6. [Namespaces (§8)](#namespaces-8)
7. [Implementation Complexity Assessment](#implementation-complexity-assessment)

---

## Algorithms (§3)

### §3.3 Declaration
- Algorithm naming conventions
- Parameter declaration patterns
- Return type specification

### §3.4 Parameters
- Optional parameters (positional and named)
- Default values
- Parameter ordering rules

### §3.5 Variables
- `let` declaration
- `set` assignment
- Multiple assignment from tuples
- Block scoping rules
- No re-declaration

### §3.6 Control Flow
- `return` (terminates algorithm, returns value)
- `throw` (terminates algorithm, propagates error)
- Automatic rethrowing in callers

### §3.7 Conditional Abort
- `abort when` pattern
- `if aborted` cleanup
- Lazy condition evaluation

### §3.8 Conditional Statements
- `if`, `then`, `otherwise` keywords
- Multiple branches

### §3.9 Iteration
- `for each` (lists and maps)
- `while` loops
- `continue` (skip to next iteration)
- `break` (exit iteration)

### §3.10 Assertions
- `Assert:` statements
- Invariant checking
- No implementation impact (documentation only)

**Implementation Implications**:
- These are **specification writing conventions**, not runtime features
- Zig implementations should follow these patterns in documentation
- Use numbered comments matching spec steps

---

## Primitive Data Types (§4)

### §4.1 Nulls

**Spec Definition**:
- `null` value indicates lack of value
- Interchangeable with JavaScript `null`

**Zig Mapping**: `null` (built-in)

---

### §4.2 Booleans

**Spec Definition**:
- `true` or `false`

**Zig Mapping**: `bool` (built-in)

---

### §4.3 Numbers

**Spec Definition** (INCOMPLETE IN SPEC):
- 8-bit unsigned integer: 0 to 255
- 16-bit unsigned integer: 0 to 65535
- 32-bit unsigned integer: 0 to 4294967295
- 64-bit unsigned integer: 0 to 18446744073709551615
- 128-bit unsigned integer: 0 to 2^128-1
- 8-bit signed integer: -128 to 127
- 16-bit signed integer: -32768 to 32767
- 32-bit signed integer: -2^31 to 2^31-1
- 64-bit signed integer: -2^63 to 2^63-1
- Floating point (IEEE 754) - not fully specified
- Mathematical operations - **not specified** (see issue #87)

**Zig Mapping**:
- `u8`, `u16`, `u32`, `u64`, `u128`
- `i8`, `i16`, `i32`, `i64`
- `f32`, `f64` (for floating point)

**Note**: Spec admits numbers are "complicated" and guidance incomplete. Math operations undefined.

---

### §4.4 Bytes

**Spec Definition**:
- A byte is 8 bits
- Represented as "0x" + two hex digits (0x00 to 0xFF)
- Has a "value" (underlying number 0-255)
- **ASCII byte**: 0x00 (NUL) to 0x7F (DEL)

**Zig Mapping**: `u8`

**Operations**:
- UTF-8 decode (single byte → code point if ASCII)

---

### §4.5 Byte Sequences

**Spec Definition**:
- Sequence of bytes
- Space-separated notation OR backtick strings for ASCII range
- Example: `0x48 0x49` OR `` `HI` ``

**Zig Mapping**: `[]const u8` (raw bytes, no UTF-8 assumption)

**Operations**:

1. **length** - Number of bytes
2. **byte-lowercase** - Increase 0x41-0x5A by 0x20
3. **byte-uppercase** - Subtract 0x61-0x7A by 0x20
4. **byte-case-insensitive match** - Compare lowercased
5. **prefix check** - Algorithm provided (step-by-step)
6. **byte less than** - Lexicographic comparison algorithm
7. **isomorphic decode** - byte sequence → string (code points = byte values)

**Critical**: Byte sequences are **not strings**. No UTF-8 encoding assumed.

---

### §4.6 Code Points

**Spec Definition**:
- Unicode code point: U+0000 to U+10FFFF
- Represented as "U+" + 4-6 hex digits
- Has a "value" (underlying number)
- Has a "name" (from Unicode)

**Zig Mapping**: `u21` (can represent 0 to 0x10FFFF)

**Subcategories**:

1. **Leading surrogate**: U+D800 to U+DBFF
2. **Trailing surrogate**: U+DC00 to U+DFFF
3. **Surrogate**: Leading or trailing
4. **Scalar value**: Code point that is NOT a surrogate
5. **Noncharacter**: Specific ranges (U+FDD0-U+FDEF, U+FFFE, U+FFFF, etc.)
6. **ASCII code point**: U+0000 to U+007F
7. **ASCII tab or newline**: U+0009 TAB, U+000A LF, U+000D CR
8. **ASCII whitespace**: U+0009 TAB, U+000A LF, U+000C FF, U+000D CR, U+0020 SPACE
9. **C0 control**: U+0000 to U+001F
10. **C0 control or space**: C0 control OR U+0020 SPACE
11. **Control**: C0 control OR U+007F to U+009F
12. **ASCII digit**: U+0030 (0) to U+0039 (9)
13. **ASCII upper hex digit**: ASCII digit OR U+0041 (A) to U+0046 (F)
14. **ASCII lower hex digit**: ASCII digit OR U+0061 (a) to U+0066 (f)
15. **ASCII hex digit**: Upper or lower hex digit
16. **ASCII upper alpha**: U+0041 (A) to U+005A (Z)
17. **ASCII lower alpha**: U+0061 (a) to U+007A (z)
18. **ASCII alpha**: Upper or lower alpha
19. **ASCII alphanumeric**: Digit or alpha

**Implementation**: These are **predicates** (functions returning bool).

---

### §4.7 Strings

**CRITICAL SPEC DEFINITION**:
> A string is a sequence of **16-bit unsigned integers**, also known as **code units**. A string is also known as a **JavaScript string**.

**Zig Implications**: 
- **Strings in Infra are UTF-16, not UTF-8!**
- This is different from Zig's natural `[]const u8`
- Must carefully choose representation

**String Properties**:
- **length**: Number of code units (not code points!)
- **code point length**: Number of code points (after surrogate pair conversion)
- Can be "interpreted as containing code points" (surrogate pairs → scalar values)

**String Subcategories**:

1. **ASCII string**: All code points are ASCII (U+0000-U+007F)
2. **Isomorphic string**: All code points U+0000-U+00FF
3. **Scalar value string**: All code points are scalar values (no surrogates)

**Operations** (26 operations total):

1. **convert to scalar value string** - Replace surrogates with U+FFFD (�)
2. **is / identical to** - Same sequence of code units (case-sensitive!)
3. **code unit prefix** - Algorithm provided
4. **starts with** - Synonym for code unit prefix (when context clear)
5. **code unit suffix** - Algorithm provided
6. **ends with** - Synonym for code unit suffix (when context clear)
7. **code unit less than** - Lexicographic comparison
8. **code unit substring from start with length** - Algorithm provided
9. **code unit substring from start to end** - Derived from above
10. **code unit substring from start to end of string** - Derived from above
11. **code point substring from start with length** - Algorithm provided
12. **code point substring from start to end** - Derived from above
13. **code point substring from start to end of string** - Derived from above
14. **isomorphic encode** - isomorphic string → byte sequence (code points → bytes)
15. **ASCII lowercase** - Replace ASCII upper alphas with lower
16. **ASCII uppercase** - Replace ASCII lower alphas with upper
17. **ASCII case-insensitive match** - Compare ASCII lowercased
18. **ASCII encode** - ASCII string → byte sequence (same as isomorphic encode)
19. **ASCII decode** - byte sequence → ASCII string (asserts all bytes ASCII)
20. **strip newlines** - Remove U+000A LF and U+000D CR
21. **normalize newlines** - Replace CR+LF with LF, then all CR with LF
22. **strip leading and trailing ASCII whitespace** - Remove at start/end
23. **strip and collapse ASCII whitespace** - Collapse runs to single space, then strip
24. **collect a sequence of code points** - Given condition and position variable
25. **skip ASCII whitespace** - Collect and discard whitespace, update position
26. **strictly split** - Split on delimiter (exact)
27. **split on ASCII whitespace** - Split and trim whitespace
28. **split on commas** - Split on U+002C, trim whitespace from tokens
29. **concatenate** - Join list of strings with separator
30. **serialize a set** - Concatenate with U+0020 SPACE separator

**Critical Decisions Needed**:
- How to represent UTF-16 strings in Zig?
- Use `[]const u16`? Or convert to/from UTF-8?
- Performance implications?

---

### §4.8 Time

**Spec Definition**:
- Use **moment** (point in time)
- Use **duration** (time span)
- Defer to High Resolution Time specification
- No specific algorithms in Infra

**Zig Mapping**: External (defer to `std.time` + integration with JS runtime)

---

## Data Structures (§5)

### §5.1 Lists

**Spec Definition**:
- Finite ordered sequence of items
- Literal syntax: `« item1, item2, item3 »`
- Indexing: `list[index]` (zero-based, must not be out-of-bounds)
- Multiple assignment: `let « a, b, c » be list` (size must match)

**Zig Mapping**: `std.ArrayList(T)` (with optional inline storage optimization)

**Operations** (19 operations):

1. **append** - Add to end (if not ordered set)
2. **extend** - Append each item from another list
3. **prepend** - Add to beginning
4. **replace** - Replace all matching items with replacement
5. **insert** - Add item at index
6. **remove** - Remove all items matching condition
7. **empty** - Remove all items
8. **contains** - Check if item exists
9. **size** - Number of items
10. **is empty** - Size is zero
11. **get indices** - Range from 0 to size (exclusive)
12. **iterate** - For each item
13. **clone** - Shallow copy (items not cloned)
14. **sort in ascending order** - With less-than algorithm (stable sort)
15. **sort in descending order** - With less-than algorithm (stable sort)
16. **`list[index]` exists** - Index within bounds

**Note**: JavaScript `List` type is compatible with Infra `list`

---

### §5.1.1 Stacks

**Spec Definition**:
- List with restricted operations
- LIFO (Last In, First Out)

**Zig Mapping**: `std.ArrayList(T)` with stack wrapper

**Operations**:

1. **push** - Append to end
2. **pop** - Remove and return last item (or nothing if empty)
3. **peek** - Return last item without removing (or nothing if empty)

**Note**: `for each` must NOT be used with stacks. Use `while` + `pop`.

---

### §5.1.2 Queues

**Spec Definition**:
- List with restricted operations
- FIFO (First In, First Out)

**Zig Mapping**: `std.ArrayList(T)` with queue wrapper (or ring buffer for efficiency)

**Operations**:

1. **enqueue** - Append to end
2. **dequeue** - Remove and return first item (or nothing if empty)

**Note**: `for each` must NOT be used with queues. Use `while` + `dequeue`.

---

### §5.1.3 Sets (Ordered Sets)

**Spec Definition**:
- List with additional semantic: **no duplicate items**
- Preserves insertion order
- "Almost all cases on the web platform require an ordered set, instead of an unordered one"

**Zig Mapping**: Custom `OrderedSet(T)` backed by `List(T)` with deduplication

**Operations** (13 operations):

1. **create** - From list (deduplicate on append)
2. **append** - Only if not already present
3. **extend** - Append each item (deduplicate)
4. **prepend** - Only if not already present
5. **replace** - Replace first instance of item or replacement, remove others
6. **subset** - All items in set A are in set B
7. **superset** - Set A is superset of set B
8. **equal** - A is subset of B AND A is superset of B
9. **intersection** - Items in both A and B
10. **union** - All items from A and B (deduplicated)
11. **difference** - Items in A but not in B
12. **the range n to m, inclusive** - Integers from n to m
13. **the range n to m, exclusive** - Integers from n to m-1

**Note**: Modified operations (append, prepend, replace) enforce no duplicates.

---

### §5.2 Maps (Ordered Maps)

**Spec Definition**:
- Finite ordered sequence of **tuples (key, value)**
- No key appears twice
- Each tuple is an **entry**
- Preserves insertion order
- Literal syntax: `«[ key1 → value1, key2 → value2 ]»`
- Indexing: `map[key]` (must exist unless `with default` used)

**Zig Mapping**: Custom `OrderedMap(K, V)` preserving insertion order

**Operations** (14 operations):

1. **get** - Get value for key (with optional default)
2. **`map[key]`** - Indexing syntax (key must exist)
3. **`map[key] with default defaultValue`** - Get with default
4. **set** - Set value (update existing OR append new entry)
5. **`set map[key] to value`** - Syntax for set operation
6. **remove** - Remove entries matching condition
7. **`remove map[key]`** - Remove entry with key
8. **clear** - Remove all entries
9. **contains** - Check if key exists
10. **`map[key] exists`** - Syntax for contains
11. **get keys** - Ordered set of keys
12. **get values** - List of values
13. **size** - Number of entries
14. **is empty** - Size is zero
15. **iterate** - `for each key → value of map`
16. **clone** - Shallow copy (keys/values not cloned)
17. **sort in ascending order** - With less-than algorithm (stable)
18. **sort in descending order** - With less-than algorithm (stable)

**Critical**: Must preserve insertion order (no HashMap!)

---

### §5.3 Structs

**Spec Definition**:
- Finite set of **items**
- Each item has unique, immutable **name**
- Each item has a defined **type**
- Each item holds a **value**

**Zig Mapping**: `struct { ... }` with named fields

**Example**:
```
An email is a struct consisting of:
- local part (string)
- host (host)
```

**Usage**:
```
Let email be an email whose local part is "hostmaster" and host is infra.example.
```

**Note**: General struct definition, no specific operations defined.

---

### §5.3.1 Tuples

**Spec Definition**:
- Struct whose items are **ordered**
- Literal syntax: `(item1, item2, item3)`
- Indexing: `tuple[index]` (zero-based)
- Name access: `tuple's name`

**Zig Mapping**: `struct { ... }` with ordered fields

**Example**:
```
A status is a tuple consisting of:
- code (number)
- text (byte sequence)

Let statusInstance be the status (200, `OK`).
If statusInstance's code is 404, then ...
If statusInstance[0] is 404, then ...
```

**Note**: Not all structs are tuples. Use tuple when order matters and you want flexibility to add new fields later.

---

## JSON Operations (§6)

**Spec Context**: Conversion between JSON and JavaScript/Infra values

### JavaScript Value Operations

1. **parse a JSON string to a JavaScript value** - Call `%JSON.parse%`
2. **parse JSON bytes to a JavaScript value** - UTF-8 decode, then parse
3. **serialize a JavaScript value to a JSON string** - Call `%JSON.stringify%` (no whitespace)
4. **serialize a JavaScript value to JSON bytes** - Serialize, then UTF-8 encode

### Infra Value Operations

5. **parse a JSON string to an Infra value** - Parse to JS, then convert
6. **parse JSON bytes to an Infra value** - UTF-8 decode, parse to Infra
7. **convert JSON-derived JavaScript value to Infra value** - Recursive conversion:
   - null → null
   - Boolean → boolean
   - Number → number (f64)
   - String → string
   - Array → list (recursive)
   - Object → ordered map (recursive, **preserves property order!**)
8. **serialize an Infra value to a JSON string** - Convert to JS, then stringify
9. **serialize an Infra value to JSON bytes** - Serialize to string, then UTF-8 encode
10. **convert Infra value to JSON-compatible JavaScript value** - Recursive conversion

**Infra Value Type**:
```
union {
  null_value,
  boolean,
  number (f64),
  string,
  list (of Infra values),
  map (string keys → Infra values)
}
```

**Zig Mapping**: Tagged union `InfraValue`

**Critical**: JSON objects become **ordered maps** (insertion order preserved!)

---

## Forgiving Base64 (§7)

### §7.1 Forgiving-base64 Encode

**Spec Definition**:
- Apply RFC 4648 section 4 base64 algorithm
- Standard base64 encoding

**Zig Mapping**: Wrapper around `std.base64.standard.Encoder`

### §7.2 Forgiving-base64 Decode

**Spec Definition** (complex algorithm):

1. Remove all ASCII whitespace from data
2. If length divides by 4 with no remainder:
   - Remove trailing one or two `=` characters
3. If length divides by 4 leaving remainder of 1: **return failure**
4. If data contains non-base64 characters: **return failure**
   - Valid: `+`, `/`, ASCII alphanumeric
5. Decode using base64 alphabet (RFC 4648 Table 1)
6. Handle partial bytes at end (discard extra bits)

**Zig Mapping**: Custom wrapper around `std.base64.standard.Decoder` with forgiving error handling

**"Forgiving" means**:
- Strips ASCII whitespace before decoding
- Allows missing padding (`=`)
- Returns failure on invalid input (doesn't throw)

---

## Namespaces (§8)

**Spec Definition**: Constant namespace URIs

1. **HTML namespace**: `"http://www.w3.org/1999/xhtml"`
2. **MathML namespace**: `"http://www.w3.org/1998/Math/MathML"`
3. **SVG namespace**: `"http://www.w3.org/2000/svg"`
4. **XLink namespace**: `"http://www.w3.org/1999/xlink"`
5. **XML namespace**: `"http://www.w3.org/XML/1998/namespace"`
6. **XMLNS namespace**: `"http://www.w3.org/2000/xmlns/"`

**Zig Mapping**: Public constants (string literals)

---

## Implementation Complexity Assessment

### Low Complexity (Straightforward)

1. **Nulls** - Built-in
2. **Booleans** - Built-in
3. **Numbers** - Built-in types (incomplete spec, but types exist)
4. **Bytes** - `u8` alias
5. **Namespaces** - String constants

### Medium Complexity (Standard Library + Wrapper)

1. **Lists** - `ArrayList(T)` + spec-compliant operations
2. **Stacks** - Wrapper around `ArrayList(T)`
3. **Queues** - Wrapper around `ArrayList(T)` or ring buffer
4. **Structs** - Zig `struct`
5. **Tuples** - Zig `struct` with ordered fields
6. **JSON (JavaScript values)** - Wrapper around `std.json`
7. **Base64 encode** - Wrapper around `std.base64`

### High Complexity (Custom Implementation Required)

1. **Strings** - **UTF-16 representation** (not UTF-8!)
   - 30+ operations
   - Code unit vs code point operations
   - Surrogate handling
   - ASCII fast paths
2. **Byte Sequences** - Distinct from strings
   - 7 operations
   - Isomorphic decode
3. **Code Points** - Predicates + conversions
   - 19 predicates
   - Surrogate detection
4. **Ordered Sets** - Custom deduplication logic
   - 13 operations
   - Backed by List
5. **Ordered Maps** - Custom insertion-order preservation
   - 18 operations
   - **Cannot use std.HashMap** (doesn't preserve order)
6. **JSON (Infra values)** - Recursive conversion
   - InfraValue union type
   - Deep cloning/cleanup
7. **Forgiving Base64 decode** - Custom error handling
   - Whitespace stripping
   - Padding tolerance

### Critical Decision Points

1. **String Representation**:
   - Spec says UTF-16 (16-bit code units)
   - Zig naturally uses UTF-8 (`[]const u8`)
   - **Decision needed**: Store UTF-16? Convert on-the-fly? Trade-offs?

2. **Ordered Map Implementation**:
   - Must preserve insertion order
   - Linear search vs hash table trade-offs
   - Inline storage optimization?

3. **Memory Management**:
   - Allocator threading (all operations take allocator?)
   - Arena patterns for intermediate values?
   - Reference counting for InfraValue?

4. **Performance Optimizations**:
   - Inline storage (browser research: 4 elements)
   - ASCII fast paths
   - Small-n linear search vs hash table

---

## Summary Statistics

- **Primitive Types**: 6 categories (nulls, booleans, numbers, bytes, byte sequences, code points, strings, time)
- **Data Structures**: 7 types (list, stack, queue, ordered set, ordered map, struct, tuple)
- **String Operations**: 30+ algorithms
- **Code Point Predicates**: 19 predicates
- **Byte Sequence Operations**: 7 algorithms
- **List Operations**: 19 operations
- **Ordered Set Operations**: 13 operations
- **Ordered Map Operations**: 18 operations
- **JSON Operations**: 10 algorithms
- **Base64 Operations**: 2 algorithms (encode/decode)
- **Namespaces**: 6 constants

**Total Implementation Surface**: ~120+ distinct operations/algorithms

---

## Next Steps

1. **Research browser implementations** for strings (UTF-16 vs UTF-8)
2. **Research browser implementations** for ordered maps (preservation strategy)
3. **Analyze UTF-16 vs UTF-8 trade-offs** for Zig context
4. **Create comparison matrices** (browser approach vs Zig optimal approach)
5. **Document design decisions** with rationale
6. **Create phased implementation plan** based on dependencies

---

**Status**: Catalog complete. Ready for browser implementation research phase.
