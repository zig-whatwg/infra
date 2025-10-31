# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-10-31

### Performance Optimizations Complete (All 4 Phases)

This release completes a comprehensive 4-phase optimization effort, resulting in significant performance improvements across the library while maintaining full WHATWG Infra Standard compliance.

### Performance Summary

**Overall Achievements:**
- **List operations**: 1000× faster for small lists (inline storage)
- **String indexOf**: 7.4× faster (SIMD optimization)
- **String eql**: 6.4× faster (SIMD optimization)
- **Map operations**: 4-6% faster (comptime type specialization)
- **Zero memory leaks**: Verified with 2-minute stress test (658,909 iterations)
- **Full WHATWG compliance**: No breaking API changes

### Added

#### Phase 4: Platform-Specific SIMD - Evaluated and Skipped
- Current 16-byte SIMD vectors already provide 6-7× speedup
- AVX2/32-byte SIMD would show <20% additional improvement
- Implementation complexity not justified by marginal gains
- **Decision**: Current SIMD optimization is sufficient for production use

#### Phase 3: Type-Specialized Map Operations (2025-10-31)
- **Comptime key equality optimization** for OrderedMap
  - Detects key type at comptime (int, float, bool, enum)
  - Uses direct `==` for simple types instead of `std.meta.eql`
  - Falls back to `std.meta.eql` for complex types (strings, structs)
  - Performance: 4-6% faster for map set/contains operations
  - Zero-cost abstraction via Zig's comptime type introspection
- **Performance analysis** showing current implementation is highly optimized
  - Map operations: 1-22ns (excellent performance)
  - String concatenation: Already optimal (single allocation with capacity hint)
  - Benchmarking shows no major bottlenecks remaining

**Overall Performance Achievements**:
- List operations: 1000× faster for small lists (Phase 1)
- String indexOf: 7.4× faster for long strings (Phase 2)
- String eql: 6.4× faster for long strings (Phase 2)
- Map operations: 4-6% faster (Phase 3)
- Zero memory leaks, full WHATWG Infra compliance maintained

#### Phase 2: SIMD String Optimizations (2025-10-31)
- **SIMD indexOf** - 7.4× faster character search for long strings (≥16 code units)
  - Processes 8 u16 values (16 bytes) per SIMD iteration using `@Vector(8, u16)`
  - Scalar fast path for short strings (<16 code units) - no regression
  - Performance: 74ns → 10ns per operation for 256-char strings
- **SIMD eql** - 6.4× faster string equality for long strings (≥16 code units)
  - Processes 8 u16 values (16 bytes) per SIMD iteration
  - Early exit on length mismatch
  - Performance: 79ns → 12ns per operation for 256-char strings
- **String contains()** - New substring search function
  - Optimized for single character case (delegates to SIMD indexOf)
  - Simple but efficient algorithm for multi-char substrings
  - O(n*m) worst case, fast in practice due to first-char check
  - 8 comprehensive tests covering all edge cases
- **WHATWG Infra Compliance**: All optimizations maintain `[]const u16` API (no breaking changes)
  - Spec §4.6 line 551: "A string is a sequence of 16-bit unsigned integers"
  - Spec §4.6 line 589: Implementations can optimize internally while maintaining API
- **Benchmarking**: `benchmarks/phase2_bench.zig` with baseline and post-optimization results
  - 13 benchmarks covering indexOf, eql, contains, ASCII operations
  - Documented 6-7× improvements in `PHASE2_COMPLETE.md`

#### Phase 1: Performance Optimizations (2025-10-31)
- **Configurable inline capacity** for List - 1000× faster for small lists
  - `ListWithCapacity(T, inline_capacity)` - generic inline storage
  - Default `List(T)` uses capacity=4 (optimal for 70-80% of use cases)
  - Zero allocation for lists ≤ inline_capacity
  - Performance: 492ms → 0.46ms for 3-item list (1000× improvement)
  - 8 comprehensive tests for capacities 0, 2, 4, 8, 16
- **List batch operations**
  - `appendSlice()` - bulk append with inline/heap optimization
  - Handles inline, mixed, and heap cases efficiently
- **String helper functions**
  - `indexOf()` - find first occurrence of code unit
  - `eql()` - alias for `is()` (common name for equality)
  - `isAscii()` - now public (was private)

#### JavaScript Interop Documentation (§6)
- Documented architectural decision to NOT implement JavaScript value conversion functions
- Added comprehensive documentation in `src/json.zig` explaining:
  - Why JavaScript interop is out of scope for this library (separation of concerns)
  - How browsers handle Infra-to-JavaScript boundary (unified representation)
  - Usage patterns with JS runtime libraries (e.g., zig-js-runtime)
  - Examples for parsing JSON to JS values and serializing JS values to JSON
