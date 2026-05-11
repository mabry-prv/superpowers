# Fixture: small spec — slugify utility

## Goal

Add a `slugify(s: str) -> str` helper that lowercases input and replaces non-alphanumeric runs with single hyphens, trimming hyphens from the ends.

## File Structure

- `lib/slugify.py` — single function `slugify`
- `tests/test_slugify.py` — unit tests

## Acceptance criteria

- `slugify("Hello World")` → `"hello-world"`
- `slugify("  foo--bar  ")` → `"foo-bar"`
- `slugify("a/b/c")` → `"a-b-c"`
- `slugify("")` → `""`

## EXPECTED PLAN SHAPE

A 2-3 task plan: (1) write failing tests, (2) implement minimal slugify, (3) commit. Each task has Files block, numbered steps with code, expected output. No placeholders.
