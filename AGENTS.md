We track work in Beads instead of Markdown. Run \`bd quickstart\` to see how.

# Agent Guidelines for WHATWG Infra Implementation in Zig

## ⚠️ CRITICAL: Ask Clarifying Questions When Unclear

**ALWAYS ask clarifying questions when requirements are ambiguous or unclear.**

### Question-Asking Protocol

When you receive a request that is:
- Ambiguous or has multiple interpretations
- Missing key details needed for implementation
- Unclear about expected behavior or scope
- Could be understood in different ways

**YOU MUST**:
1. ✅ **Ask ONE clarifying question at a time**
2. ✅ **Wait for the answer before proceeding**
3. ✅ **Continue asking questions until you have complete understanding**
4. ✅ **Never make assumptions when you can ask**

### Examples of When to Ask

❓ **Ambiguous request**: "Implement list operations"
- **Ask**: "Should this include just append/prepend, or also remove and contains?"

❓ **Missing details**: "Add string operations"
- **Ask**: "Should this handle ASCII operations only, or full Unicode string processing?"

❓ **Unclear scope**: "Optimize collection operations"
- **Ask**: "Which operations should be prioritized? List append, map lookup, or set contains?"

❓ **Multiple interpretations**: "Handle JSON parsing"
- **Ask**: "Should this support streaming JSON parsing, or only parse complete strings?"

### What NOT to Do

❌ **Don't make assumptions and implement something that might be wrong**
❌ **Don't ask multiple questions in one message** (ask one, wait for answer, then ask next)
❌ **Don't proceed with unclear requirements** hoping you guessed correctly
❌ **Don't over-explain options** in the question (keep questions concise)

### Good Question Pattern

```
"I want to make sure I understand correctly: [restate what you think they mean].

Is that correct, or did you mean [alternative interpretation]?"
```

**Remember**: It's better to ask and get it right than to implement the wrong thing quickly.

---

## ⚠️ CRITICAL: Spec-Compliant Infra Primitives

**THIS IS A WHATWG INFRA SPECIFICATION LIBRARY** implementing foundational data structures and algorithms.

### What WHATWG Infra IS

The WHATWG Infra Standard defines **foundational primitives for all web specifications**:

1. **Data Structures** - Lists, ordered maps, ordered sets, stacks, queues
2. **Strings** - Code points, ASCII operations, UTF-16 encoding
3. **Bytes** - Byte sequences and operations
4. **JSON** - Parsing and serialization with Infra values
5. **Base64** - Forgiving encoding and decoding
6. **Namespaces** - Common namespace URIs (HTML, SVG, MathML, XML)

### What Infra is NOT

❌ **NOT domain-specific** - Provides primitives, not application logic
❌ **NOT an HTTP client** - Just data structures and algorithms
❌ **NOT a DOM library** - Foundation that DOM depends on
❌ **NOT a file system library** - Focused on web primitives

### Scope

✅ **ONLY implement**: Data structures, string operations, encoding, JSON, base64 per WHATWG Infra spec
✅ **Spec compliance critical**: All other WHATWG specs (URL, DOM, Fetch, HTML) depend on precise Infra behavior
✅ **Test against spec**: Comprehensive unit testing of all primitives

### Test Guidelines

- Use simple, clear examples: lists, maps, strings, code points
- Test edge cases: empty collections, boundary conditions, invalid input
- Focus on spec compliance: every algorithm step must match

**Example Test**:
```zig
test "list append - adds item to end" {
    const allocator = std.testing.allocator;
    
    var list = std.ArrayList(u32).init(allocator);
    defer list.deinit();
    
    try list.append(10);
    try list.append(20);
    
    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    try std.testing.expectEqual(@as(u32, 10), list.items[0]);
    try std.testing.expectEqual(@as(u32, 20), list.items[1]);
}
```

---

This project uses **Agent Skills** for specialized knowledge areas. Skills are automatically loaded when relevant to your task.

## WHATWG Specifications

The complete WHATWG Infra Standard specification is available in:
- `specs/infra.md` - Complete Infra Standard specification (optimized markdown)

**Always load complete spec sections** from this file into context when implementing Infra primitives. Never rely on grep fragments - every algorithm has context and edge cases that matter.

### Infra is Self-Contained

The WHATWG Infra Standard has **no external WHATWG spec dependencies**. Infra is the foundation that other specifications (URL, DOM, Fetch, HTML, etc.) depend on.

## Memory Management for Infra Primitives

Infra types use standard Zig allocation patterns - allocate for collections and strings, deinit when done.

### Standard Allocation Pattern

```zig
// Lists use ArrayList
var list = std.ArrayList(u8).init(allocator);
defer list.deinit();

