# WHATWG Infra Benchmarks

Performance benchmarks for WHATWG Infra primitive operations.

## Running Benchmarks

Build and run all benchmarks:

```bash
zig build bench
```

Run individual benchmark suites:

```bash
# List operations
zig build bench-list

# OrderedMap operations
zig build bench-map

# String operations
zig build bench-string

# JSON operations
zig build bench-json

# Base64 operations
zig build bench-base64

# Memory leak detection (2+ minute runtime)
zig build bench-memory-leak
```

## Benchmark Suites

### List (`list_bench.zig`)

Tests List operations with inline storage (4 elements) and heap allocation:

- **append (inline storage)** - 3 items on stack
- **append (heap storage)** - 10 items with heap allocation
- **prepend** - Insert at beginning
- **insert** - Insert at middle position
- **remove** - Remove from middle
- **get** - Index access
- **contains** - Linear search
- **clone** - Deep copy with 10 items
- **sort** - Sort 5 items

**Key Metrics**: Inline storage should be significantly faster than heap for ≤4 items.

### OrderedMap (`map_bench.zig`)

Tests OrderedMap operations (preserves insertion order):

- **set (small)** - 3 entries
- **set (large)** - 20 entries
- **get** - Key lookup in 10-entry map
- **contains** - Key existence check
- **remove** - Remove entry
- **iteration** - Iterate all entries in insertion order
- **clone** - Deep copy 10 entries
- **string keys** - Operations with string keys

**Key Metrics**: Linear search O(n) should be faster than HashMap for n < 12 due to cache locality.

### String (`string_bench.zig`)

Tests UTF-8↔UTF-16 conversion and string operations:

- **utf8ToUtf16 (ASCII)** - Pure ASCII conversion
- **utf8ToUtf16 (Unicode)** - Unicode with surrogate pairs
- **utf16ToUtf8 (ASCII)** - ASCII back to UTF-8
- **utf16ToUtf8 (Unicode)** - Unicode with surrogate pairs
- **asciiLowercase** - Convert to lowercase
- **asciiUppercase** - Convert to uppercase
- **isAsciiCaseInsensitiveMatch** - Case-insensitive comparison
- **stripWhitespace** - Remove leading/trailing whitespace
- **stripNewlines** - Remove CR/LF
- **normalizeNewlines** - Normalize CRLF → LF
- **splitOnWhitespace** - Split by whitespace
- **splitOnCommas** - Split by commas
- **concatenate** - Join strings

**Key Metrics**: ASCII operations should be faster than Unicode operations.

### JSON (`json_bench.zig`)

Tests JSON parsing and serialization:

**Parsing:**
- **parse null** - Null value
- **parse boolean** - Boolean value
- **parse number** - Number value
- **parse string** - String value
- **parse array (small)** - 3 items
- **parse array (large)** - 20 items
- **parse object (small)** - 2 keys
- **parse object (large)** - Nested object with arrays

**Serialization:**
- **serialize null** - Null value
- **serialize boolean** - Boolean value
- **serialize number** - Number value
- **serialize string** - String value

**Key Metrics**: Parsing is typically slower than serialization. Large structures should show linear scaling.

### Base64 (`base64_bench.zig`)

Tests forgiving Base64 encoding/decoding (strips ASCII whitespace):

**Encoding:**
- **encode (small)** - 5 bytes
- **encode (medium)** - 32 bytes
- **encode (large)** - 256 bytes

**Decoding:**
- **decode (small)** - 5 bytes
- **decode (medium)** - 32 bytes
- **decode (large)** - 256 bytes
- **decode (with whitespace)** - Forgiving decode strips whitespace

**Roundtrip:**
- **roundtrip (small)** - Encode + decode 5 bytes
- **roundtrip (large)** - Encode + decode 256 bytes

**Key Metrics**: Encoding and decoding should scale linearly. Forgiving decode should handle whitespace with minimal overhead.

### Memory Leak Detection (`memory_leak_bench.zig`)

Tests long-term memory stability by running intensive workloads for 2+ minutes:

**Phases:**
1. **Warmup (5 seconds)** - Stabilize memory allocator state
2. **Intensive Workload (120 seconds)** - Continuous create/destroy cycles
3. **Cleanup Wait (5 seconds)** - Allow memory to return to baseline

**Workloads (each iteration):**
- **List operations** - 100 appends, removes, prepends, clone, sort
- **OrderedMap operations** - 50 sets, 25 removes, clone with string keys
- **OrderedSet operations** - 100 appends, 50 removes, clone
- **Stack operations** - 100 pushes, 100 pops
- **Queue operations** - 100 enqueues, 100 dequeues
- **String operations** - UTF-8↔UTF-16 conversion, case transforms, splitting
- **JSON operations** - Parse/serialize complex nested structures
- **Base64 operations** - Encode/decode with forgiving whitespace handling

**Success Criteria:**
- ✅ **Pass**: Final memory ≤ baseline + 1% (within allocator variance)
- ⚠️ **Warning**: Final memory > baseline + 1% but < 5% (possible slow leak)
- ❌ **Fail**: Final memory > baseline + 5% (likely memory leak)

**Metrics Reported:**
- Total iterations completed
- Iterations per second
- Memory usage every 10 seconds during workload
- Baseline, peak, and final memory comparison
- Memory leak detection (GPA deinit check)

**Key Metrics**: Memory should return to baseline (±1%) after intensive workload, indicating proper cleanup with `defer` patterns.

## Interpreting Results

Benchmarks report:
- **Total time (ms)** - Time to complete all iterations
- **Per-operation time (ns/op)** - Average time per operation

### Expected Performance Characteristics

1. **Inline Storage** - List/Map operations with ≤4 items should avoid heap allocations (70-80% hit rate in practice)
2. **Cache Locality** - OrderedMap linear search faster than HashMap for small n due to cache efficiency
3. **ASCII Fast Path** - ASCII string operations significantly faster than Unicode operations
4. **Linear Scaling** - Large structures (arrays, objects, byte sequences) should scale linearly with size

## Build Configuration

Benchmarks are built with:
- **Target**: Native
- **Optimization**: ReleaseFast
- **Allocator**: GeneralPurposeAllocator (production-like)

For maximum performance, use ReleaseFast mode (default in benchmark builds).

## Baseline Comparisons

To establish baseline performance:

```bash
# Run benchmarks and save results
zig build bench > baseline.txt

# Make changes, then compare
zig build bench > new.txt
diff baseline.txt new.txt
```

## Notes

- Benchmarks use realistic data sizes based on browser research (see `skills/browser_benchmarking/`)
- Iterations are tuned for ~1-10 seconds runtime per benchmark
- Memory allocations are measured via GeneralPurposeAllocator (no leaks)
- All benchmarks verify correctness (defer cleanup, proper error handling)
