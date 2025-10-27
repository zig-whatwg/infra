# Contributing to WHATWG Infra for Zig

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Development Setup

### Prerequisites

- Zig 0.15.1 or later
- Git

### Getting Started

```bash
git clone https://github.com/zig-js/whatwg-infra
cd whatwg-infra
zig build test
```

## Development Workflow

### 1. Before Making Changes

- Read the [WHATWG Infra specification](https://infra.spec.whatwg.org/)
- Check existing issues and pull requests
- Review [DESIGN_DECISIONS.md](./analysis/DESIGN_DECISIONS.md) for architectural patterns

### 2. Making Changes

#### Code Style

- Follow Zig standard library conventions
- Use explicit allocators (never global state)
- Write comprehensive inline documentation with spec references
- Keep functions focused and well-named

Example:

```zig
/// ASCII lowercase (WHATWG Infra §4.7)
/// 
/// Spec: https://infra.spec.whatwg.org/#ascii-lowercase
/// 
/// Converts ASCII uppercase letters to lowercase. Non-ASCII characters
/// are preserved unchanged.
/// 
/// Caller owns returned string, must free with allocator.free()
pub fn asciiLowercase(allocator: Allocator, string: String) !String {
    // Implementation with numbered comments matching spec steps
}
```

#### Testing

**Every change must include tests.** Use TDD (Test-Driven Development):

1. Write failing test
2. Implement feature
3. Verify test passes
4. Check for memory leaks with `std.testing.allocator`

Test coverage requirements:
- ✅ **Happy path**: Normal usage
- ✅ **Edge cases**: Empty input, boundary values, large input
- ✅ **Error cases**: Invalid input, out of bounds
- ✅ **Memory safety**: Zero leaks

Example:

```zig
test "asciiLowercase - ASCII uppercase" {
    const allocator = std.testing.allocator;
    const input = [_]u16{ 'H', 'E', 'L', 'L', 'O' };
    const result = try asciiLowercase(allocator, &input);
    defer allocator.free(result);

    const expected = [_]u16{ 'h', 'e', 'l', 'l', 'o' };
    try std.testing.expectEqualSlices(u16, &expected, result);
}
```

### 3. Running Tests

```bash
# Run all tests
zig build test

# Run with summary
zig build test --summary all
```

All tests must pass before submitting a PR.

### 4. Documentation

- Update inline documentation (//! and ///)
- Add CHANGELOG.md entry
- Update README.md if adding new features
- Reference WHATWG Infra spec sections

### 5. Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Pull Request Guidelines

### PR Title Format

Use conventional commit style:

- `feat: Add JSON parsing support`
- `fix: Handle unpaired surrogates in UTF-16`
- `docs: Update API reference`
- `test: Add tests for OrderedMap`
- `refactor: Simplify Base64 decoding`

### PR Description

Include:

1. **What**: Brief description of changes
2. **Why**: Motivation and context
3. **Spec**: Link to relevant WHATWG Infra sections
4. **Testing**: How you tested the changes
5. **Breaking**: Note any breaking changes

Example:

```markdown
## What

Adds forgiving Base64 decode operation.

## Why

Required by WHATWG Infra §7 for decoding Base64 with whitespace.

## Spec

https://infra.spec.whatwg.org/#forgiving-base64-decode

## Testing

- 13 tests covering encode, decode, roundtrip, whitespace handling
- All tests pass with zero memory leaks

## Breaking Changes

None
```

## Code Review Process

1. Maintainer reviews code
2. Address feedback if any
3. Maintainer approves and merges

## Commit Guidelines

- Keep commits focused and atomic
- Write clear commit messages
- Reference issues/specs in commit body

Good commit message:

```
feat: Add forgiving Base64 decode

Implements WHATWG Infra §7 forgiving Base64 decode algorithm.
Strips ASCII whitespace before decoding.

Spec: https://infra.spec.whatwg.org/#forgiving-base64-decode
Fixes #42
```

## Quality Standards

### Zero Tolerance For

- ❌ Memory leaks
- ❌ Breaking changes without major version bump
- ❌ Untested code
- ❌ Missing documentation
- ❌ Deviating from WHATWG Infra spec

### Must Have

- ✅ Spec compliance
- ✅ Zero memory leaks (verified with `std.testing.allocator`)
- ✅ Comprehensive tests (happy path, edge cases, errors)
- ✅ Inline documentation with spec references
- ✅ CHANGELOG.md entry

## Project Structure

```
src/
├── string.zig          # String operations (§4.7)
├── code_point.zig      # Code point predicates (§4.6)
├── bytes.zig           # Byte sequences (§4.5)
├── list.zig            # List operations (§5.1)
├── map.zig             # OrderedMap (§5.2)
├── set.zig             # OrderedSet (§5.1.3)
├── stack.zig           # Stack (§5.3)
├── queue.zig           # Queue (§5.4)
├── struct.zig          # Struct (§5.5)
├── tuple.zig           # Tuple (§5.6)
├── json.zig            # JSON (§6)
├── base64.zig          # Base64 (§7)
├── namespaces.zig      # Namespaces (§8)
└── root.zig            # Unified API

tests/
└── unit/               # Unit tests for all modules

analysis/               # Design documents
├── DESIGN_DECISIONS.md
├── IMPLEMENTATION_PLAN.md
└── ...
```

## Design Principles

1. **Spec Compliance First**: Never deviate from WHATWG Infra
2. **Memory Safety**: Zero leaks, always
3. **Zig Idioms**: Explicit allocators, error handling
4. **Browser Patterns**: Learn from Chromium/Firefox
5. **Simplicity**: Clear, correct code over clever code

## Getting Help

- Open an issue for questions
- Check [AGENTS.md](./AGENTS.md) for development guidelines
- Review existing code for patterns

## Recognition

Contributors will be credited in release notes and README.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