try list.append(42);

// Maps use custom OrderedMap (preserves insertion order)
var map = OrderedMap([]const u8, u32).init(allocator);
defer map.deinit();

try map.set("key", 100);

// Strings are just slices
const string: []const u8 = "hello";
```

### Arena Allocation for Temporary Work

```zig
// For algorithms that build intermediate data structures
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const temp_allocator = arena.allocator();

// Build temporary structures
const temp_list = std.ArrayList(u8).init(temp_allocator);
const result = try processData(temp_allocator, input);

// Everything freed at once when arena.deinit() is called
```

### Memory Safety

- **Always use `defer`** for cleanup
- **Always test with `std.testing.allocator`** to detect leaks
- **No reference counting** - primitives are values, not objects
- **No global state** - everything takes an allocator

---

## Available Skills

Claude automatically loads skills when relevant to your task. You don't need to manually select them.

### 1. **whatwg_spec** - WHATWG Specification Reference ⭐

**Automatically loaded when:**
- Implementing Infra primitives from WHATWG spec
- Looking up specific algorithm steps or edge cases
- Verifying list, map, or set operations
- Understanding string operations (ASCII, code points, whitespace)
- Checking JSON or base64 algorithms
- Resolving ambiguities in specification language

**Provides:**
- Direct references to `specs/infra.md` in this project
- Guidance on loading complete spec sections (never fragments)
- Common algorithm locations and search patterns
- Spec terminology and reading best practices
- Integration with other skills (whatwg_compliance, zig_standards, testing)

**Key Files**:
- `specs/infra.md` - Complete WHATWG Infra Standard (optimized markdown)

**Critical Rule**: Always load complete spec sections into context. Never rely on grep fragments.

**Location:** `skills/whatwg_spec/`

### 2. **whatwg_compliance** - Specification to Zig Mapping

**Automatically loaded when:**
- Mapping WHATWG spec algorithms to Zig types
- Understanding how to implement spec concepts in Zig
- Need examples of spec-compliant Zig implementations

**Provides:**
- Type mapping from WHATWG Infra spec to Zig (list → ArrayList, ordered map → OrderedMap, string → []const u16, code point → u21)
- Complete Infra implementation examples with numbered steps matching spec
- Documentation patterns with Infra spec references
- Memory management patterns for Infra primitives
- How to implement lists, maps, sets, strings, JSON, base64 correctly

**Works with**: `whatwg_spec` skill (read spec first, then map to Zig)

**Location:** `skills/whatwg_compliance/`

### 3. **zig_standards** - Zig Programming Patterns

**Automatically loaded when:**
- Writing or refactoring Zig code
- Implementing algorithms
- Managing memory with allocators
- Handling errors

**Provides:**
- Naming conventions and code style
- Error handling patterns
- Memory management patterns (allocator, arena, defer)
- Type safety best practices
- Comptime programming patterns

**Location:** `skills/zig_standards/`

### 4. **testing_requirements** - Test Standards

**Automatically loaded when:**
- Writing tests
- Ensuring test coverage
- Verifying memory safety (no leaks)
- Implementing TDD workflows

**Provides:**
- Test coverage requirements (happy path, edge cases, errors, memory)
- Memory leak testing with `std.testing.allocator`
- Test organization patterns
- TDD workflow

**Location:** `skills/testing_requirements/`

### 5. **performance_optimization** - Infra Performance

**Automatically loaded when:**
- Optimizing Infra primitives
- Working on hot paths
- Minimizing allocations

**Provides:**
- Fast paths for common cases (ASCII strings, small collections)
- Allocation minimization patterns
- String operation optimization
- JSON parsing optimization
- Base64 encoding/decoding optimization

**Location:** `skills/performance_optimization/`

### 6. **documentation_standards** - Documentation Format

**Automatically loaded when:**
- Writing inline documentation
- Updating README.md or CHANGELOG.md
- Documenting design decisions
- Creating completion reports

**Provides:**
- Comprehensive module-level documentation format (`//!`)
- Function and type documentation patterns (`///`)
- Infra spec reference format
- Complete usage examples and common patterns
- README.md update workflow
- CHANGELOG.md format (Keep a Changelog 1.1.0)

