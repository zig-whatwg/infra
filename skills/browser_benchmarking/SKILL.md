# Browser Benchmarking Skill

## Purpose

This skill provides guidance on how to benchmark the WHATWG URL implementation against browser engines, identify optimization opportunities, and measure URL parsing performance.

---

## Why Benchmark Against Browsers?

**URL parsing must match browser behavior** - both functionally AND performantly.

### Key Reasons

1. **Compatibility Verification**
   - Ensure parsing matches Chrome, Firefox, Safari
   - Validate edge case handling
   - Confirm serialization output

2. **Performance Targets**
   - Set realistic performance goals based on browser implementations
   - Identify optimization opportunities
   - Avoid premature optimization (measure first!)

3. **Regression Detection**
   - Catch performance regressions early
   - Track improvements over time
   - Validate optimization effectiveness

---

## URL Parsing Performance Characteristics

### What to Measure

| Operation | Why Measure | Browser Typical Performance |
|-----------|-------------|----------------------------|
| **URL parsing** | Core hot path | 1-5 μs for simple URLs |
| **Host parsing** | Complex (IPv4, IPv6, domain) | 0.5-2 μs |
| **Percent encoding** | Frequent operation | 0.1-0.5 μs per component |
| **URL serialization** | Converting URL back to string | 0.5-1 μs |
| **Relative URL resolution** | Parsing with base URL | 2-10 μs |
| **Setter operations** | `url.hostname = "..."` | 1-3 μs |

### Browser URL Parser Implementations

**Chromium (Blink)**:
- Location: `third_party/blink/renderer/platform/url/kurl.cc`
- Fast path for ASCII-only URLs
- Optimized percent encoding lookup tables
- Inline storage for URL components

**Firefox (Gecko)**:
- Location: `netwerk/base/nsStandardURL.cpp`
- Lazy component parsing (parse-on-demand)
- Cached parsing results
- Minimal allocations for common URLs

**WebKit**:
- Location: `Source/WTF/wtf/URL.cpp`
- Similar patterns to Chromium
- Fast paths for special schemes (http, https)

---

## Benchmarking Strategy

### 1. Microbenchmarks (Single Operation)

**Purpose**: Measure individual URL operations in isolation

**Example**:
```zig
test "benchmark - parse simple HTTP URL" {
    const allocator = std.testing.allocator;
    const url_string = "https://example.com/path?query=value#fragment";
    
    var timer = try std.time.Timer.start();
    const iterations = 100_000;
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const url = try URL.parse(allocator, url_string);
        defer url.deinit();
    }
    
    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    
    std.debug.print("URL.parse(): {} ns/op\n", .{ns_per_op});
    
    // Target: < 5000 ns (5 μs) per parse for simple URLs
    try std.testing.expect(ns_per_op < 5000);
}
```

### 2. Macro benchmarks (Real-World Scenarios)

**Purpose**: Measure realistic URL workloads

**Examples**:
- Parse 1000 URLs from a real dataset (e.g., Alexa Top 1000)
- Measure end-to-end URL resolution with base URLs
- Test URL setter operations in sequence

### 3. Comparison Benchmarks (Against Browsers)

**Purpose**: Compare Zig performance to browser implementations

**Approach**:
```javascript
// JavaScript (run in browser)
console.time("parse-100k-urls");
for (let i = 0; i < 100000; i++) {
    new URL("https://example.com/path?query=value#fragment");
}
console.timeEnd("parse-100k-urls");
```

Then compare against Zig implementation.

---

## URL-Specific Optimization Opportunities

### 1. Percent Encoding Lookup Tables

**Pattern**: Use lookup tables instead of range checks

**Browser implementation** (Chromium):
```cpp
// Character class lookup table (256 entries)
static const char kCharClassTable[256] = {
    // 0x00-0x1F: control characters
    kNonASCII, kNonASCII, ...
    // 0x20: space
    kQueryCharacter,
    // ...
};
```

**Zig implementation**:
```zig
/// Lookup table for percent encoding rules
/// true = needs encoding, false = allowed unencoded
const percent_encode_table = blk: {
    var table: [256]bool = [_]bool{true} ** 256;
    
    // ASCII alphanumeric: always allowed
    for ('A'..'Z' + 1) |c| table[c] = false;
    for ('a'..'z' + 1) |c| table[c] = false;
    for ('0'..'9' + 1) |c| table[c] = false;
    
    // Special characters (scheme-specific)
    table['-'] = false;
    table['_'] = false;
    table['.'] = false;
    table['~'] = false;
    
    break :blk table;
};

pub inline fn needsPercentEncoding(byte: u8, set: PercentEncodeSet) bool {
    return percent_encode_table[byte] or isInEncodeSet(byte, set);
}
```

**Benchmark**:
```zig
test "benchmark - percent encoding" {
    const input = "hello world! 100% awesome";
    
    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        const encoded = try percentEncode(allocator, input, .path);
        defer allocator.free(encoded);
    }
    const elapsed = timer.read();
    std.debug.print("percentEncode: {} ns/op\n", .{elapsed / 100_000});
}
```

