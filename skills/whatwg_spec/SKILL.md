# WHATWG Specification Reference Skill

## When to use this skill

Load this skill automatically when:
- Implementing Infra primitives from the WHATWG spec
- Looking up specific algorithm steps or sections
- Verifying correct implementation of Infra primitives
- Understanding edge cases in Infra operations
- Resolving ambiguities in specification language

## What this skill provides

This skill directs you to the **authoritative WHATWG Infra specification file** located in this project:

- **`specs/infra.md`** - Complete WHATWG Infra Standard in optimized markdown format

## Infra is Self-Contained

The WHATWG Infra Standard has **no external WHATWG spec dependencies**. Infra provides the foundational primitives that other specifications (URL, DOM, Fetch, HTML, etc.) depend on.

## Critical Rule: Always Load Complete Spec Sections

**NEVER rely on grep fragments or partial algorithm text.**

When implementing any Infra algorithm or primitive:

1. **Load the complete section** from `specs/infra.md` into context
2. **Read the full algorithm** with all steps, context, and cross-references
3. **Check dependencies** - Infra algorithms often reference other sections
4. **Understand edge cases** - The spec documents failure modes and validation errors

## Workflow: Using the WHATWG Spec

### Step 1: Identify the Spec Section

Common sections you'll need:

| Section | Topic | Location in specs/infra.md |
|---------|-------|----------------------------|
| §1-3 | Primitives - Bytes, code points, strings | Search for "## Primitives" |
| §4 | Strings - ASCII operations, whitespace | Search for "## Strings" |
| §5 | Data structures - Lists, maps, sets | Search for "## Data structures" |
| §6 | JavaScript - JSON parsing/serialization | Search for "## JavaScript" |
| §7 | Base64 - Encoding and decoding | Search for "## Base64" |
| §8 | Namespaces - HTML, SVG, MathML | Search for "## Namespaces" |

### Step 2: Load Complete Section into Context

**Read the file** with the `read` tool:

```
read("specs/infra.md", offset=<start_line>, limit=<line_count>)
```

Find the section with `grep`:
```bash
rg -n "## Strings" specs/infra.md
```

Then load the complete section (not just a fragment).

### Step 3: Understand the Algorithm

Infra algorithms are written as numbered steps or prose. Read ALL steps:

**Example** (ASCII lowercase):
```
To ASCII lowercase a string, replace all ASCII upper alphas in the string 
with their corresponding code point in ASCII lower alpha.
```