**Location:** `skills/documentation_standards/`

### 7. **communication_protocol** - Clarifying Questions ⭐

**ALWAYS ACTIVE** - Applies to every interaction and task.

**Core Principle:**
When requirements are ambiguous, unclear, or could be interpreted multiple ways, **ALWAYS ask clarifying questions** before proceeding.

**Provides:**
- Question-asking protocol (one question at a time)
- When to ask vs. when to proceed
- Question patterns and examples
- Anti-patterns to avoid (assuming, option overload, paralysis)
- Decision tree for "should I ask?"

**Critical Rule:** Ask ONE clarifying question at a time. Wait for answer. Repeat until understanding is complete.

**Location:** `skills/communication_protocol/`

### 8. **browser_benchmarking** - Infra Benchmarking Strategies

**Automatically loaded when:**
- Benchmarking Infra primitive performance
- Comparing against browser implementations
- Identifying Infra optimization opportunities
- Measuring performance regressions

**Provides:**
- How to benchmark Infra primitives against browsers (Chrome, Firefox, Safari)
- Infra-specific optimization patterns (character classification tables, small collection fast paths, ASCII string fast paths)
- Performance targets based on browser implementations (WTF::Vector, WTF::String, mozilla::Vector)
- Real-world primitive operation testing strategies
- Microbenchmark and macrobenchmark patterns

**Key Optimizations:**
- Character classification lookup tables
- Fast path for ASCII-only strings
- Small collection fast paths (linear search for small lists/maps)
- String operation capacity hints
- Base64 lookup tables

**Location:** `skills/browser_benchmarking/`

### 9. **pre_commit_checks** - Automated Quality Checks

**Automatically loaded when:**
- Preparing to commit code
- Running pre-commit hooks
- Ensuring code quality before push

**Provides:**
- Pre-commit hook workflow (format, build, test)
- How to handle pre-commit failures
- Integration with development tools (VS Code, Vim, Emacs)
- Performance considerations for pre-commit checks

**Core Checks:**
1. ✅ Code formatting (`zig fmt --check`)
2. ✅ Build success (`zig build`)
3. ✅ Test success (`zig build test`)

**Critical Rule**: Never commit unformatted, broken, or untested code.

**Location:** `skills/pre_commit_checks/`

### 10. **beads_workflow** - Task Tracking with bd ⭐

**ALWAYS use bd for ALL task tracking** - No markdown TODOs or external trackers.

**Automatically loaded when:**
- Managing tasks and issues
- Tracking work progress
- Creating new issues
- Checking what to work on next

**Provides:**
- Complete bd (beads) workflow for issue tracking
- How to create, claim, update, and close issues
- Dependency tracking with `discovered-from` links
- Auto-sync with git (`.beads/issues.jsonl`)
- MCP server integration for Claude Desktop

**Core Commands:**
- `bd ready --json` - Check ready work
- `bd create "Title" -t bug|feature|task -p 0-4 --json` - Create issue
- `bd update bd-N --status in_progress --json` - Claim issue
- `bd close bd-N --reason "Done" --json` - Complete work

**Critical Rules:**
- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag
- ✅ Link discovered work with `discovered-from`
- ✅ Commit `.beads/issues.jsonl` with code
- ❌ NEVER use markdown TODO lists

**Location:** `skills/beads_workflow/`

---

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers

For complete details, see `skills/beads_workflow/SKILL.md`.

---

## Golden Rules

These apply to ALL work on this project:

### 0. **Ask When Unclear** ⭐
When requirements are ambiguous or unclear, **ASK CLARIFYING QUESTIONS** before proceeding. One question at a time. Wait for answer. Never assume.

### 1. **Complete Spec Understanding**
Load the complete WHATWG Infra specification from `specs/infra.md` into context. Read the full algorithm sections with proper context. Never rely on grep fragments - every algorithm has context and edge cases.

### 2. **Algorithm Precision**
Infra primitives are foundational for all web specifications. Implement EXACTLY as specified, step by step. Even small deviations can break compatibility with browsers that depend on Infra.

### 3. **Memory Safety**
Zero leaks, proper cleanup with defer, test with `std.testing.allocator`. No exceptions.

