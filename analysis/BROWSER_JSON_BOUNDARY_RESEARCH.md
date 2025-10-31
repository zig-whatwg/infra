# Browser Infra-to-JavaScript JSON Boundary Research

**Research Date:** October 31, 2025  
**Issue:** infra-16  
**Purpose:** Understand how Chrome (Blink/V8), WebKit (JavaScriptCore), and Firefox (SpiderMonkey) handle the boundary between WHATWG Infra primitives and JavaScript values for JSON operations.

---

## Executive Summary

**Key Finding:** Browsers **blur the line** between WHATWG Infra primitives and JavaScript engine primitives for JSON operations. They do **not** maintain separate Infra primitive representations. Instead:

1. **JSON parsing directly produces JavaScript engine values** (V8 `Object`, JSC `JSValue`, SpiderMonkey `JS::Value`)
2. **JSON serialization directly consumes JavaScript engine values** without conversion to Infra primitives
3. **No distinct Infra layer exists** — the WHATWG Infra spec is a **conceptual model** that browser implementations optimize away
4. **Type conversions happen implicitly** through the engine's native object model

This has **critical implications** for a Zig WHATWG Infra implementation:
- We should **not** create separate Infra value types and JavaScript value types
- JSON operations can work directly with Infra primitives (lists, maps, strings)
- The "boundary" is **conceptual only** — implementations merge the layers for performance

---

## 1. How Browsers Represent Infra Values vs JavaScript Values

### WebKit (JavaScriptCore)

**Finding:** JavaScriptCore uses **`JSValue`** as the unified representation for both Infra concepts and JavaScript values.

**Evidence from Source Code:**

```cpp
// Source/JavaScriptCore/runtime/JSONObject.h
JSValue JSONParse(JSGlobalObject*, StringView);
JSValue JSONParseWithException(JSGlobalObject*, StringView);
String JSONStringify(JSGlobalObject*, JSValue, JSValue space);
```

**Key Points:**
- `JSValue` is a tagged pointer (64-bit) that can represent:
  - Numbers (as immediate values)
  - Pointers to objects (`JSObject*`)
  - Booleans, null, undefined (special values)
- **No separate "Infra Value" type exists**
- `StringView` is used for input (C++ string abstraction), but parsing directly produces `JSValue`

**Object Model (from WebKit blog post "Concurrent JavaScript"):**
```
Cell (fixed-size) → contains Structure pointer, type info
  ↓
Butterfly (resizable) → out-of-line properties + array elements
```

- **Infra "list"** → `JSArray` (with `Butterfly` for elements)
- **Infra "ordered map"** → `JSObject` (with `Structure` for property lookup)
- **Infra "string"** → `JSString` (internally uses `WTF::String` for UTF-16 storage)
- **Infra "code point"** → No separate type; represented as `uint32_t` in string operations

### Chrome (Blink/V8)

**Finding:** V8 uses **`v8::internal::Object`** (tagged pointer) as the unified representation.

**Evidence from Source Code:**

```cpp
// v8/src/json/json-parser.cc
MaybeHandle<Object> JsonParseInternalizer::Internalize(
    Isolate* isolate, DirectHandle<Object> result, Handle<Object> reviver,
    Handle<String> source, MaybeHandle<Object> val_node,
    bool pass_context_argument) {
  // ...
}
```

**Key Points:**
- `Object` is V8's fundamental type (Smi for small integers, HeapObject pointer otherwise)
- **No distinction between Infra primitives and JS values**
- JSON parser directly constructs `JSObject`, `JSArray`, `String`, `Number` from input
- V8's `Handle<T>` is a GC-safe smart pointer, not a type distinction

**Object Model:**
- **Infra "list"** → `JSArray` (with `FixedArray` elements backing store)
- **Infra "ordered map"** → `JSObject` (with `Map` for hidden class / structure)
- **Infra "string"** → `String` (SeqString, ConsString, SlicedString, ExternalString variants)
- V8 uses **hidden classes** (Maps) similar to JSC's Structures

### Firefox (SpiderMonkey)

**Finding:** SpiderMonkey uses **`JS::Value`** as the unified representation.

**Evidence from Source Code:**