### 2. Fast Path for ASCII-Only URLs

**Pattern**: Detect ASCII-only URLs early, skip UTF-8 validation

**Implementation**:
```zig
pub fn parseURL(allocator: Allocator, input: []const u8) !URL {
    // Fast check: is input pure ASCII?
    var is_ascii = true;
    for (input) |byte| {
        if (byte >= 0x80) {
            is_ascii = false;
            break;
        }
    }
    
    if (is_ascii) {
        // Fast path: skip UTF-8 validation, simpler parsing
        return parseASCIIURL(allocator, input);
    } else {
        // Slow path: full UTF-8 handling
        return parseUnicodeURL(allocator, input);
    }
}
```

**Benchmark**:
```zig
test "benchmark - ASCII fast path" {
    const ascii_url = "https://example.com/path";
    const unicode_url = "https://例え.jp/パス";
    
    // ASCII fast path
    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < 100_000) : (i += 1) {
        const url = try URL.parse(allocator, ascii_url);
        defer url.deinit();
    }
    const ascii_time = timer.read();
    
    // Unicode slow path
    timer.reset();
    i = 0;
    while (i < 100_000) : (i += 1) {
        const url = try URL.parse(allocator, unicode_url);
        defer url.deinit();
    }
    const unicode_time = timer.read();
    
    std.debug.print("ASCII: {} ns/op, Unicode: {} ns/op\n", 
        .{ascii_time / 100_000, unicode_time / 100_000});
    
    // ASCII path should be faster
    try std.testing.expect(ascii_time < unicode_time);
}
```

### 3. Host Parsing Cache (IPv4/IPv6 Detection)

**Pattern**: Quick validation before full parsing

**Implementation**:
```zig
pub fn parseHost(input: []const u8) !Host {
    // Quick check: IPv4 pattern (digits and dots only)
    if (looksLikeIPv4(input)) {
        return Host{ .ipv4 = try parseIPv4(input) };
    }
    
    // Quick check: IPv6 pattern (starts with '[')
    if (input.len > 0 and input[0] == '[') {
        return Host{ .ipv6 = try parseIPv6(input) };
    }
    
    // Domain name parsing
    return Host{ .domain = try parseDomain(input) };
}

fn looksLikeIPv4(input: []const u8) bool {
    if (input.len == 0) return false;
    
    // Fast check: only digits and dots
    for (input) |byte| {
        if (byte != '.' and (byte < '0' or byte > '9')) {
            return false;
        }
    }
    return true;
}
```

### 4. URL Serialization with Capacity Hints

**Pattern**: Preallocate buffer based on component sizes

**Implementation**:
```zig
pub fn serialize(self: *const URL, allocator: Allocator) ![]u8 {
    // Calculate minimum size needed
    var capacity: usize = 0;
    capacity += self.scheme.len + 1; // "scheme:"
    if (self.host) |host| {
        capacity += 2; // "//"
        capacity += estimateHostSize(host);
    }
    if (self.port) |_| {
        capacity += 6; // ":12345"
    }
    capacity += self.path.len;
    if (self.query) |q| capacity += 1 + q.len;
    if (self.fragment) |f| capacity += 1 + f.len;
    
    // Preallocate (avoids reallocation)
    var result = try std.ArrayList(u8).initCapacity(allocator, capacity);
    errdefer result.deinit();
    
    // Serialize components
    try result.appendSlice(self.scheme);
    try result.append(':');
    // ... (rest of serialization)
    
    return result.toOwnedSlice();
}
```

### 5. Special Scheme Fast Paths

**Pattern**: Optimize for common schemes (http, https, file)

**Implementation**:
```zig
pub fn parseURL(allocator: Allocator, input: []const u8) !URL {
    // Detect special schemes early
    const scheme = try extractScheme(input);
    
    if (isSpecialScheme(scheme)) {
        // Fast path for http, https, file, ftp, ws, wss
        return parseSpecialURL(allocator, input, scheme);
    } else {
        // Generic URL parsing
        return parseGenericURL(allocator, input, scheme);
    }
}

inline fn isSpecialScheme(scheme: []const u8) bool {
    return std.mem.eql(u8, scheme, "http") or
           std.mem.eql(u8, scheme, "https") or
           std.mem.eql(u8, scheme, "file") or
           std.mem.eql(u8, scheme, "ftp") or
           std.mem.eql(u8, scheme, "ws") or
           std.mem.eql(u8, scheme, "wss");
}
```

---

## Benchmarking Tools

### 1. Zig Built-in Timer

```zig
const std = @import("std");

pub fn benchmark(comptime name: []const u8, iterations: usize, func: anytype) !void {
    var timer = try std.time.Timer.start();
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        func();
    }
    
    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;
    
    std.debug.print("{s}: {} ns/op ({d:.2} μs/op)\n", 
        .{name, ns_per_op, @as(f64, @floatFromInt(ns_per_op)) / 1000.0});
}
```

### 2. Browser DevTools (for comparison)