### 4. **Test First**
Write tests before implementation. Comprehensive unit testing for all primitives against spec requirements.

### 5. **Browser Compatibility**
Infra primitives must match browser behavior. Test against edge cases and boundary conditions. When in doubt, check how browser implementations (Chromium WTF, Firefox mozilla) handle it.

### 6. **Performance Matters** (but spec compliance comes first)
Infra primitives are used extensively by other specs (URL, DOM, Fetch). Optimize for speed and low allocation. But never sacrifice correctness for speed.

### 7. **Use bd for Task Tracking** ⭐
All tasks, bugs, and features tracked in bd (beads). Always use `bd ready --json` to check for work. Link discovered issues with `discovered-from`. Never use markdown TODOs.

---

## Critical Project Context

### What Makes Infra Special

1. **Foundation for All WHATWG Specs** - URL, DOM, Fetch, HTML all depend on Infra
2. **Browser Compatibility** - Must match Chrome, Firefox, Safari primitive implementations
3. **Spec Compliance Critical** - Bugs in Infra cascade to every dependent specification
4. **Used Everywhere** - Every web standard operation uses Infra primitives (lists, maps, strings)

### Code Quality

- Production-ready codebase
- Zero tolerance for memory leaks
- Zero tolerance for breaking changes without major version
- Zero tolerance for untested code
- Zero tolerance for missing or incomplete documentation
- Zero tolerance for deviating from Infra spec

### Workflow (New Features)

1. **Check bd for issue** - `bd ready --json` or create new issue if needed
2. **Claim the issue** - `bd update bd-N --status in_progress --json`
3. **Read Infra spec** - Load `specs/infra.md` and read the complete algorithm/component section
4. **Understand full algorithm** - Read all steps with context, dependencies, and edge cases
5. **Map to Zig types** - Use Zig idioms from `zig_standards` skill
6. **Write tests first** - Test all algorithm steps and edge cases
7. **Implement precisely** - Follow spec steps exactly, numbered comments
8. **Verify** - No leaks, all tests pass, pre-commit checks pass
9. **Document** - Inline docs with Infra spec references
10. **Update CHANGELOG.md** - Document what was added
11. **Close issue** - `bd close bd-N --reason "Implemented" --json`

### Workflow (Bug Fixes)

1. **Check bd for issue** - or create: `bd create "Bug: ..." -t bug -p 1 --json`
2. **Claim the issue** - `bd update bd-N --status in_progress --json`
3. **Write failing test** that reproduces the bug
4. **Read spec** - Load `specs/infra.md` to verify what spec says should happen
5. **Fix the bug** with minimal code change
6. **Verify** all tests pass (including new test), pre-commit checks pass
7. **Update** CHANGELOG.md if user-visible
8. **Close issue** - `bd close bd-N --reason "Fixed" --json`

---

## Memory Tool Usage

Use Claude's memory tool to persist knowledge across sessions:

**Store in memory:**
- Completed Infra features with implementation dates
- Design decisions and architectural rationale
- Performance optimization notes
- Complex spec interpretation notes
- Known gotchas and edge cases

**Memory directory structure:**
```
memory/
├── completed_features.json
├── design_decisions.md
└── spec_interpretations.md
```

---

## Quick Reference

### Infra Primitives (WHATWG Infra Standard)

| Primitive | Zig Type | Notes |
|-----------|----------|-------|
| `list` | `std.ArrayList(T)` | Ordered collection, allows duplicates |
| `ordered map` | `OrderedMap(K, V)` | Key-value pairs, preserves insertion order |
| `ordered set` | `OrderedSet(T)` | Unique items, preserves insertion order |
| `string` | `[]const u16` | UTF-16 code units (matches web platform) |
| `code point` | `u21` | Unicode code point (U+0000 to U+10FFFF) |
| `byte` | `u8` | Single octet (0-255) |
| `byte sequence` | `[]const u8` | Sequence of bytes |

### Common Infra Operations

```zig
// List operations (Infra §5.1)
var list = std.ArrayList(u32).init(allocator);
defer list.deinit();
try list.append(10);
try list.append(20);

// Ordered map operations (Infra §5.2)
var map = OrderedMap([]const u8, u32).init(allocator);
defer map.deinit();
try map.set("key", 100);
const value = map.get("key"); // Returns ?u32

// String operations (Infra §4)
const lowercase = try asciiLowercase(allocator, "HELLO");
defer allocator.free(lowercase);

// JSON parsing (Infra §6)
const json = "{\"key\": \"value\"}";
const value = try parseJsonStringToInfraValue(allocator, json);
defer value.deinit(allocator);

// Base64 (Infra §7)
const encoded = try forgivingBase64Encode(allocator, data);
defer allocator.free(encoded);
```