```cpp
// js/src/builtin/JSON.cpp
namespace js {

using JS::AutoStableStringChars;
using JS::Value;

template <typename SrcCharT, typename DstCharT>
static bool QuoteJSONString(JSContext* cx, StringBuilder& sb, JSString* str) {
  JSLinearString* linear = str->ensureLinear(cx);
  // ...
}
```

**Key Points:**
- `JS::Value` is a 64-bit tagged union (similar to JSC's `JSValue` and V8's `Object`)
- **No separate Infra value representation**
- JSON operates directly on `JSObject`, `JSString`, `JSArray`

**Object Model:**
- **Infra "list"** → `ArrayObject` (with `ObjectElements` for storage)
- **Infra "ordered map"** → `PlainObject` / `NativeObject` (with `Shape` for property layout)
- **Infra "string"** → `JSString` (with `JSLinearString`, `JSRope` variants)

---

## 2. API Boundary Between Infra C++ Code and JS Engine

### Key Finding: **No Explicit Boundary**

All three browsers **collapse the Infra layer into the JS engine layer**. There is no API like:

```cpp
// This does NOT exist:
InfraValue parseJsonToInfraValue(String json);
JSValue convertInfraValueToJSValue(InfraValue infra);
```

Instead, the pattern is:

```cpp
// What actually exists:
JSValue parseJsonDirectly(String json); // Returns JS values directly
```

### WebKit Example (JSONObject.cpp)

```cpp
JSValue toJSON(JSValue value, const PropertyNameForFunctionCall& key) {
    // Checks if value has toJSON method
    // Calls it if present
    // Returns result directly as JSValue
}
```

**No Infra intermediate representation.** The `toJSON` method operates on `JSValue` throughout.

### V8 Example (json-parser.cc)

```cpp
template <typename Char>
Handle<Object> JsonParser<Char>::ParseJsonValue() {
  JsonToken token = Next();
  switch (token) {
    case JsonToken::STRING:
      return MakeString(ScanJsonString<false>());
    case JsonToken::NUMBER:
      return MakeNumber(ParseJsonNumber());
    case JsonToken::LBRACE:
      return ParseJsonObject();
    case JsonToken::LBRACK:
      return ParseJsonArray();
    // ...
  }
}
```

**Direct construction of JS values.** `MakeString` returns `Handle<String>`, not an Infra string.

### Firefox Example (JSONParser.h)

```cpp
class MOZ_STACK_CLASS JSONParser {
  bool parse(MutableHandleValue vp);
  bool parseObject(MutableHandleValue vp);
  bool parseArray(MutableHandleValue vp);
  // ...
}
```

**Output is `JS::Value` directly.** No Infra layer.

---

## 3. Implementation of WHATWG Infra JSON-to-JavaScript Functions

The WHATWG Infra specification defines these functions:

1. **`parseJsonStringToJavaScriptValue(string)`** — Parse JSON string to JS value
2. **`parseJsonBytesToJavaScriptValue(bytes)`** — Parse JSON bytes to JS value
3. **`serializeJavaScriptValueToJsonString(value)`** — Serialize JS value to JSON string
4. **`serializeJavaScriptValueToJsonBytes(value)`** — Serialize JS value to JSON bytes

### Implementation Pattern (All Browsers)

**These functions are NOT implemented as distinct functions.** Instead:

#### Parsing (String → JS Value)

**WebKit:**
```cpp
JSValue JSONParse(JSGlobalObject* globalObject, StringView json) {
    // Directly parses string and produces JSValue
    // Uses LiteralParser internally
}
```

**V8:**
```cpp
MaybeHandle<Object> JsonParser::Parse() {
    // Directly parses input and produces Handle<Object>
    // No intermediate Infra representation
}
```

**Firefox:**
```cpp
bool JSONParser::parse(MutableHandleValue vp) {
    // Directly parses input and stores result in JS::Value
}
```

#### Serialization (JS Value → String)

**WebKit:**
```cpp
class Stringifier {
    StringifyResult appendStringifiedValue(
        StringBuilder&, JSValue, const Holder&, const PropertyNameForFunctionCall&);
    // Walks JSValue tree and builds JSON string directly
}
```

