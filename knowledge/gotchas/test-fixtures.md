---
topic: test-fixtures
category: gotchas
last-updated: 2026-05-11
last-since: 52c7c83
---

# Test-fixture gotchas

## Entries

### 2026-05-11 — Bad-fixture must actually exceed the threshold it tests (since 6868f02)

`tests/lint-knowledge/fixtures/bad/knowledge/gotchas/oversized.md` was
originally a 184-word lorem-ipsum block intended to trip the
"entry >200 words" warning in `scripts/lint-knowledge.sh`. 184 < 200, so
the lint never fired and the assertion silently passed for the wrong
reason — the fixture had no missing-frontmatter or other defect either,
so the bad-sweep was effectively green on this check.

**Why:** copy-paste lorem ipsum has variable length; nobody counted.
Fixture extended to ~290 words during T-8 follow-up.

**Avoid:** when writing a fixture that exists to violate a numeric
threshold (word count, line count, byte size), assert programmatically
that the fixture's measured value is on the wrong side of the threshold
before committing — or stamp the threshold + actual count in a comment
at the top of the fixture so drift is obvious.

### 2026-05-11 — Curator test regex is literal-phrase-sensitive (since aae076d)

`tests/curator/test-structure.sh:60` matches one of three literal
phrasings to assert the curator does not escalate
`BLOCKED:ARCHITECTURAL`:

```
NOT escalate.*BLOCKED:ARCHITECTURAL|never emit.*BLOCKED:ARCHITECTURAL|does NOT emit.*BLOCKED:ARCHITECTURAL
```

The agent text originally read "librarians does NOT emit" (plural
subject, singular verb). Fixing the grammar to "the curator does NOT
emit" — the natural fix — happens to keep the regex matching only
because both forms contain "does NOT emit".

**Why:** the structural test bakes in surface wording, not semantics.
Any future librarian-family agent that uses different phrasing
("must not emit", "won't escalate") will break this test.

**Avoid:** when editing `agents/*.md` anti-pattern bullets, grep the
matching `tests/*/test-structure.sh` for literal-string assertions and
either keep the phrasing or update both files together.