**Chrome DevTools**:
```javascript
// Microbenchmark
console.time("parse-url");
for (let i = 0; i < 100000; i++) {
    new URL("https://example.com/path?query#fragment");
}
console.timeEnd("parse-url");

// Detailed profiling
performance.mark("start");
for (let i = 0; i < 100000; i++) {
    new URL("https://example.com/path?query#fragment");
}
performance.mark("end");
performance.measure("url-parse", "start", "end");
console.log(performance.getEntriesByName("url-parse"));
```

### 3. Criterion-like Benchmarking

```zig
// Simple benchmark suite
pub const BenchmarkSuite = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) BenchmarkSuite {
        return .{ .allocator = allocator };
    }
    
    pub fn run(self: BenchmarkSuite, comptime name: []const u8, func: anytype) !void {
        const iterations = 100_000;
        var timer = try std.time.Timer.start();
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            try func(self.allocator);
        }
        
        const elapsed = timer.read();
        const ns_per_op = elapsed / iterations;
        
        std.debug.print("{s}: {} ns/op\n", .{name, ns_per_op});
    }
};

// Usage
test "benchmark suite" {
    var suite = BenchmarkSuite.init(std.testing.allocator);
    
    try suite.run("parse-simple-url", parseSimpleURL);
    try suite.run("parse-complex-url", parseComplexURL);
    try suite.run("parse-relative-url", parseRelativeURL);
}
```

---

## Real-World URL Datasets

### Test Against Real URLs

**Alexa Top 1000**:
- Download real-world URLs
- Parse each one
- Measure aggregate performance

**Example dataset**:
```
https://www.google.com
https://www.youtube.com
https://www.facebook.com
https://www.amazon.com
https://www.wikipedia.org
...
```

**Benchmark**:
```zig
test "benchmark - real-world URLs" {
    const urls = @embedFile("../data/alexa-top-1000.txt");
    var lines = std.mem.split(u8, urls, "\n");
    
    var timer = try std.time.Timer.start();
    var count: usize = 0;
    
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        
        const url = try URL.parse(allocator, line);
        defer url.deinit();
        count += 1;
    }
    
    const elapsed = timer.read();
    const ns_per_url = elapsed / count;
    
    std.debug.print("Parsed {} real URLs: {} ns/op\n", .{count, ns_per_url});
}
```

---

## Performance Targets

### Realistic Goals (Based on Browser Performance)

| Operation | Target | Notes |
|-----------|--------|-------|
| **Simple URL parse** | < 5 μs | `https://example.com/path` |
| **Complex URL parse** | < 10 μs | With query, fragment, IPv6 |
| **Host parse (domain)** | < 2 μs | ASCII domain names |
| **Host parse (IPv4)** | < 1 μs | Simple numeric parsing |
| **Host parse (IPv6)** | < 3 μs | Complex parsing |
| **Percent encoding** | < 500 ns | Per component (path, query) |
| **URL serialization** | < 1 μs | Converting back to string |

**Note**: These are approximate targets. Actual browser performance varies by:
- CPU architecture
- Compiler optimizations
- Input characteristics (ASCII vs Unicode, simple vs complex)

---

## Avoiding Premature Optimization

### Optimization Workflow

1. **Implement correctly first**
   - Follow WHATWG URL spec exactly
   - Pass all tests
   - Ensure spec compliance

2. **Measure baseline**
   - Benchmark current implementation
   - Identify hot spots with profiling
   - Set realistic targets

3. **Optimize hot paths**
   - Focus on frequently-called operations
   - Measure before and after
   - Verify correctness still holds

4. **Validate improvements**
   - Re-run full test suite
   - Compare against browsers
   - Check for regressions

### Red Flags (Don't Optimize Yet)

- ❌ No baseline measurements
- ❌ No clear performance problem
- ❌ Tests don't pass
- ❌ Spec compliance uncertain

### Green Lights (OK to Optimize)

- ✅ Tests pass (100% coverage)
- ✅ Spec compliant
- ✅ Baseline measured
- ✅ Clear bottleneck identified

---

## Integration with Other Skills

### With whatwg_spec

- Read `specs/url.md` to understand algorithm complexity
- Identify optimization opportunities in spec algorithms
- Ensure optimizations don't break spec compliance

### With testing_requirements

- Write performance regression tests
- Ensure optimizations pass all functional tests
- Add benchmark tests for critical paths

### With performance_optimization

- Apply general Zig optimization patterns
- Use lookup tables, fast paths, inline functions
- Minimize allocations

---

## Summary

**Key Principles:**

1. **Measure before optimizing** - Get baseline performance
2. **Compare against browsers** - Set realistic targets
3. **Focus on hot paths** - URL parsing, host parsing, percent encoding
4. **Use lookup tables** - Avoid range checks
5. **Fast path for ASCII** - Most URLs are ASCII-only
6. **Preallocate buffers** - Avoid reallocation
7. **Verify correctness** - Never sacrifice spec compliance for speed

**Workflow:**
1. Implement correctly (spec-compliant)
2. Measure baseline
3. Identify bottlenecks
4. Optimize hot paths
5. Verify improvements
6. Compare against browsers

**Remember**: URL parsing must match browser behavior. Performance matters, but correctness comes first.
