# Browser Implementation Research Index

Complete index of research on browser implementations of WHATWG Infra primitives.

## Research Documents

### 1. **WEBKIT_JSC_RESEARCH.md** (Comprehensive)
Deep dive into JavaScriptCore/WebKit optimizations.

**Contents:**
- Executive Summary
- Data Structure Optimizations (WTF::Vector, WTF::String, JSC::Structure, JSValue)
- Hot Path Optimizations (DFG JIT, FTL JIT)
- JSON Parsing Optimizations
- Base64 Optimizations
- Memory Allocation Patterns (Butterfly storage, Small object optimization)
- Apple Silicon Optimizations
- Benchmarking Methodology
- Lessons for Zig Implementation

**Key Findings:**
- 8-bit vs 16-bit string paths → 50% memory savings
- Inline storage → 60-70% allocation elimination
- Structure-based inline caching → 10-20× speedup
- Four-tier JIT (LLInt → Baseline → DFG → FTL)

**Read this:** For deep understanding of WebKit architecture

---

### 2. **WEBKIT_OPTIMIZATION_SUMMARY.md** (Quick Reference)
Practical guide with priority matrix and decision trees.

**Contents:**
- Top 10 Actionable Optimizations (ranked)
- Performance Targets (latency and memory)
- Memory Overhead Targets
- Optimization Decision Tree
- Implementation Priority Matrix
- Anti-Patterns to Avoid
- Profiling Checklist
- Quick Wins for WHATWG Infra

**Key Tools:**
- Priority matrix (impact vs complexity)
- Decision tree for optimization selection
- Performance targets for validation

**Read this:** Before starting implementation

---

### 3. **WEBKIT_ZIG_EXAMPLES.md** (Code Examples)
Copy-pasteable Zig implementations of WebKit patterns.

**Contents:**
1. Inline-Storage ArrayList
2. Dual-Representation Strings (8-bit/16-bit)
3. Character Classification Lookup Tables
4. Small OrderedMap with Inline Storage
5. SIMD Base64 Decode
6. Branchless Operations

**Features:**
- Production-ready code
- Full test coverage
- Extensive comments
- Performance notes

**Read this:** When implementing optimizations

---

## Quick Start Guide

### For Understanding
```
1. Read: BROWSER_IMPLEMENTATION_RESEARCH.md (existing)
2. Read: WEBKIT_OPTIMIZATION_SUMMARY.md (priority matrix)
3. Skim: WEBKIT_JSC_RESEARCH.md (architecture details)
```

### For Implementation
```
1. Check: WEBKIT_OPTIMIZATION_SUMMARY.md (decision tree)
2. Copy: WEBKIT_ZIG_EXAMPLES.md (code patterns)
3. Validate: Performance targets in summary
4. Reference: WEBKIT_JSC_RESEARCH.md (deep dives)
```

## Optimization Priority

Based on impact/complexity analysis:

### Priority 1 (Start Here) ⭐⭐⭐
1. **8-bit vs 16-bit strings** (`WEBKIT_ZIG_EXAMPLES.md` §2)
   - Impact: 50% memory, 2× speed
   - Complexity: Medium
   
2. **Inline storage** (`WEBKIT_ZIG_EXAMPLES.md` §1, §4)
   - Impact: 60-70% fewer allocations
   - Complexity: Low-Medium
   
3. **Lookup tables** (`WEBKIT_ZIG_EXAMPLES.md` §3)
   - Impact: 5-10× faster char ops
   - Complexity: Low

### Priority 2 (Next) ⭐⭐
4. **SIMD operations** (`WEBKIT_ZIG_EXAMPLES.md` §5)
   - Impact: 4-8× throughput
   - Complexity: High
   
5. **Capacity hints**
   - Impact: 50-80% fewer reallocs
   - Complexity: Low
   
6. **Branchless ops** (`WEBKIT_ZIG_EXAMPLES.md` §6)
   - Impact: 2-3× in tight loops
   - Complexity: Low

### Priority 3 (Later) ⭐
7. Growth strategy (1.5× not 2×)
8. Monomorphic design patterns
9. Zero-copy string views

## Architecture Mapping

| WHATWG Infra | WebKit/JSC | Zig Implementation |
|--------------|------------|-------------------|
| `list` | WTF::Vector | `InlineArrayList` |
| `ordered map` | JSObject properties | `SmallOrderedMap` |
| `ordered set` | WTF::HashSet | `SmallOrderedSet` |
| `string` | WTF::String | Dual-repr String |
| `code point` | UChar32 | `u21` |
| `byte sequence` | Vector<uint8_t> | `[]const u8` |

## Performance Validation

Use these targets from JSC benchmarks:

### Latency Targets (per operation, M1 Pro)
- List append: 5-10 ns
- Map get (monomorphic): 3-5 ns
- Map get (polymorphic): 8-15 ns
- String concat (ASCII): 1-2 ns/char
- JSON parse: 50-100 ns/object
- Base64 encode: 1-2 ns/byte