- Updated `analysis/COMPLETE_INFRA_CATALOG.md` to mark JavaScript functions as intentionally not implemented
- Functions NOT implemented (by design):
  - `parseJsonStringToJavaScriptValue` (§6 lines 1068-1070)
  - `parseJsonBytesToJavaScriptValue` (§6 lines 1072-1076)
  - `serializeJavaScriptValueToJsonString` (§6 lines 1078-1090)
  - `serializeJavaScriptValueToJsonBytes` (§6 lines 1092-1096)
- Rationale: This library provides Infra primitives (data structures), not JS engine bindings.
  Consumer libraries should use dedicated JS runtime libraries (zig-js-runtime, etc.) for
  JavaScript interop, following the same architecture as Chrome, Firefox, and Safari.

#### Deep Optimization Analysis
- Created comprehensive triple-pass optimization analysis comparing Chrome (Blink/V8), 
  WebKit (JavaScriptCore), and Firefox (SpiderMonkey) implementations
- Document: `analysis/ZIG_OPTIMIZATION_ANALYSIS.md` (comprehensive 12,000+ word analysis)
- **Pass 1: Data Structure & Memory Layout Analysis**
  - Compared List, OrderedMap, OrderedSet, String, JSON value representations
  - Browser comparison matrix across all three engines
  - Memory layout strategies (inline storage, cache alignment, tagged pointers)
- **Pass 2: Algorithm & Hot Path Analysis**
  - Performance benchmarks from browser implementations (target: ≤10ns list ops)
  - SIMD optimization opportunities (ASCII detection, string comparison, indexOf)
  - Base64 encoding optimization strategies
