# WHATWG Infra for Zig

Complete implementation of the [WHATWG Infra Standard](https://infra.spec.whatwg.org/) in Zig.

## Quick Start

```zig
const std = @import("std");
const infra = @import("infra");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Work with strings (UTF-16)
    const str = try infra.string.utf8ToUtf16(allocator, "Hello, 世界!");
    defer allocator.free(str);
    
    // Use collections (4-element inline storage)
    var list = infra.List(u32).init(allocator);
    defer list.deinit();
    try list.append(1);
    try list.append(2);
    
    // Parse JSON
    var json = try infra.json.parseJsonString(allocator, "{\"key\":\"value\"}");
    defer json.deinit(allocator);
    
    // Encode Base64
    const encoded = try infra.base64.forgivingBase64Encode(allocator, "data");
    defer allocator.free(encoded);
}
```

## API Reference

### Strings

Infra strings use **UTF-16 encoding** (`[]const u16`), matching the WHATWG specification and JavaScript's internal representation.

```zig
const std = @import("std");
const infra = @import("infra");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Convert UTF-8 (Zig) to UTF-16 (Infra)
    const utf8_str = "hello world 🌍";
    const infra_str = try infra.string.utf8ToUtf16(allocator, utf8_str);
    defer allocator.free(infra_str);
    
    // Convert UTF-16 (Infra) back to UTF-8 (Zig)
    const result = try infra.string.utf16ToUtf8(allocator, infra_str);
    defer allocator.free(result);
    
    std.debug.print("{s}\n", .{result});
}
```

**Conversion:**
- ✅ UTF-8 → UTF-16 conversion (`utf8ToUtf16`)
- ✅ UTF-16 → UTF-8 conversion (`utf16ToUtf8`)
- ✅ Surrogate pair encoding for code points U+10000..U+10FFFF
- ✅ Error handling for invalid UTF-8 and unpaired surrogates

**ASCII Operations:**
- ✅ Case conversion (`asciiLowercase`, `asciiUppercase`)
- ✅ ASCII checking (`isAsciiString`, `isAsciiCaseInsensitiveMatch`)
- ✅ Byte length (`asciiByteLength`)

**Whitespace:**
- ✅ Whitespace detection (`isAsciiWhitespace`)
- ✅ Stripping (`stripLeadingAndTrailingAsciiWhitespace`, `stripNewlines`)
- ✅ Normalization (`normalizeNewlines`)

**Parsing:**
- ✅ Splitting (`splitOnAsciiWhitespace`, `splitOnCommas`)
- ✅ Joining (`concatenate`)

**Code Points:**
- ✅ 19 type predicates (surrogate, ASCII, control, digit, alpha, etc.)
- ✅ Surrogate pair encoding/decoding

**Byte Sequences:**
- ✅ Lexicographic comparison (`byteLessThan`)
- ✅ UTF-8 decode/encode (`decodeAsUtf8`, `utf8Encode`)
- ✅ Isomorphic decode/encode (1:1 byte↔code unit mapping)

### Collections

**List**

```zig
var list = infra.List(u32).init(allocator);
defer list.deinit();

try list.append(42);           // Add to end
try list.prepend(10);          // Add to start
try list.insert(1, 20);        // Insert at index
const item = list.get(0);      // Get item (returns ?T)
_ = try list.remove(1);        // Remove by index
try list.extend(&other_list);  // Append another list
list.sort(lessThan);           // Sort with comparator
```

**OrderedMap**

```zig
var map = infra.OrderedMap([]const u8, u32).init(allocator);
defer map.deinit();

try map.set("key", 100);       // Insert/update
const val = map.get("key");    // Get (returns ?V)
_ = map.remove("key");         // Remove (returns bool)
const exists = map.contains("key");

// Iterate in insertion order
var it = map.iterator();
while (it.next()) |entry| {
    std.debug.print("{s}: {}\n", .{entry.key, entry.value});
}
```

**OrderedSet**

```zig
var set = infra.OrderedSet(u32).init(allocator);
defer set.deinit();

const added = try set.add(42); // Add (returns false if exists)
_ = set.remove(42);            // Remove
const exists = set.contains(42);
```

**Stack & Queue**

```zig
// Stack (LIFO)
var stack = infra.Stack(u32).init(allocator);
defer stack.deinit();
try stack.push(1);
const item = stack.pop(); // Returns ?T

// Queue (FIFO)
var queue = infra.Queue(u32).init(allocator);
defer queue.deinit();
try queue.enqueue(1);
const item2 = queue.dequeue(); // Returns ?T
```

### JSON

```zig
// Parse JSON string
var value = try infra.json.parseJsonString(allocator, 
    "{\"name\":\"Alice\",\"age\":30}");
defer value.deinit(allocator);

// Access values
switch (value) {
    .null_value => {},
    .boolean => |b| {},
    .number => |n| {},
    .string => |s| {},
    .list => |l| {},
    .map => |m| {
        // OrderedMap preserves insertion order
        var it = m.iterator();
        while (it.next()) |entry| {
            // entry.key: String (UTF-16)
            // entry.value: *InfraValue
        }
    },
}

// Serialize back to JSON
const json_string = try infra.json.serializeInfraValue(allocator, value);
defer allocator.free(json_string);
```

### Base64

```zig
// Encode
const encoded = try infra.base64.forgivingBase64Encode(allocator, data);
defer allocator.free(encoded);

// Decode (forgiving - strips whitespace)
const decoded = try infra.base64.forgivingBase64Decode(allocator, 
    "aGVs bG8="); // Whitespace is stripped
defer allocator.free(decoded);
```

### Namespaces

```zig
const html_ns = infra.namespaces.HTML_NAMESPACE;
const svg_ns = infra.namespaces.SVG_NAMESPACE;
const mathml_ns = infra.namespaces.MATHML_NAMESPACE;
```



## Installation

### Using Zig Package Manager

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .infra = .{
        .url = "https://github.com/zig-js/whatwg-infra/archive/<commit>.tar.gz",
        .hash = "<hash>",
    },
},
```

Then in your `build.zig`:

```zig
const infra = b.dependency("infra", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("infra", infra.module("infra"));
```

### From Source

```bash
git clone https://github.com/zig-js/whatwg-infra
cd whatwg-infra
zig build test
```

## Requirements

- Zig 0.15.1 or later

## Design Principles

1. **Spec Compliance First**: Implements WHATWG Infra exactly as specified
2. **Memory Safety**: Zero leaks, verified with `std.testing.allocator`
3. **V8 Interop**: UTF-16 strings enable zero-copy JavaScript interop
4. **Zig Idioms**: Explicit allocators, clear error handling
5. **Production Ready**: Full test coverage, comprehensive documentation

## Why UTF-16?

The WHATWG Infra specification defines strings as **sequences of 16-bit code units** (UTF-16). This choice:

- ✅ Matches the specification exactly
- ✅ Enables zero-copy interop with V8/JavaScript
- ✅ Simplifies implementation (single representation)
- ✅ Direct compatibility with DOM, Fetch, URL specs

See [DESIGN_DECISIONS.md](./analysis/DESIGN_DECISIONS.md) for detailed rationale.

## Performance

Run benchmarks: `zig build bench`

See [PERFORMANCE.md](./PERFORMANCE.md) for detailed performance characteristics.

## Testing

```bash
# Run all tests
zig build test

# Run tests with summary
zig build test --summary all
```

## Documentation

- [Implementation Plan](./analysis/IMPLEMENTATION_PLAN.md) - Detailed 5-phase roadmap
- [Design Decisions](./analysis/DESIGN_DECISIONS.md) - Architecture and trade-offs
- [Browser Research](./analysis/BROWSER_IMPLEMENTATION_RESEARCH.md) - Chromium/Firefox patterns
- [Complete Spec Catalog](./analysis/COMPLETE_INFRA_CATALOG.md) - All ~120 operations

## Contributing

See [AGENTS.md](./AGENTS.md) for development guidelines and agent instructions.

## License

MIT License - see [LICENSE](./LICENSE) file for details.

## Acknowledgments

- [WHATWG Infra Standard](https://infra.spec.whatwg.org/)
- Chromium Blink (WTF::String, WTF::Vector)
- Firefox Gecko (mozilla::Vector, nsAString)
