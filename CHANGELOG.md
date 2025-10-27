# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
