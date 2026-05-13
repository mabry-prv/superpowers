---
topic: librarian-agents
category: patterns
last-updated: 2026-05-13
last-since: 97def3d
---

# Librarian-family agent conventions

## Entries

### 2026-05-13 — Librarian agents return NEEDS_CONTEXT, never BLOCKED:ARCHITECTURAL (since 97def3d)

The librarian family (`curator`, `reviser`) does NOT have an
architectural-escalation verdict. When a librarian genuinely cannot
proceed (missing per-call field, citation that won't fetch, can't
locate the entry on disk, etc.) it returns
`NEEDS_CONTEXT — <gap-description>`. Surface this contract in two
places per agent: the Report Format section AND the Anti-Patterns DO
NOT list.

**Why:** librarians work on stable, append-only structures (the
`knowledge/` tree). They do not propose changes to the *system* —
only to records of past observations. There is no architectural
decision a librarian could escalate; mis-routing one to the architect
would invent decisions the librarian isn't qualified to make.

**Avoid:** when adding a new librarian-family agent under `agents/`,
do NOT inherit `BLOCKED:ARCHITECTURAL` from the implementer/architect
envelope. The structural test `tests/curator/test-structure.sh:60`
asserts the absence of that escalation path with literal phrasings
`NOT escalate.*BLOCKED:ARCHITECTURAL|never emit…|does NOT emit…` —
mirror one of those literal phrases in the agent body.

**Source:** observed_locally_unvetted

### 2026-05-13 — Dispatcher must verify all N per-call fields before invoking a librarian (since 44d2700)

Every librarian agent declares an exact field count in its Per-Call
Context section: curator = 8, reviser = 5. The dispatching skill MUST
populate every field with a non-empty value before invoking; the
agent's Step 0 verifies the contract and returns NEEDS_CONTEXT on any
gap. EXISTING_INDEX for the curator is the lone exception — empty
string is acceptable on a project's first curator run.

**Why:** librarians produce content that ends up on disk in
`knowledge/`. A missing field would make the agent hallucinate or
guess. The verify-up-front pattern keeps hallucinated entries out of
the knowledge base.

**How:** when adding a new dispatcher invocation, copy the per-call
block from the agent's own Per-Call Context section verbatim and
populate inline. See `skills/finishing-a-development-branch/SKILL.md:54-67`
(curator, 8 fields) and `skills/vetting-knowledge/SKILL.md:166-173`
(reviser, 5 fields) for the canonical recipes.

**Source:** observed_locally_unvetted

### 2026-05-13 — Reviser preserves the dated H3 + since-SHA byte-for-byte (since 97def3d)

When the `reviser` agent rewrites a contradicted entry, it MUST
preserve the H3 header line — date, title, AND `(since <SHA>)` —
exactly as it appears on disk. Only the body of the entry changes;
the observation is still anchored to the SHA that first captured it.
See `agents/reviser.md:39-42` for the contract.

**Why:** `since: <SHA>` documents WHEN the local observation was
made. Rewriting it to "today's HEAD" would falsify the historical
record. The recommendation (e.g. "use pattern X" → "use canonical
pattern Y") moved; the observation didn't.

**Avoid:** if a future revision MUST also update the title (because
the original was misleading), surface that as NEEDS_CONTEXT instead
of editing — the user should adjudicate whether the entry is a
title-rewrite (rare) or a body-rewrite (the reviser's job).

**Source:** observed_locally_unvetted