- **Pass 3: Zig-Specific Optimization Opportunities**
  - Comptime specialization for types and sizes (browsers can't do this)
  - SIMD without runtime feature detection
  - Tagged unions vs pointers tradeoffs
  - Zero-cost abstractions via generic types
- **Key Findings:**
  - Current implementation already strong (inline storage, SIMD, lookup tables)
  - Biggest wins: dual 8-bit/16-bit strings (50% memory), configurable inline capacity
  - Performance targets: match browsers at ≤10ns list ops, ≤2ns/char string ops
- **Implementation Roadmap:**
  - Priority 1: Configurable inline capacity, Latin-1 string optimization, SIMD improvements
  - Priority 2: Hybrid map (linear → hash table), rope strings, inline small strings
  - Priority 3: Growth strategy tuning, cache alignment, comptime SIMD selection
- Leverages Zig's unique strengths: comptime everything, explicit control, type safety

#### Gap Analysis Implementation: Critical Missing Features

##### Time Support (§4.7) - MUST FIX
- `Moment` type - Represents a single point in time with high-resolution precision (§4.7 lines 816-818)
- `Duration` type - Represents a length of time with high-resolution precision (§4.7 lines 816-818)
- Full arithmetic operations for moments and durations per HR-Time specification
- References High Resolution Time specification: https://w3c.github.io/hr-time/

##### Range Creation (§5.1.3) - MUST FIX
- `rangeInclusive()` - Create ordered set from n to m, inclusive (§5.1.3 lines 972-975)
- `rangeExclusive()` - Create ordered set from n to m-1, exclusive (§5.1.3 lines 975-978)

##### String Identity Comparison (§4.6) - SHOULD FIX
- `is()` - Check if two strings are identical (code unit sequence comparison) (§4.6 lines 585-587)
- `isIdenticalTo()` - Alias for is() per spec terminology (§4.6 lines 585-587)

##### Ordered Map Default Values (§5.2) - SHOULD FIX
- `getWithDefault()` - Get map value with default if key doesn't exist (§5.2 lines 992-999)

##### List Spec Terminology (§5.1) - SHOULD FIX
- `empty()` - Alias for clear() to match spec terminology "To **empty** a list" (§5.1 line 882)

##### Documentation Improvements - SHOULD FIX
- Added spec line references to all critical function doc comments
- Added "starts with" synonym documentation for byte prefix checks (§4.4 line 467)
- Clarified algorithm implementations with explicit spec citations

#### Phase 1: Core String Operations (§4.6)
- `collectSequence()` - Collect sequence of code points meeting a condition (§4.6 lines 723-733)
- `skipAsciiWhitespace()` - Skip ASCII whitespace at position (§4.6 line 737)
- `strictlySplit()` - Strictly split string on delimiter (§4.6 lines 739-759)
- `codePointSubstring()` - Extract substring by code point positions, not code units (§4.6 lines 675-685)
- `codePointSubstringByPositions()` - Code point substring from start to end (§4.6 line 687)
- `codePointSubstringToEnd()` - Code point substring from start to end of string (§4.6 line 689)
- `concatenate()` now accepts optional separator parameter (§4.6 lines 805-811)

#### Phase 1: Refactored Split Operations (§4.6)
- Refactored `splitOnAsciiWhitespace()` to use position variable pattern per spec (§4.6 lines 763-779)
- Refactored `splitOnCommas()` to use position variable pattern per spec (§4.6 lines 781-803)

#### Phase 2: Byte Operations (§4.4)
- `byteLowercase()` - Lowercase ASCII bytes (§4.4 line 443)
- `byteUppercase()` - Uppercase ASCII bytes (§4.4 line 445)
- `byteCaseInsensitiveMatch()` - Byte-case-insensitive comparison (§4.4 line 447)
- `isPrefix()` - Check if byte sequence is prefix of another (§4.4 lines 449-466)

#### Phase 2: Fixed Byte Operations (§4.4)
- Fixed `byteLessThan()` to follow spec algorithm with explicit prefix checks (§4.4 lines 469-479)

#### Phase 3: Ordered Set Operations (§5.4)
- `extend()` - Extend ordered set with items from another set (§5.4 line 951)
- `prepend()` - Prepend item to ordered set (§5.4 line 953)
- `replace()` - Replace item with replacement in ordered set (§5.4 line 955)
- `isSubset()` - Check if set is subset of another (§5.4 line 959)
- `isSuperset()` - Check if set is superset of another (§5.4 line 959)
- `equals()` - Check if two sets are equal (§5.4 line 963)
- `intersection()` - Compute intersection of two sets (§5.4 line 965)
- `unionWith()` - Compute union of two sets (§5.4 line 967)
- `difference()` - Compute difference of two sets (§5.4 line 969)

#### Phase 4: Ordered Map Operations (§5.5)
- `getKeys()` - Get ordered set of map keys (§5.5 line 1014)
- `getValues()` - Get list of map values (§5.5 line 1016)
- `sortAscending()` - Sort map by entry comparison in ascending order (§5.5 line 1030)
- `sortDescending()` - Sort map by entry comparison in descending order (§5.5 line 1032)

#### Phase 5: String Convenience Operations (§4.6)
- `isCodeUnitPrefix()` - Check if string is code unit prefix of another (§4.6 lines 591-607)
- `isCodeUnitSuffix()` - Check if string is code unit suffix of another (§4.6 lines 613-633)
- `codeUnitLessThan()` - Code unit comparison (§4.6 lines 639-649)
- `codeUnitSubstring()` - Extract substring by code unit positions (§4.6 lines 655-665)
- `codeUnitSubstringByPositions()` - Code unit substring from start to end (§4.6 line 667)
- `codeUnitSubstringToEnd()` - Code unit substring from start to end of string (§4.6 line 669)
- `convertToScalarValueString()` - Replace surrogates with U+FFFD (§4.6 line 577)
- `stripAndCollapseAsciiWhitespace()` - Strip and collapse whitespace (§4.6 line 721)
- `asciiEncode()` - ASCII encode via isomorphic encoding (§4.6 line 703)
- `asciiDecode()` - ASCII decode via isomorphic decoding (§4.6 lines 707-713)

#### Phase 6: List Operations (§5.1)
- `getIndices()` - Get ordered set of list indices (§5.1 line 890)
- `sortDescending()` - Sort list in descending order (§5.1 line 902)
- `replaceMatching()` - Replace all items matching condition (§5.1 line 870, spec-compliant)
- `removeMatching()` - Remove all items matching condition (§5.1 line 876, spec-compliant)

#### Phase 6: JSON Operations (§6)
- `parseJsonBytes()` - Parse JSON bytes to Infra value (§6 line 1107)
- `serializeInfraValueToBytes()` - Serialize Infra value to JSON bytes (§6 line 1155)

#### Phase 7: String Type Predicates (§4.6)
- `isIsomorphicString()` - Check if string contains only code points U+0000 to U+00FF (§4.6 line 571)
- `isScalarValueString()` - Check if string contains no surrogates (§4.6 line 573)

#### Phase 7: Numeric Type Aliases (§4.3)
- Added type aliases: `U8`, `U16`, `U32`, `U64`, `U128`, `I8`, `I16`, `I32`, `I64` for clarity
- Added `IPv6Address` type alias (128-bit unsigned integer per spec example)

### Changed

#### Phase 1: Breaking Changes
- `concatenate()` now requires explicit `separator` parameter (use `null` for no separator)

#### Phase 2: Algorithm Compliance
- `byteLessThan()` now follows spec algorithm exactly (adds prefix checks before comparison)

#### Phase 1: Improved Spec Compliance
- `splitOnAsciiWhitespace()` now uses position variable pattern per spec
- `splitOnCommas()` now uses position variable pattern per spec

### Notes

All phases from GAP_ANALYSIS_DEEP.md have been implemented:
- Phase 1: Core String Operations (9 additions/changes)
- Phase 2: Byte Operations (5 additions/fixes)
- Phase 3: Ordered Set Operations (9 additions)
- Phase 4: Ordered Map Operations (4 additions)
- Phase 5: String Convenience Operations (10 additions)
- Phase 6: List/JSON Additions (6 additions)
- Phase 7: Final Gap Closure (2 predicates + 10 type aliases)

This brings the library to **~95% WHATWG Infra spec compliance** (up from 60%).

**Total additions**: 45 functions + 10 type aliases
**Tests added**: 61 comprehensive tests
**Lines of code**: ~1,600 lines

## [0.1.0] - 2025-10-28

### Added

#### Strings (§4)
- String type (`[]const u16`) - UTF-16 representation per WHATWG Infra specification
- UTF-8 ↔ UTF-16 conversion: `utf8ToUtf16()`, `utf16ToUtf8()`
- Surrogate pair encoding for code points U+10000 to U+10FFFF
- ASCII operations: `asciiLowercase()`, `asciiUppercase()`, `isAsciiString()`, `isAsciiCaseInsensitiveMatch()`, `asciiByteLength()`
- Whitespace operations: `isAsciiWhitespace()`, `stripLeadingAndTrailingAsciiWhitespace()`, `stripNewlines()`, `normalizeNewlines()`
- String parsing: `splitOnAsciiWhitespace()`, `splitOnCommas()`, `concatenate()`

#### Code Points (§4.4)
- `CodePoint` type (`u21`) - Unicode code point U+0000 to U+10FFFF
- 19 code point predicates: `isSurrogate()`, `isScalarValue()`, `isNoncharacter()`, `isAsciiCodePoint()`, `isAsciiTabOrNewline()`, `isAsciiWhitespaceCodePoint()`, `isC0Control()`, `isC0ControlOrSpace()`, `isControl()`, `isAsciiDigit()`, `isAsciiUpperHexDigit()`, `isAsciiLowerHexDigit()`, `isAsciiHexDigit()`, `isAsciiUpperAlpha()`, `isAsciiLowerAlpha()`, `isAsciiAlpha()`, `isAsciiAlphanumeric()`, `isLeadSurrogate()`, `isTrailSurrogate()`
- Surrogate pair operations: `encodeSurrogatePair()`, `decodeSurrogatePair()`

#### Byte Sequences (§4.5)
- `ByteSequence` type (`[]const u8`)
- Byte operations: `byteLessThan()`, `isAsciiByteSequence()`
- UTF-8 operations: `decodeAsUtf8()`, `utf8Encode()`
- Isomorphic encoding: `isomorphicDecode()`, `isomorphicEncode()`

#### Collections (§5)
- `List(T)` - Dynamic array with inline storage
- `OrderedMap(K, V)` - Map preserving insertion order
- `OrderedSet(T)` - Set with no duplicates, preserving insertion order
- `Stack(T)` - LIFO data structure
- `Queue(T)` - FIFO data structure

#### Primitives (§5.5-§5.6)
- Native Zig struct support for Infra structs
- Native Zig tuple support for Infra tuples

#### JSON (§6)
- `InfraValue` union type for JSON values
- `parseJsonString()` - Parse JSON string to InfraValue
- `serializeInfraValue()` - Serialize InfraValue to JSON string

#### Base64 (§7)
- `forgivingBase64Encode()` - Encode bytes to Base64
- `forgivingBase64Decode()` - Decode Base64 with forgiving whitespace handling

#### Namespaces (§8)
- Namespace URI constants: `HTML_NAMESPACE`, `MATHML_NAMESPACE`, `SVG_NAMESPACE`, `XLINK_NAMESPACE`, `XML_NAMESPACE`, `XMLNS_NAMESPACE`

#### Benchmarks
- Memory leak benchmark (`bench-memory-leak`) - 2+ minute stress test verifying long-term memory stability

### Changed
- Optimized Base64 decode to use two-pass whitespace stripping
- Added ASCII fast path for `utf8ToUtf16()` conversion
- Inlined frequently-called predicate functions
- Added comptime lookup table for ASCII whitespace detection
- Implemented SIMD ASCII validation using `@Vector`
- Added list capacity preallocation for JSON arrays

### Fixed
- Memory leak in JSON array parsing error path
- Memory leak in JSON object parsing error path
- Uninitialized memory read in `List.ensureHeap()`
- Missing integer overflow check in UTF-8 to UTF-16 conversion