### Common Errors

```zig
pub const InfraError = error{
    // Parsing errors
    InvalidJson,
    InvalidBase64,
    InvalidCodePoint,
    InvalidUtf8,
    
    // Collection errors
    IndexOutOfBounds,
    KeyNotFound,
    EmptyList,
    
    // String errors
    InvalidCharacter,
    StringTooLong,
    
    // Memory errors
    OutOfMemory,
};
```

---

## File Organization

```
skills/
├── whatwg_spec/             # ⭐ WHATWG spec reference (specs/infra.md)
├── whatwg_compliance/       # Infra spec to Zig type mapping and patterns
├── communication_protocol/  # ⭐ Ask clarifying questions when unclear
├── zig_standards/           # Zig idioms, memory patterns, errors
├── testing_requirements/    # Test patterns, coverage, TDD
├── performance_optimization/# General Zig optimization patterns
├── documentation_standards/ # Doc format, CHANGELOG, README
├── browser_benchmarking/    # Infra benchmarking strategies and optimizations
├── pre_commit_checks/       # Automated quality checks (format, build, test)
└── beads_workflow/          # ⭐ Task tracking with bd (beads)

specs/
└── infra.md                 # Complete WHATWG Infra Standard (optimized markdown)

.beads/
└── issues.jsonl             # Beads issue tracking database (git-versioned)

memory/                      # Persistent knowledge (memory tool)
├── completed_features.json
├── design_decisions.md
└── spec_interpretations.md

tests/
└── unit/                    # Unit tests for Infra primitives

src/                         # Source code
├── list.zig                 # List operations
├── map.zig                  # Ordered map operations
├── set.zig                  # Ordered set operations
├── string.zig               # String operations
├── code_point.zig           # Code point operations
├── bytes.zig                # Byte sequence operations
├── json.zig                 # JSON parsing and serialization
├── base64.zig               # Base64 encoding/decoding
├── namespaces.zig           # Namespace URIs
└── ...

Root:
├── CHANGELOG.md
├── CONTRIBUTING.md
├── AGENTS.md (this file)
└── ... (build files)
```

---

## Zero Tolerance For

- Memory leaks (test with `std.testing.allocator`)
- Breaking changes without major version bump
- Untested code
- Missing documentation
- Undocumented CHANGELOG entries
- **Deviating from Infra spec algorithms**
- **Browser incompatibility** (test against browser primitive implementations)
- **Missing spec references** (must cite Infra spec section)

---

## When in Doubt

1. **ASK A CLARIFYING QUESTION** ⭐ - Don't assume, just ask (one question at a time)
2. **Check bd for existing issues** - `bd ready --json` - See if work is already tracked
3. **Read the WHATWG spec** - Load `specs/infra.md` for accurate algorithm details
4. **Read the complete section** - Context matters, never rely on fragments
5. **Load relevant skills** - Get specialized guidance
6. **Look at existing tests** - See patterns
7. **Follow the Golden Rules** - Especially algorithm precision

---

## Infra Standard Reference

**Official Spec**: https://infra.spec.whatwg.org/

**Key Sections**:
- §1-3 Primitives - Bytes, code points, strings
- §4 Strings - ASCII operations, whitespace, code points
- §5 Data structures - Lists, ordered maps, ordered sets, stacks, queues
- §6 JavaScript - JSON parsing and serialization
- §7 Base64 - Forgiving encoding and decoding
- §8 Namespaces - HTML, SVG, MathML, XML namespace URIs

**Reading Guide**:
1. Read the section introduction (context)
2. Read all algorithm steps (don't skip)
3. Check cross-references (other sections)
4. Understand why, not just what

---

**Quality over speed.** Take time to do it right. The codebase is production-ready and must stay that way.

**Skills provide the details.** This file coordinates. Load skills for deep expertise.

**Infra is the foundation.** All other WHATWG specs depend on it being correct. Precision matters.

**Thank you for maintaining the high quality standards of this project!** 🎉