### Memory Targets
- List overhead: ≤24 bytes
- Map overhead: ≤32 bytes
- String overhead: ≤16 bytes
- Inline storage hit rate: ≥60%

## Key Insights from Research

### 1. **Speculation vs Static Types**
- JSC: Uses JIT, profile-guided optimization, speculation
- Zig: Uses AOT, static types, compile-time optimization
- **Takeaway:** We can achieve JSC-like performance with simpler code via static types

### 2. **Memory vs Speed Trade-offs**
- JSC: Optimizes for average case, tolerates some waste
- Zig: Can optimize for both (static analysis + manual control)
- **Takeaway:** Inline storage + static allocation = best of both worlds

### 3. **SIMD Opportunities**
- JSC: Runtime CPU detection, dynamic codegen
- Zig: Compile-time CPU features, static vectorization
- **Takeaway:** Use comptime for zero-cost SIMD abstraction

### 4. **String Representation**
- JSC: UTF-16 primary (web platform), Latin-1 optimization
- Zig Infra: UTF-16 required (WHATWG spec), need Latin-1 optimization too
- **Takeaway:** Dual representation is non-negotiable for performance

## Implementation Checklist

Before implementing any optimization:

- [ ] Is it in Priority 1? (Start there)
- [ ] Does it align with WHATWG spec requirements?
- [ ] Have you profiled to confirm it's hot?
- [ ] Do you have tests ready?
- [ ] Can you measure the improvement?

After implementing:

- [ ] Does it pass all tests?
- [ ] Does it meet performance targets?
- [ ] Is the code readable?
- [ ] Have you updated benchmarks?
- [ ] Have you documented tradeoffs?

## Further Reading

### WebKit Blog
- [Introducing the WebKit FTL JIT](https://webkit.org/blog/3362/introducing-the-webkit-ftl-jit/) (2014)
- [Speculation in JavaScriptCore](https://webkit.org/blog/10308/speculation-in-javascriptcore/) (2020)
- [Introducing SquirrelFish Extreme](https://webkit.org/blog/214/introducing-squirrelfish-extreme/) (2008)
- [Introducing B3 JIT Compiler](https://webkit.org/blog/5852/introducing-the-b3-jit-compiler/) (2015)

### Papers
- "Efficient Implementation of the Smalltalk-80 System" (Deutsch & Schiffman, 1984)
  - Original polymorphic inline caching paper
- "An Efficient Implementation of SELF" (Chambers, Ungar, Lee, 1989)
  - Maps/structures paper
- "Adaptive Optimization in the Jalapeño JVM" (Arnold et al, 2000)
  - Profile-guided optimization

### Source Code
- WebKit: `Source/WTF/` (Web Template Framework)
- JavaScriptCore: `Source/JavaScriptCore/`
- Chromium V8: Similar techniques, different implementation

## Related Files

```
analysis/
├── BROWSER_RESEARCH_INDEX.md          ← You are here
├── BROWSER_IMPLEMENTATION_RESEARCH.md ← Original Chrome research
├── WEBKIT_JSC_RESEARCH.md            ← Deep dive
├── WEBKIT_OPTIMIZATION_SUMMARY.md     ← Quick reference
└── WEBKIT_ZIG_EXAMPLES.md            ← Code examples
```

## Questions? Decision Tree

**"Which document should I read?"**
```
┌─ Want to understand architecture? ───────────────┐
│                                                   │
Yes → WEBKIT_JSC_RESEARCH.md                        │
│                                                   │
No ─┬─ Want quick optimization guide? ─────────────┘
    │
    Yes → WEBKIT_OPTIMIZATION_SUMMARY.md
    │
    No ─┬─ Want copy-paste code? ─────────────
        │
        Yes → WEBKIT_ZIG_EXAMPLES.md
        │
        No ─→ Start with this index!
```

**"Should I optimize this?"**
```
Use decision tree in WEBKIT_OPTIMIZATION_SUMMARY.md
```

**"How do I implement inline storage?"**
```
See WEBKIT_ZIG_EXAMPLES.md §1 (ArrayList)
See WEBKIT_ZIG_EXAMPLES.md §4 (OrderedMap)
```

**"What performance should I expect?"**
```
See targets in WEBKIT_OPTIMIZATION_SUMMARY.md
```

---

## Summary

This research provides:

1. ✅ **Understanding** of how browsers optimize Infra primitives
2. ✅ **Priorities** for which optimizations to implement first
3. ✅ **Code** examples ready to use in Zig
4. ✅ **Targets** to validate performance
5. ✅ **Guidance** on when to optimize and when not to

**Start with:** `WEBKIT_OPTIMIZATION_SUMMARY.md` → `WEBKIT_ZIG_EXAMPLES.md`

**Deep dive when needed:** `WEBKIT_JSC_RESEARCH.md`

---

**Last Updated:** 2025-10-31
**Research Focus:** WebKit/JavaScriptCore optimizations for WHATWG Infra
**Next Steps:** Apply Priority 1 optimizations to `src/` implementations