**V8:**
```cpp
class JsonStringifier {
    Maybe<bool> Serialize_(Handle<Object> object, bool comma, Handle<String> key);
    // Walks V8 Object and builds JSON string directly
}
```

**Firefox:**
```cpp
bool Stringifier::Str(HandleValue v, HandleValue key, 
                      MutableHandleValue vp, StringifySession* session) {
    // Walks JS::Value and builds JSON string directly
}
```

### Critical Observation: **One-Step Conversion**

All browsers implement JSON parsing/serialization as:
1. **Parse:** `String → JSValue` (not `String → InfraValue → JSValue`)
2. **Stringify:** `JSValue → String` (not `JSValue → InfraValue → String`)

The Infra spec functions are **conceptual abstractions**, not actual implementation layers.

---

## 4. Do Browsers Keep Infra Primitives Separate from JS Primitives?

### Answer: **No, they blur the line completely.**

### Evidence

#### WebKit's Object Model

From the "Concurrent JavaScript" blog post, WebKit describes their object model in terms that **merge Infra and JS concepts**:

> "JavaScript shares a lot in common with languages like Java and .NET, which already support threads."

> "JavaScript's variable-size objects... mean that object accesses require multiple memory access instructions in some cases."

**Key Insight:** WebKit thinks of JavaScript objects as the **only** object model. They don't maintain separate:
- "Infra list" vs "JS Array"
- "Infra map" vs "JS Object"

Instead, `JSArray` **is** how they implement Infra lists when those lists are exposed to JavaScript.

#### V8's Type System

V8's `Object` hierarchy (from source code analysis):
```
Object (tagged pointer)
  ├── Smi (small integer, immediate)
  └── HeapObject (pointer to heap)
      ├── String
      ├── JSObject
      │   ├── JSArray
      │   └── JSFunction
      ├── FixedArray
      └── Map (hidden class)
```

**No parallel "Infra" hierarchy.** The `JSArray` type serves as both:
- A JavaScript array (exposed to script)
- The implementation of Infra "list" (internal concept)

#### Firefox's Approach

SpiderMonkey's `js::Value` is the universal representation:
```cpp
// js/public/Value.h
class Value {
    uint64_t asBits_;  // Tagged representation
    // Can be: double, int32, boolean, undefined, null, string, object, symbol
};
```

**No "Infra Value" type exists.** All WHATWG Infra concepts (list, map, string, etc.) are represented using `JSObject`, `JSString`, etc.

### Why This Matters for Zig Implementation

Browsers prove that **you don't need separate Infra types**. The Infra spec is a **specification tool** for describing algorithms, not a **runtime data structure requirement**.

For a Zig implementation:
- ✅ Can use `std.ArrayList(T)` directly as "Infra list"
- ✅ Can use `OrderedMap(K, V)` directly as "Infra ordered map"
- ✅ Can use `[]const u8` directly as "Infra byte sequence"
- ✅ Can use `[]const u16` directly as "Infra string"
- ❌ Do NOT need separate `InfraValue` union type

The **boundary is conceptual**, not implemented.

---

## 5. Architectural Insights

### Insight 1: **The WHATWG Infra Spec Is a Pedagogical Tool**

The Infra spec exists to:
1. **Define precise semantics** for operations (e.g., "what does it mean to append to a list?")
2. **Provide a common vocabulary** across WHATWG specs (URL, Fetch, DOM, HTML)
3. **Avoid reinventing data structures** in every spec

But it does **not** require implementations to have a distinct "Infra layer."

### Insight 2: **Browsers Optimize Through Unified Representations**

All three browsers converged on the same design:
- **One tagged pointer type** (`JSValue`, `Object`, `JS::Value`)
- **One object model** that serves both JS and internal needs
- **Direct conversion** from JSON to JS values without intermediate steps

This design is faster because:
- No marshaling overhead between Infra and JS layers
- Fewer allocations (no intermediate Infra objects)
- JIT can optimize through the entire stack

### Insight 3: **Type Safety Is in the Spec, Not the Types**

Browsers rely on the **WHATWG Infra specification** to define correct behavior, not on static types in C++. For example:

**Infra spec says:**
> "A list is an ordered collection of items."

**Browser implementation:**
```cpp
// WebKit
JSArray* list = JSArray::create(vm, structure);
```

