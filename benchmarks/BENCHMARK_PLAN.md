# Comprehensive Benchmark Plan for 4-Phase Optimization

This document tracks which operations need benchmarking to establish baselines before implementing the 4-phase optimization plan from `analysis/ZIG_OPTIMIZATION_ANALYSIS.md`.

## Current Benchmark Coverage

### ✅ Existing Benchmarks (56 total)

**List Operations** (10 benchmarks in `list_bench.zig`):
- ✅ append (inline storage, 3 items)
- ✅ append (heap storage, 10 items)
- ✅ prepend
- ✅ insert
- ✅ remove
- ✅ get
- ✅ contains
- ✅ clone
- ✅ sort

**OrderedMap Operations** (9 benchmarks in `map_bench.zig`):
- ✅ set (small, 3 entries)
- ✅ set (large, 20 entries)
- ✅ get
- ✅ contains
- ✅ remove
- ✅ iteration
- ✅ clone
- ✅ string keys

**String Operations** (14 benchmarks in `string_bench.zig`):
- ✅ utf8ToUtf16 (ASCII)
- ✅ utf8ToUtf16 (Unicode)
- ✅ utf16ToUtf8 (ASCII)
- ✅ utf16ToUtf8 (Unicode)
- ✅ asciiLowercase
- ✅ asciiUppercase
- ✅ isAsciiCaseInsensitiveMatch
- ✅ stripWhitespace
- ✅ stripNewlines
- ✅ normalizeNewlines
- ✅ splitOnWhitespace
- ✅ splitOnCommas
- ✅ concatenate

**JSON Operations** (13 benchmarks in `json_bench.zig`):
- ✅ parse null
- ✅ parse boolean
- ✅ parse number
- ✅ parse string
- ✅ parse array (small, 3 items)
- ✅ parse array (large, 20 items)
- ✅ parse object (small, 2 keys)
- ✅ parse object (large, nested)
- ✅ serialize null
- ✅ serialize boolean
- ✅ serialize number
- ✅ serialize string
- ✅ serialize array

**Base64 Operations** (10 benchmarks in `base64_bench.zig`):
- ✅ encode (small, 5 bytes)
- ✅ encode (medium, 32 bytes)
- ✅ encode (large, 256 bytes)
- ✅ decode (small)
- ✅ decode (medium)
- ✅ decode (large)
- ✅ decode (with whitespace)
- ✅ roundtrip (small)
- ✅ roundtrip (large)

---

## Phase 1: Quick Wins - Missing Benchmarks

### ❌ List with Configurable Inline Capacity

**Need to add**:
- List with inline_capacity = 0 (always heap)
- List with inline_capacity = 2 (tiny)
- List with inline_capacity = 8 (medium)
- List with inline_capacity = 16 (large)
- Compare append performance across different capacities

**Why**: Test impact of configurable inline capacity parameter

### ❌ List Batch Operations

**Need to add**:
- appendSlice (3 items, all inline)
- appendSlice (10 items, mixed inline/heap)
- appendSlice (100 items, all heap)

**Why**: Phase 1 adds batch operations for performance

### ❌ Map with Different Key Types

**Need to add**:
- Map with integer keys (fast path)
- Map with string keys (current)
- Map with complex keys (generic path)

**Why**: Phase 1 adds comptime type specialization for Map.get()

### ❌ String SIMD Improvements

**Current coverage**: ASCII detection is tested via utf8ToUtf16  
**Need to add**:
- String comparison (eql) - short strings (< 8 chars)
- String comparison (eql) - long strings (> 64 chars)
- ASCII detection specifically (standalone benchmark)
- SIMD vector size comparison (16 bytes vs 32 bytes)

**Why**: Phase 1 improves SIMD ASCII detection and adds string comparison

---

## Phase 2: String Optimizations - Missing Benchmarks

### ❌ Dual 8-bit/16-bit String Representation

**Need to add**:
- String operations on ASCII strings (8-bit representation)
- String operations on Unicode strings (16-bit representation)
- Comparison of memory usage (8-bit vs 16-bit)
- Conversion cost (UTF-8 → 8-bit Latin-1 vs UTF-8 → 16-bit UTF-16)

**Why**: Phase 2 implements dual representation for 50% memory savings

### ❌ String indexOf

**Need to add**:
- indexOf (single character, short string)
- indexOf (single character, long string)
- indexOf (multi-character substring, short)
- indexOf (multi-character substring, long)
- indexOf (not found case)

**Why**: Phase 2 implements indexOf with SIMD and Boyer-Moore-Horspool

### ❌ String eql (Comparison)

**Need to add**:
- eql (equal strings, short)
- eql (equal strings, long)
- eql (unequal strings, differ at start)
- eql (unequal strings, differ at end)
- eql (different lengths)

**Why**: Phase 2 implements SIMD string comparison

### ❌ String contains

**Need to add**:
- contains (substring found)
- contains (substring not found)
- contains (single character)

**Why**: Phase 2 implements contains with Boyer-Moore-Horspool

---

## Phase 3: Advanced Optimizations - Missing Benchmarks

### ❌ Hybrid Map (Linear → Hash Table)

**Need to add**:
- Map operations at threshold (n = 12 entries)
- Map with 5 entries (linear search)
- Map with 15 entries (after upgrade to hash table)
- Map with 100 entries (large hash table)
- Measure upgrade cost (linear → hash table transition)

**Why**: Phase 3 implements hybrid map with dynamic upgrade

### ❌ Inline Small Strings