**Critical**: 
- Follow every step in order
- Check for "return failure" conditions
- Note validation errors (logged but don't stop processing)
- Follow cross-references to other algorithms

## Common Algorithms Reference

### String Operations

**Location**: Search for "ASCII lowercase", "strip newlines" in `specs/infra.md`

**Key algorithms**:
- **ASCII lowercase** - Convert ASCII uppercase to lowercase
- **ASCII uppercase** - Convert ASCII lowercase to uppercase
- **Strip newlines** - Remove U+000A LF and U+000D CR
- **Strip leading/trailing whitespace** - Remove ASCII whitespace
- **Normalize newlines** - Replace CR LF and CR with LF
- **Split on ASCII whitespace** - Split string on whitespace
- **Split on commas** - Split on commas

### List Operations

**Location**: Search for "list", "append", "prepend" in `specs/infra.md`

**Key operations**:
- **Append** - Add item to end of list
- **Prepend** - Add item to beginning of list
- **Extend** - Append all items from another list
- **Insert** - Insert at specific index
- **Remove** - Remove by index or value
- **Contains** - Check if list contains item
- **Sort** - Sort list with comparator

### Ordered Map Operations

**Location**: Search for "ordered map", "map set" in `specs/infra.md`

**Key operations**:
- **Set** - Insert or update entry
- **Get** - Retrieve value by key
- **Remove** - Remove entry by key
- **Contains** - Check if map contains key
- **Keys** - Get list of keys in insertion order
- **Values** - Get list of values in insertion order

### Ordered Set Operations

**Location**: Search for "ordered set" in `specs/infra.md`

**Key operations**:
- **Append** - Add item if not present
- **Prepend** - Add item to beginning if not present
- **Remove** - Remove item from set
- **Contains** - Check if set contains item

### JSON Operations

**Location**: Search for "parse JSON string" in `specs/infra.md`

**Key algorithms**:
- **Parse JSON string to Infra value** - Parse JSON to Infra types
- **Serialize Infra value to JSON** - Convert Infra types to JSON

### Base64 Operations

**Location**: Search for "forgiving-base64" in `specs/infra.md`

**Key algorithms**:
- **Forgiving-base64 decode** - Decode with whitespace stripping
- **Forgiving-base64 encode** - Encode to base64

## Example Workflow

### Implementing List Append

1. **Find the algorithm**:
```bash
rg -n "append" specs/infra.md
```

2. **Load complete section** (example line numbers):
```
read("specs/infra.md", offset=200, limit=100)
```

3. **Read the full algorithm**:
   > To append to a list is to add the given item to the end of the list.

4. **Implement in Zig**, matching spec exactly

5. **Test thoroughly** with unit tests

### Implementing ASCII Lowercase

1. **Find algorithm**:
```bash
rg -n "ASCII lowercase" specs/infra.md
```

2. **Load complete section**

3. **Read algorithm**:
   > To ASCII lowercase a string, replace all ASCII upper alphas in the 
   > string with their corresponding code point in ASCII lower alpha.

4. **Implement step-by-step** in Zig

5. **Test** with ASCII and non-ASCII strings

## Spec Reading Best Practices

### 1. Load Complete Sections

❌ **Don't**: Use grep to extract algorithm fragments
```bash
# BAD - incomplete context
rg "ASCII lowercase" specs/infra.md
```

✅ **Do**: Load the complete algorithm section
```
# GOOD - full context
read("specs/infra.md", offset=<section_start>, limit=<section_length>)
```

### 2. Follow Cross-References

The spec frequently references other sections:

- "For each item in list..." → Understand list iteration
- "ASCII lowercase string" → Load ASCII lowercase algorithm
- "UTF-8 encode" → Check string encoding section

### 3. Understand Prose vs. Algorithmic Steps

Some Infra algorithms are prose:
> To ASCII lowercase a string, replace all ASCII upper alphas...

Others are numbered steps:
> 1. Let result be an empty list.
> 2. For each item in input...

Both styles are spec-compliant - implement exactly as written.

## Integration with Other Skills

### Use with `whatwg_compliance`

- **whatwg_spec** → Locate and read algorithm from `specs/infra.md`
- **whatwg_compliance** → Map spec concepts to Zig types and patterns

### Use with `zig_standards`

- **whatwg_spec** → Understand spec algorithm steps
- **zig_standards** → Implement with Zig idioms (allocators, error handling, defer)

### Use with `testing_requirements`

- **whatwg_spec** → Read algorithm and edge cases
- **testing_requirements** → Write comprehensive tests covering all cases

## Quick Reference

### File Location

| File | Description |
|------|-------------|
| `specs/infra.md` | Complete WHATWG Infra Standard (optimized markdown) |

### Common Searches

```bash
# Find string operations
rg -n "ASCII lowercase" specs/infra.md

# Find list operations
rg -n "append" specs/infra.md

# Find map operations
rg -n "ordered map" specs/infra.md

# Find JSON operations
rg -n "parse JSON string" specs/infra.md

# Find base64 operations
rg -n "forgiving-base64" specs/infra.md
```

### Spec Terminology

| Spec Term | Meaning |
|-----------|---------|
| **code point** | Unicode character (U+0000 to U+10FFFF) |
| **code unit** | 16-bit value in UTF-16 string |
| **byte** | Single octet (0-255) |
| **list** | Ordered collection (allows duplicates) |
| **ordered map** | Key-value pairs (preserves insertion order) |
| **ordered set** | Unique items (preserves insertion order) |
| **ASCII whitespace** | U+0009 TAB, U+000A LF, U+000C FF, U+000D CR, U+0020 SPACE |
| **ASCII alpha** | U+0041-U+005A (A-Z) or U+0061-U+007A (a-z) |

## Remember

1. **Always load complete spec sections** - Never work from fragments
2. **Read specs/infra.md for algorithms** - Authoritative source
3. **Follow all algorithm steps** - Don't skip or assume
4. **Check cross-references** - Infra algorithms may reference each other
5. **Test edge cases** - Spec documents failure modes and edge cases

**The spec is your source of truth. Read it completely and implement it precisely.**