The `JSArray` **is** the list. No separate `InfraList` wrapper.

Type safety comes from:
1. Following spec algorithms exactly
2. Comprehensive testing against spec requirements
3. Web Platform Tests (WPT) that validate behavior

### Insight 4: **JSON Is a Special Case of Low-Level Serialization**

JSON operations in browsers are **highly optimized** because they're so common:
- **Fast paths** for ASCII strings (WebKit `fastStringify`)
- **Inline caching** for property access during stringification
- **Specialized parsers** (V8's `JsonParser<Char>` template)

But the optimization is at the **algorithm level**, not by introducing an Infra layer.

---

## 6. Implications for Zig WHATWG Infra Implementation

### Recommendation 1: **No Separate Infra Value Type**

Do **NOT** create:
```zig
pub const InfraValue = union(enum) {
    list: InfraList,
    map: InfraMap,
    string: InfraString,
    number: f64,
    boolean: bool,
    null: void,
};
```

Instead, use Zig types directly:
```zig
// Infra "list" → std.ArrayList(T)
// Infra "ordered map" → OrderedMap(K, V)
// Infra "string" → []const u16
// Infra "byte sequence" → []const u8
```

### Recommendation 2: **JSON Operations Work on Infra Types Directly**

```zig
// JSON parsing
pub fn parseJsonStringToInfraValue(
    allocator: Allocator,
    json: []const u8
) !InfraValue {
    // Parse JSON and construct InfraValue directly
    // No intermediate "JavaScript value" representation
}

// JSON serialization
pub fn serializeInfraValueToJsonString(
    allocator: Allocator,
    value: InfraValue
) ![]const u8 {
    // Serialize InfraValue directly to JSON
}
```

Where `InfraValue` is just:
```zig
pub const InfraValue = union(enum) {
    list: std.ArrayList(InfraValue),  // Recursive
    map: OrderedMap([]const u16, InfraValue),
    string: []const u16,
    number: f64,
    boolean: bool,
    null: void,
};
```

This is **sufficient** for JSON operations. No need for "JavaScript value" as a separate concept.

### Recommendation 3: **Expose Infra Types to Language Bindings**

If you later want to expose Infra primitives to JavaScript (via a JIT or interpreter):

```zig
// Hypothetical future JavaScript engine binding
pub fn infraValueToJsValue(infra: InfraValue) JsValue {
    return switch (infra) {
        .list => |lst| JsValue{ .array = lst },
        .map => |m| JsValue{ .object = m },
        .string => |s| JsValue{ .string = s },
        // ...
    };
}
```

But this is **optional** and **not required by the WHATWG Infra spec**.

### Recommendation 4: **Follow Browser Optimization Patterns**

Browsers show that the fast path is:
1. **ASCII fast path** for strings (WebKit `fastStringify`)
2. **Small object optimization** for maps/arrays
3. **Inline caching** for repeated operations

Apply these at the **algorithm level** in `json.zig`, not by introducing layers.

---

## 7. Comparison Table

| Aspect | WebKit (JSC) | Chrome (V8) | Firefox (SpiderMonkey) | Zig Infra (Recommended) |
|--------|-------------|-------------|------------------------|------------------------|
| **Unified Value Type** | `JSValue` | `Object` | `JS::Value` | `InfraValue` (union) |
| **List Representation** | `JSArray` | `JSArray` | `ArrayObject` | `std.ArrayList(T)` |
| **Map Representation** | `JSObject` + `Structure` | `JSObject` + `Map` | `NativeObject` + `Shape` | `OrderedMap(K, V)` |
| **String Representation** | `JSString` (UTF-16) | `String` (UTF-16) | `JSString` (UTF-16) | `[]const u16` |
| **Separate Infra Layer?** | ❌ No | ❌ No | ❌ No | ❌ No |
| **JSON → JS Conversion** | Direct (one step) | Direct (one step) | Direct (one step) | Direct (one step) |
| **Boundary Type** | None (merged) | None (merged) | None (merged) | None (merged) |

---

## 8. Code Examples from Browsers

### WebKit: JSON Parsing (JSONObject.cpp)

```cpp
JSValue JSONParse(JSGlobalObject* globalObject, StringView json) {
    LiteralParser<CharType> jsonParser(globalObject, jsonString, StrictJSON);
    
    JSValue result = jsonParser.tryLiteralParse();
    // result is already JSValue (JS object, array, string, number, boolean, null)
    
    return result;
}
```

**No Infra intermediate.** Directly produces `JSValue`.

### V8: JSON Parsing (json-parser.cc)

```cpp
template <typename Char>
MaybeHandle<Object> JsonParser<Char>::ParseJsonValue() {
    JsonToken token = Next();
    switch (token) {
        case JsonToken::STRING:
            return MakeString(ScanJsonString<false>());  // Returns Handle<String>
        case JsonToken::NUMBER:
            return MakeNumber(ParseJsonNumber());        // Returns Handle<Number>
        case JsonToken::LBRACE:
            return ParseJsonObject();                    // Returns Handle<JSObject>
        case JsonToken::LBRACK:
            return ParseJsonArray();                     // Returns Handle<JSArray>
        case JsonToken::TRUE_LITERAL:
            return factory()->true_value();              // Returns Handle<Boolean>
        case JsonToken::FALSE_LITERAL:
            return factory()->false_value();
        case JsonToken::NULL_LITERAL:
            return factory()->null_value();
        default:
            return ReportUnexpectedToken(token);
    }
}
```

**No Infra values.** All return types are V8 `Object` handles.

### Firefox: JSON Stringification (JSON.cpp)

```cpp
bool Stringifier::Str(HandleValue v, HandleValue key, MutableHandleValue vp, 
                      StringifySession* session) {
    // Handle different JS value types directly
    if (v.isObject()) {
        RootedObject obj(cx, &v.toObject());
        return HandleObject(obj, key, vp, session);
    }
    if (v.isString()) {
        return Quote(v.toString(), sb);
    }
    if (v.isNumber()) {
        return NumberToJSON(cx, v.toNumber(), sb);
    }
    // ...
}
```

**Operates on `JS::Value` directly.** No conversion to Infra types.

---

## 9. Conclusion

### Key Takeaways

1. **Browsers do NOT separate Infra primitives from JavaScript values.** They use a unified representation (tagged pointer).

2. **The WHATWG Infra spec is a conceptual model**, not a runtime architecture requirement.

3. **JSON operations are direct:** `String → JSValue` and `JSValue → String`, without an Infra intermediate layer.

4. **For Zig implementation:** Use Zig types directly (`std.ArrayList`, `OrderedMap`, `[]const u16`). Do not create separate "Infra value" and "JavaScript value" types unless you're building a full JS engine.

5. **The "boundary" is an illusion.** What the spec calls "Infra list" is what browsers implement as `JSArray`. The distinction only exists in specification documents, not in code.

### Recommendation for zig-whatwg/infra

**Do:**
- ✅ Implement Infra primitives as Zig types (ArrayList, OrderedMap, slices)
- ✅ Make JSON operations work directly on these types
- ✅ Follow browser optimization patterns (ASCII fast path, inline caching ideas)
- ✅ Test against WHATWG Infra spec requirements and WPT

**Don't:**
- ❌ Create separate "Infra value" vs "JavaScript value" type hierarchies
- ❌ Add marshaling layers between Infra and JS
- ❌ Over-engineer for a "boundary" that browsers don't implement

### Next Steps

1. **Implement JSON parsing/serialization directly on Infra types** (issue infra-5)
2. **Optimize JSON fast paths** using browser techniques (issue infra-6)
3. **Write comprehensive tests** against WHATWG Infra JSON algorithms
4. **Document that Infra types ARE the public API** — no separate JS value layer needed

---

## References

1. **WHATWG Infra Standard** — https://infra.spec.whatwg.org/
2. **WebKit Blog: Concurrent JavaScript** — https://webkit.org/blog/7846/concurrent-javascript-it-can-work/
3. **V8 Blog: Fast Async** — https://v8.dev/blog/fast-async
4. **WebKit JSONObject Source** — https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/runtime/JSONObject.cpp
5. **V8 JSON Parser Source** — https://github.com/v8/v8/blob/main/src/json/json-parser.cc
6. **Firefox JSON Source** — https://github.com/mozilla/gecko-dev/blob/master/js/src/builtin/JSON.cpp