**Need to add**:
- String operations on strings ≤ 23 chars (inline)
- String operations on strings > 23 chars (heap)
- Compare memory allocation counts

**Why**: Phase 3 implements inline small strings (zero allocations)

### ❌ Rope Strings

**Need to add**:
- String concatenation (2 strings)
- String concatenation (10 strings)
- String concatenation (100 strings)
- Rope flattening cost
- Compare rope vs immediate concatenation

**Why**: Phase 3 implements rope strings for O(1) concatenation

---

## Phase 4: Polish & Platform-Specific - Missing Benchmarks

### ❌ Platform-Specific SIMD

**Need to add**:
- ASCII detection with 16-byte vectors (SSE2/NEON)
- ASCII detection with 32-byte vectors (AVX2)
- String comparison with 16-byte vectors
- String comparison with 32-byte vectors

**Why**: Phase 4 adds platform-specific SIMD paths

### ❌ Cache Line Alignment

**Need to add**:
- Large list operations (aligned vs unaligned)
- Large map operations (aligned vs unaligned)
- Measure cache miss rates (would need perf counters)

**Why**: Phase 4 adds cache line alignment for large structures

---

## Benchmark Implementation Priority

### Priority 1: Add Before Phase 1 Implementation

1. ✅ **List batch operations** (appendSlice) - NEW BENCHMARK NEEDED
2. ✅ **String comparison** (eql) - NEW BENCHMARK NEEDED
3. ✅ **ASCII detection standalone** - NEW BENCHMARK NEEDED

### Priority 2: Add Before Phase 2 Implementation

1. ✅ **String indexOf** - NEW BENCHMARK NEEDED
2. ✅ **String contains** - NEW BENCHMARK NEEDED
3. ✅ **Dual string representation** - NEW BENCHMARK NEEDED

### Priority 3: Add Before Phase 3 Implementation

1. ✅ **Hybrid map at different sizes** - NEW BENCHMARK NEEDED
2. ✅ **Inline small strings** - NEW BENCHMARK NEEDED
3. ✅ **Rope string concatenation** - NEW BENCHMARK NEEDED

### Priority 4: Add Before Phase 4 Implementation

1. ✅ **Platform-specific SIMD** - NEW BENCHMARK NEEDED
2. ✅ **Cache alignment** - NEW BENCHMARK NEEDED

---

## Action Plan

### Step 1: Establish Current Baseline

Run existing benchmarks and save results:

```bash
zig build bench > benchmarks/baseline_before_phase1.txt
```

### Step 2: Add Phase 1 Benchmarks

Create new benchmark files:
- `benchmarks/list_advanced_bench.zig` - Configurable capacity, batch operations
- `benchmarks/string_advanced_bench.zig` - eql, indexOf, contains, ASCII detection
- `benchmarks/map_types_bench.zig` - Different key types

### Step 3: Run Phase 1 Baseline

```bash
zig build bench > benchmarks/baseline_with_phase1_benches.txt
```

### Step 4: Implement Phase 1 Optimizations

Follow implementation plan from `analysis/ZIG_OPTIMIZATION_ANALYSIS.md`

### Step 5: Run Phase 1 Results

```bash
zig build bench > benchmarks/results_after_phase1.txt
diff benchmarks/baseline_with_phase1_benches.txt benchmarks/results_after_phase1.txt
```

### Step 6: Repeat for Phases 2-4

Add benchmarks → Run baseline → Implement optimizations → Compare results

---

## Success Criteria

### Phase 1 Targets (Quick Wins)

- List operations: **≤10 ns/op**
- Map get (small): **≤5 ns/op**
- String operations: **≤2 ns/char**
- **20-30% overall performance improvement**
- **40-50% allocation reduction**

### Phase 2 Targets (String Optimizations)

- String memory (ASCII): **50% reduction** (8-bit vs 16-bit)
- String indexOf: **10× faster** (single char), **3-5× faster** (substring)
- String eql: **2-3× faster** (long strings)

### Phase 3 Targets (Advanced)

- Map get (large): **O(1)** instead of O(n) after hybrid upgrade
- String concatenation: **5-10× faster** with rope strings
- Small strings: **Zero allocations** for ≤23 chars

### Phase 4 Targets (Polish)

- Platform SIMD: **20-30% faster** on supported platforms
- Cache alignment: **10-20% faster** for large structures
- **Match or exceed browser performance**

---

## Measurement Notes

### What to Measure

1. **Time per operation** (ns/op) - Primary metric
2. **Total time** (ms) - For relative comparison
3. **Memory allocations** - Count allocations via GPA
4. **Memory usage** - Peak memory during benchmark
5. **Throughput** (ops/sec) - For bulk operations

### How to Compare

```bash
# Before optimization
zig build bench > before.txt

# After optimization  
zig build bench > after.txt

# Compare
diff before.txt after.txt

# Or use a more sophisticated tool
python scripts/compare_benchmarks.py before.txt after.txt
```

### Statistical Significance

- Run each benchmark **3-5 times**
- Take **median** value (not mean, to avoid outliers)
- Report **standard deviation** if variance is high
- Warm up allocator state before measurement

---

## Next Steps

1. ✅ Create missing benchmark files for Phase 1
2. ✅ Run baseline benchmarks
3. ✅ Implement Phase 1 optimizations
4. ✅ Compare results
5. ✅ Decide: keep or revert based on data
6. ✅ Repeat for Phases 2-4

**Remember**: Measure first, optimize second, verify third. Let the data guide decisions.
