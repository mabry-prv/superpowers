# Knowledge Discovery + Vetting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the discovery + vetting layer described in `docs/superpowers/specs/2026-05-12-knowledge-discovery-and-vetting-design.md` — a discovery skill every plugin agent self-invokes, a `**Source:**` provenance line on every entry (lint-enforced), pre-write vetting in the curator, a `vetting-knowledge` audit skill, and a `reviser` librarian agent that rewrites contradicted entries.

**Architecture:** Three coordinated layers. (A) Discovery: a new `using-project-knowledge` skill self-loads `knowledge/INDEX.md` into each plugin agent's context (one new "Before You Begin" line per agent body). (B) Vetting: curator gains pre-write search (exa/Ref MCPs detected by prefix; degraded to `observed_locally_unvetted` when absent); a new on-demand `vetting-knowledge` skill audits every entry, writes a timestamped report, optionally dispatches the new `reviser` agent per contradicted entry. (C) Lint enforcement: `lint-knowledge.sh` gains Check 4b requiring `**Source:**` on every entry; a one-shot `backfill-knowledge-sources.sh` migration script populates missing source lines for consumers.

**Tech Stack:** Markdown agents/skills (Claude Code plugin format); Bash for hooks, scripts, and tests (`set -uo pipefail`, process substitution `< <(...)` not `producer | while`); existing `tests/<name>/test-structure.sh` convention for structural assertions; `tests/<name>/test-integration.sh` for live Claude Code dispatch.

---

## File Structure

### Created

| Path | Purpose |
|---|---|
| `skills/using-project-knowledge/SKILL.md` | Discovery skill every plugin agent invokes from "Before You Begin" step 0 — surfaces `./knowledge/INDEX.md` as system-reminder; silent return on absence |
| `skills/vetting-knowledge/SKILL.md` | On-demand audit skill: enumerates entries, vets via exa/Ref, writes timestamped report at `knowledge/_meta/vetting-reports/<ISO>.md`, offers fix-loop dispatch of reviser |
| `agents/reviser.md` | Librarian-family agent — rewrites one contradicted entry to align with canonical guidance; preserves H3 date + since-SHA verbatim; does NOT modify INDEX or other entries |
| `scripts/backfill-knowledge-sources.sh` | One-shot migration: appends `**Source:** observed_locally_unvetted` to every entry missing a source line; idempotent |
| `tests/using-project-knowledge/test-structure.sh` | Structural test: frontmatter, INDEX-read behavior, no-fail-on-missing-knowledge clause, no-auto-load guidance |
| `tests/using-project-knowledge/fixtures/with-knowledge/knowledge/INDEX.md` | Fixture for integration test |
| `tests/using-project-knowledge/test-integration.sh` | Live Claude Code: skill invocation surfaces INDEX content |
| `tests/reviser/test-structure.sh` | Structural test: frontmatter (`color=teal`, `model=opus`, `effort=xhigh`), all 5 per-call fields, H3-preservation rule in anti-patterns |
| `tests/reviser/fixtures/contradicted-entry.md` | Fixture topic file with one known-contradicted entry |
| `tests/reviser/test-integration.sh` | Live Claude Code: dispatch reviser; assert H3 preserved, source line updated |
| `tests/vetting-knowledge/test-structure.sh` | Structural test: step ordering (1-8), report frontmatter shape, per-call block to reviser, degraded-mode handling |
| `tests/vetting-knowledge/fixtures/sample-knowledge/` | Fixture knowledge tree (INDEX + 1 confirmed-shaped + 1 unvetted-shaped entry) |
| `tests/vetting-knowledge/test-integration.sh` | Live Claude Code: skill run with no MCPs available — assert degraded report written |
| `tests/backfill-knowledge-sources/test.sh` | Bash test: fixture tree with mixed missing/present source lines → script adds missing, leaves present untouched; second run is no-op |
| `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/` | Fixture tree for backfill test (one entry missing source, one with URL source, one with `observed_locally_unvetted`) |

### Modified

| Path | Change |
|---|---|
| `agents/architect.md` | Add step 0 to "Before You Begin" invoking `superpowers:using-project-knowledge` |
| `agents/curator.md` | Add step 0 in new "Before You Begin"; add pre-write vetting step (MCP detect → search → classify); emit `**Source:**` line per entry; extended "Flagged for review" report shape |
| `agents/implementer-default.md` | Add step 0 to existing "Before You Begin" |
| `agents/implementer-expo.md` | Add step 0 to existing "Before You Begin" |
| `agents/implementer-fastapi.md` | Add step 0 to existing "Before You Begin" |
| `agents/planner.md` | Add step 0 to existing "Before You Begin" |
| `agents/reviewer-code-quality.md` | Add step 0 in new "Before You Begin" section |
| `agents/reviewer-migration-safety.md` | Add step 0 in new "Before You Begin" section |
| `agents/reviewer-multitenant-isolation.md` | Add step 0 in new "Before You Begin" section |
| `agents/reviewer-security.md` | Add step 0 in new "Before You Begin" section |
| `agents/reviewer-spec.md` | Add step 0 in new "Before You Begin" section |
| `agents/README.md` | Librarian family row gains `reviser`; per-call context fields table gains `reviser` row |
| `skills/finishing-a-development-branch/SKILL.md` | Handle curator's new "Flagged for review" block — interactive (a/b/c) prompt when contradictions present |
| `skills/curating-knowledge/SKILL.md` | Same handling for the manual entry point |
| `skills/linting-knowledge/SKILL.md` | Surface new check 4b errors ("missing/malformed **Source:** line") |
| `scripts/lint-knowledge.sh` | Insert Check 4b — every entry must end with `**Source:**` matching URL or `observed_locally_unvetted[ (...)]` |
| `docs/knowledge-schema.md` | New "Source line" subsection under "Entry style" documenting three valid forms |
| `tests/curator/test-structure.sh` | Extend: assert new vetting step present, `**Source:**` emission rule, degraded-mode language |
| `tests/lint-knowledge/test-lint.sh` | Extend: bad fixture must include missing-source entry; clean fixture must include all three valid forms |
| `tests/lint-knowledge/fixtures/bad/knowledge/gotchas/missing-source.md` | New bad fixture: entry without `**Source:**` line |
| `tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md` | Extend existing entries with `**Source:**` lines (URL + `observed_locally_unvetted` + parenthetical-hint variants) |
| `tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md` | Add `**Source:**` lines to all entries |
| `tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md` | Add INDEX bullet for the new missing-source fixture topic |
| `tests/claude-code/run-skill-tests.sh` | Append four new structural test paths to `tests=(...)`; append three new integration test paths to `integration_tests=(...)` |
| `package.json` / `.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` | Bump version 5.2.0 → 5.3.0 via `scripts/bump-version.sh` |
| `RELEASE-NOTES.md` | Append v5.3.0 entry summarizing the layer |

### Backfilled (in this branch)

| Path | Change |
|---|---|
| `knowledge/patterns/repo-conventions.md` | Append `**Source:** observed_locally_unvetted` to the one entry |
| `knowledge/gotchas/bash-scripts.md` | Append URL to "Pipe into while" entry (bash manual `BASHFAQ/024` URL); append `**Source:** observed_locally_unvetted` to "session-start hook" entry |
| `knowledge/gotchas/test-fixtures.md` | Append `**Source:** observed_locally_unvetted` to both entries |

---

## Implementation order

The order respects two hard constraints:

1. **Backfill closes the lint-failing window in a single task.** Tasks land in this order: 4 (write Check 4b — lint of this repo's own `knowledge/` now FAILS), 5 (backfill this repo's 5 entries — lint passes again). Between Task 4 commit and Task 5 commit, `scripts/lint-knowledge.sh ./knowledge` exits 1. Every other task either leaves the runner green or explicitly documents why (e.g., a RED-phase test ahead of GREEN implementation).

2. **Discovery skill exists before any agent invokes it.** Task 1 ships the skill; Tasks 6-11 add the invocation to agent bodies.

Task sequence:

1. **Task 1** — `using-project-knowledge` skill + structural test (the skill comes first; agents reference it from Task 6 onward)
2. **Task 2** — Schema doc update: `**Source:**` line section
3. **Task 3** — Backfill migration script + test (creates the tool we'll need in Task 5)
4. **Task 4** — Lint Check 4b: tests first (RED), then `scripts/lint-knowledge.sh` extension (GREEN) — at end of this task, this repo's own knowledge is lint-failing
5. **Task 5** — Backfill this repo's 5 existing entries (closes the lint-failing window — `scripts/lint-knowledge.sh ./knowledge` passes again)
6. **Task 6** — Add step-0 invocation to all 5 existing agents that already have "Before You Begin" (architect, planner, implementer-default, implementer-expo, implementer-fastapi)
7. **Task 7** — Add step-0 invocation to the 5 reviewer agents (which require creating a "Before You Begin" section first)
8. **Task 8** — Curator vetting changes + extended report shape + step-0 invocation (test extension covers all three)
9. **Task 9** — `reviser` agent + structural test + integration test scaffold; add to `agents/README.md`
10. **Task 10** — `vetting-knowledge` skill + structural test + integration test scaffold (skill body covers Steps 1-8 from spec)
11. **Task 11** — Update dispatcher skills (`finishing-a-development-branch`, `curating-knowledge`, `linting-knowledge`) to handle the new "Flagged for review" interaction and new lint check
12. **Task 12** — Wire new test paths into `tests/claude-code/run-skill-tests.sh`; verify suite green
13. **Task 13** — Version bump 5.2.0 → 5.3.0 + RELEASE-NOTES entry

---

### Task 1: `using-project-knowledge` skill (Layer A foundation)

**Files:**
- Create: `skills/using-project-knowledge/SKILL.md`
- Create: `tests/using-project-knowledge/test-structure.sh`
- Create: `tests/using-project-knowledge/fixtures/with-knowledge/knowledge/INDEX.md`

This skill lands first because every agent body update (Tasks 6, 7, 8, 9) references its name (`superpowers:using-project-knowledge`). Skipping it leaves agents pointing at a missing skill, which silently breaks the discovery layer.

- [ ] **Step 1: Write the failing structural test**

Create `tests/using-project-knowledge/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for using-project-knowledge skill.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/using-project-knowledge/SKILL.md"
FIX="$SCRIPT_DIR/fixtures"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

assert_file() {
    local path="$1" name="$2"
    if [ -f "$path" ]; then pass "$name exists"; else fail "$name missing: $path"; fi
}

assert_grep() {
    local path="$1" pattern="$2" name="$3"
    if grep -qE "$pattern" "$path" 2>/dev/null; then
        pass "$name"
    else
        fail "$name (pattern '/$pattern/' not in $path)"
    fi
}

echo "========================================"
echo " using-project-knowledge: structural tests"
echo "========================================"

# Skill file presence and frontmatter
assert_file "$SKILL" "skills/using-project-knowledge/SKILL.md"
assert_grep "$SKILL" '^name: using-project-knowledge$' "frontmatter: name=using-project-knowledge"
assert_grep "$SKILL" '^description: Use at the start' "frontmatter: description starts with 'Use at the start'"

# Required sections
assert_grep "$SKILL" '^## ' "section: at least one H2"
assert_grep "$SKILL" 'Announce at start' "skill announces itself at start"

# Behavior: tests for INDEX.md presence
assert_grep "$SKILL" 'knowledge/INDEX\.md' "references knowledge/INDEX.md path"
assert_grep "$SKILL" 'no `knowledge/`|no knowledge dir|proceeding without project knowledge' "silent return when knowledge absent"

# Guidance: do not auto-load topic files
assert_grep "$SKILL" 'do NOT auto-load|Do NOT auto-load|not auto-load every' "explicit no-auto-load guidance"

# Guidance: Read on hook match
assert_grep "$SKILL" 'Read.*topic|hook matches' "Read topic file when hook matches"

# Fixture for integration test
assert_file "$FIX/with-knowledge/knowledge/INDEX.md" "integration fixture: INDEX.md"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

Make executable:

```bash
chmod +x tests/using-project-knowledge/test-structure.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
bash tests/using-project-knowledge/test-structure.sh
```

Expected: FAIL — skill file missing, fixture missing.

- [ ] **Step 3: Create the integration fixture**

Create `tests/using-project-knowledge/fixtures/with-knowledge/knowledge/INDEX.md`:

```markdown
# Knowledge Index

## Patterns

- **fixture-pattern** — Sample hook for a fixture-pattern topic — `patterns/fixture-pattern.md`

## Gotchas

- **fixture-gotcha** — Sample hook for a fixture-gotcha topic — `gotchas/fixture-gotcha.md`
```

- [ ] **Step 4: Write the skill body**

Create `skills/using-project-knowledge/SKILL.md`:

```markdown
---
name: using-project-knowledge
description: Use at the start of every subagent task to load the project's knowledge index (patterns + gotchas captured from prior work). Surfaces ./knowledge/INDEX.md as a system-reminder and instructs the agent to Read specific topic files when their hook matches the task.
---

# Using Project Knowledge

## Overview

Lightweight discovery skill invoked by every plugin agent as the first step of "Before You Begin". Loads the project's `knowledge/INDEX.md` (if present) into the agent's context. Does NOT auto-load topic files — only the INDEX, which holds one-line hooks per topic; the agent decides which topic files to `Read` based on hook relevance.

**Core principle:** the agent self-loads project-stable environmental context. The dispatcher curates only per-task dynamic context (SPEC_PATH, IMPLEMENTER_REPORT, etc.). INDEX.md lives at a known path and is the same across calls — the agent can fetch it itself.

**Announce at start:** "I'm using the using-project-knowledge skill to surface the project knowledge index."

## The Process

### Step 1: Check for `./knowledge/INDEX.md`

Use the `Bash` or `Read` tool to test whether the file exists at the path `./knowledge/INDEX.md` relative to the current working directory.

```bash
test -f ./knowledge/INDEX.md && echo "present" || echo "absent"
```

### Step 2a: If absent — silent return

Emit a single line:

```
Project has no `knowledge/` directory; proceeding without project knowledge.
```

Then exit the skill. Do not fail. Do not retry. Many projects (and all first-curator-run projects) have no `knowledge/` yet.

### Step 2b: If present — surface as system-reminder

Read the file's full contents with the `Read` tool. Surface it back to the invoking agent as a system-reminder block, followed by this instruction text verbatim:

> Treat the index above as authoritative for project-specific patterns and gotchas. When a row's hook matches your current task, `Read` the referenced topic file before proceeding. Do NOT auto-load every topic file — only the ones whose hooks match what you're working on.

Exit the skill.

## Why INDEX-only

Topic files can run ~300 lines each. A knowledge tree with 10 topics would be ~3000 lines of context — most irrelevant to any given task. INDEX hooks are ≤120 chars: enough for the agent to recognize relevance and `Read` selectively. Same budget reasoning as the SessionStart hook for the main session.

## Anti-Patterns — What NOT to Do

**DO NOT:**
- Auto-load topic files alongside INDEX — burns context
- Fail / error when `knowledge/` is absent — silent return is the contract
- Walk up the directory tree looking for a knowledge dir — only check `./knowledge/INDEX.md` (the agent's cwd)
- Surface the INDEX content multiple times in one task — load once at the start
- Modify INDEX or any topic file — read-only skill
```

- [ ] **Step 5: Run the structural test to verify it passes**

```bash
bash tests/using-project-knowledge/test-structure.sh
```

Expected: PASS for all assertions.

- [ ] **Step 6: Commit**

```bash
git add skills/using-project-knowledge/ tests/using-project-knowledge/
git commit -m "feat(skills): add using-project-knowledge discovery skill

Lightweight skill every plugin agent invokes from Before-You-Begin
step 0. Loads ./knowledge/INDEX.md into the agent's context when
present; silent return otherwise. INDEX-only — no auto-load of topic
files.

Foundation for the discovery layer; agent-body invocations follow
in later tasks."
```

---

### Task 2: Schema doc — add `**Source:**` line section

**Files:**
- Modify: `docs/knowledge-schema.md` (insert new subsection in "Entry style")

The schema doc is the single source of truth — lint script, curator agent, and reviser agent will all reference it. Update it before the lint check (Task 4) and the backfill script (Task 3).

- [ ] **Step 1: Read current `docs/knowledge-schema.md` to find the insertion point**

```bash
grep -n '^##' docs/knowledge-schema.md
```

Expected: the "Entry style" H2 sits between "Topic file" and "Naming".

- [ ] **Step 2: Append the Source-line subsection after the existing 5-point list in "Entry style"**

Edit `docs/knowledge-schema.md`. After the existing line `No generic advice ("use clean code", "write tests"). Every entry must be specific to THIS codebase.`, insert:

```markdown

### Source line

Every entry MUST end with a `**Source:**` line. Three valid forms:

- `**Source:** <URL>` — any string starting with `http://` or `https://`. Use when canonical documentation supports the entry.
- `**Source:** observed_locally_unvetted` — use when the entry captures a local observation the curator couldn't ground against canonical sources.
- `**Source:** observed_locally_unvetted (<optional hint>)` — same as above, with a short parenthetical hint (e.g. `observed_locally_unvetted (vetting skipped — exa/Ref unavailable)`).

Anything else is a lint error (hard). See `scripts/lint-knowledge.sh` Check 4b.

Example:

```markdown
### 2026-05-11 — BaseHTTPMiddleware breaks ContextVars (since abc1234)

Using `BaseHTTPMiddleware` from Starlette loses request-scoped ContextVars
between middleware and the route handler.

**Why:** Starlette runs `BaseHTTPMiddleware` via a TaskGroup; ContextVar
writes inside it don't propagate to the route handler's task.

**Avoid:** use pure ASGI middleware (`call/await scope, receive, send`)
for anything that mutates ContextVars.

**Source:** https://github.com/encode/starlette/issues/1273
```
```

- [ ] **Step 3: Sanity-check rendering and word count**

```bash
grep -c '^## ' docs/knowledge-schema.md   # expect ≥ 8 (one new H2 may not be added; the new content is H3)
grep -c '^### ' docs/knowledge-schema.md  # expect one more than before — new "Source line" H3
wc -w docs/knowledge-schema.md            # expect slight increase (~150 words added)
```

- [ ] **Step 4: Commit**

```bash
git add docs/knowledge-schema.md
git commit -m "docs(schema): document **Source:** line on every entry

Every entry MUST end with a Source line. Three valid forms: URL,
literal observed_locally_unvetted, or observed_locally_unvetted with
parenthetical hint. Anything else is a lint error (hard).

Foundation for lint Check 4b and curator vetting changes."
```

---

### Task 3: Backfill migration script + test

**Files:**
- Create: `scripts/backfill-knowledge-sources.sh`
- Create: `tests/backfill-knowledge-sources/test.sh`
- Create: `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/INDEX.md`
- Create: `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/patterns/topic-a.md`
- Create: `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/gotchas/topic-b.md`

This script ships before the lint check itself — we'll need it to backfill this repo's own 5 entries (Task 5). It's also the migration tool consumers run once when upgrading to v5.3.

The fixture topology: one topic has an entry missing `**Source:**`; another topic has entries with each of the three valid source forms. After running the script, only the first entry should change; second run should be a no-op.

- [ ] **Step 1: Write the failing test**

Create `tests/backfill-knowledge-sources/test.sh`:

```bash
#!/usr/bin/env bash
# Test for scripts/backfill-knowledge-sources.sh.
# Asserts:
#   1. Entries missing **Source:** get observed_locally_unvetted appended
#   2. Entries with existing **Source:** are untouched
#   3. Second run is a no-op (idempotent)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKFILL="$REPO_ROOT/scripts/backfill-knowledge-sources.sh"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

# Make a fresh working copy of the fixture (don't mutate the committed fixture)
WORK=$(mktemp -d)
cp -R "$SCRIPT_DIR/fixtures/mixed/knowledge" "$WORK/knowledge"

echo "========================================"
echo " backfill-knowledge-sources: first run"
echo "========================================"

bash "$BACKFILL" "$WORK/knowledge" >/dev/null 2>&1
first_exit=$?
if [ "$first_exit" -eq 0 ]; then pass "first run exits 0"; else fail "first run exited $first_exit"; fi

# Entry that was missing source should now have observed_locally_unvetted
if grep -q '^\*\*Source:\*\* observed_locally_unvetted$' "$WORK/knowledge/patterns/topic-a.md"; then
    pass "topic-a missing-source entry: backfilled with observed_locally_unvetted"
else
    fail "topic-a missing-source entry not backfilled"
fi

# Existing URL source preserved verbatim
if grep -q '^\*\*Source:\*\* https://example\.com/canonical$' "$WORK/knowledge/gotchas/topic-b.md"; then
    pass "topic-b URL source: preserved"
else
    fail "topic-b URL source disturbed"
fi

# Existing observed_locally_unvetted (with hint) preserved verbatim
if grep -q '^\*\*Source:\*\* observed_locally_unvetted (sample hint)$' "$WORK/knowledge/gotchas/topic-b.md"; then
    pass "topic-b parenthetical-hint source: preserved"
else
    fail "topic-b parenthetical-hint source disturbed"
fi

# Snapshot post-first-run state
checksum1=$(find "$WORK/knowledge" -type f -name '*.md' | sort | xargs cat | shasum | awk '{print $1}')

echo ""
echo "========================================"
echo " backfill-knowledge-sources: second run (idempotent)"
echo "========================================"

bash "$BACKFILL" "$WORK/knowledge" >/dev/null 2>&1
second_exit=$?
if [ "$second_exit" -eq 0 ]; then pass "second run exits 0"; else fail "second run exited $second_exit"; fi

checksum2=$(find "$WORK/knowledge" -type f -name '*.md' | sort | xargs cat | shasum | awk '{print $1}')
if [ "$checksum1" = "$checksum2" ]; then pass "second run is idempotent (no file changes)"; else fail "second run mutated files (not idempotent)"; fi

rm -rf "$WORK"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

Make executable:

```bash
chmod +x tests/backfill-knowledge-sources/test.sh
```

- [ ] **Step 2: Create the fixtures**

Create `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/INDEX.md`:

```markdown
# Knowledge Index

## Patterns

- **topic-a** — Sample patterns topic — `patterns/topic-a.md`

## Gotchas

- **topic-b** — Sample gotchas topic — `gotchas/topic-b.md`
```

Create `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/patterns/topic-a.md`:

```markdown
---
topic: topic-a
category: patterns
last-updated: 2026-05-01
last-since: abc1234
---

# Topic A

## Entries

### 2026-05-01 — Entry missing the Source line (since abc1234)

This entry has no Source line — backfill should append observed_locally_unvetted.

**Why:** simulating a pre-v5.3 entry.

**Avoid:** leaving it like this after the lint check rolls out.
```

Create `tests/backfill-knowledge-sources/fixtures/mixed/knowledge/gotchas/topic-b.md`:

```markdown
---
topic: topic-b
category: gotchas
last-updated: 2026-05-01
last-since: abc1234
---

# Topic B

## Entries

### 2026-05-01 — Entry with URL source (since abc1234)

This entry already has a URL source — backfill should leave it alone.

**Why:** canonical documentation supports it.

**Source:** https://example.com/canonical

### 2026-05-01 — Entry with hinted source (since abc1234)

This entry already has an observed_locally_unvetted source with a hint.

**Why:** local observation; vetting skipped.

**Source:** observed_locally_unvetted (sample hint)
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
bash tests/backfill-knowledge-sources/test.sh
```

Expected: FAIL (backfill script does not exist yet).

- [ ] **Step 4: Write the backfill script**

Create `scripts/backfill-knowledge-sources.sh`:

```bash
#!/usr/bin/env bash
# Backfill **Source:** lines on knowledge/ entries that are missing them.
# Appends `**Source:** observed_locally_unvetted` as the last non-blank line
# of each entry's body (before the next `### ` header or EOF).
# Idempotent: entries that already have a Source line are untouched.
#
# Usage: backfill-knowledge-sources.sh [<path-to-knowledge-dir>]
# Defaults to ./knowledge if no arg given.
#
# Exit codes:
#   0 — success (may have made changes or been a no-op)
#   1 — runtime error
#   2 — usage error
set -uo pipefail

KNOWLEDGE="${1:-./knowledge}"
if [ ! -d "$KNOWLEDGE" ]; then
    echo "ERROR: knowledge directory not found: $KNOWLEDGE" >&2
    exit 2
fi

INDEX="$KNOWLEDGE/INDEX.md"
META="$KNOWLEDGE/_meta"

# Process one topic file in-place via awk.
# State machine: walk entries delimited by ^### .
# When transitioning out of an entry (next ### or EOF), check whether the
# accumulated body contained a ^**Source:** line. If not, emit
# **Source:** observed_locally_unvetted just before the boundary.
process_topic() {
    local topic="$1"
    local tmp
    tmp=$(mktemp)
    awk '
        function flush_entry() {
            # Trim trailing blank lines from the body
            while (n > 0 && body[n] ~ /^[[:space:]]*$/) {
                n--
            }
            # Print body up to n
            for (i = 1; i <= n; i++) print body[i]
            # If no Source line found in this entry, inject one
            if (in_entry && !have_source) {
                print ""
                print "**Source:** observed_locally_unvetted"
            }
            # Reset
            n = 0
            have_source = 0
        }

        BEGIN { in_entry = 0; n = 0; have_source = 0 }

        /^### / {
            if (in_entry) {
                flush_entry()
                print ""
            }
            in_entry = 1
            n = 0
            have_source = 0
            print $0
            next
        }

        {
            if (in_entry) {
                if ($0 ~ /^\*\*Source:\*\* /) have_source = 1
                n++
                body[n] = $0
            } else {
                print $0
            }
        }

        END {
            if (in_entry) flush_entry()
        }
    ' "$topic" > "$tmp"

    # Replace only if content differs
    if ! cmp -s "$topic" "$tmp"; then
        mv "$tmp" "$topic"
    else
        rm -f "$tmp"
    fi
}

# Walk every topic file under $KNOWLEDGE, skipping INDEX.md and _meta/.
# Use process substitution so the loop runs in the current shell.
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    process_topic "$topic"
done < <(find "$KNOWLEDGE" -type f -name '*.md' \
            ! -path "$INDEX" ! -path "$META/*" 2>/dev/null)

exit 0
```

Make executable:

```bash
chmod +x scripts/backfill-knowledge-sources.sh
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
bash tests/backfill-knowledge-sources/test.sh
```

Expected: PASS — first run backfills the missing entry, leaves the others alone; second run is idempotent.

- [ ] **Step 6: Commit**

```bash
git add scripts/backfill-knowledge-sources.sh tests/backfill-knowledge-sources/
git commit -m "feat(scripts): add backfill-knowledge-sources.sh + test

One-shot migration: appends '**Source:** observed_locally_unvetted'
to every entry missing a Source line. Idempotent (second run is a
no-op). Documented in v5.3 release notes as the consumer-side
migration tool for pre-v5.3 knowledge dirs.

Also used in this same branch (Task 5) to backfill the plugin repo's
own 5 existing entries before the lint check rolls out."
```

---

### Task 4: Lint Check 4b — `**Source:**` enforcement (TDD)

**Files:**
- Modify: `tests/lint-knowledge/test-lint.sh` (extend with new assertions)
- Create: `tests/lint-knowledge/fixtures/bad/knowledge/gotchas/missing-source.md`
- Modify: `tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md` (add INDEX hook for new fixture)
- Modify: `tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md` (add Source lines, including all three valid forms)
- Modify: `tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md` (add Source lines)
- Modify: `scripts/lint-knowledge.sh` (insert Check 4b between Check 4 and Check 5)

This is TDD for the lint extension. **Lint-failing window opens at the end of this task** — committing the lint check before backfill (Task 5) means `scripts/lint-knowledge.sh ./knowledge` against this repo's own `knowledge/` will exit 1 (the 5 existing entries don't yet have Source lines). The plan closes this window in the very next task.

- [ ] **Step 1: Read current lint test + fixtures**

```bash
cat tests/lint-knowledge/test-lint.sh
ls tests/lint-knowledge/fixtures/bad/knowledge tests/lint-knowledge/fixtures/clean/knowledge
cat tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md
cat tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md
cat tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md
```

This shows the existing baseline: `auth.md` and `testing.md` are valid topic files; the bad fixture INDEX needs a new bullet for our `missing-source` topic.

- [ ] **Step 2: Add the new bad fixture (entry missing the Source line)**

Create `tests/lint-knowledge/fixtures/bad/knowledge/gotchas/missing-source.md`:

```markdown
---
topic: missing-source
category: gotchas
last-updated: 2026-05-12
last-since: HEAD
---

# Missing source line

## Entries

### 2026-05-12 — This entry has no Source line and should trip Check 4b (since HEAD)

The body deliberately omits the `**Source:**` line so the lint flags it.

**Why:** demonstrating Check 4b's hard-error behavior.

**Avoid:** writing entries without a Source line — pick one of the three
valid forms (URL, observed_locally_unvetted, or observed_locally_unvetted
with parenthetical hint).
```

- [ ] **Step 3: Add the new fixture to the bad-INDEX**

Edit `tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md`. Add a Gotchas bullet for the new topic. The exact additions depend on the existing structure — open the file and append a bullet under the Gotchas section:

```markdown
- **missing-source** — Sample entry deliberately missing the Source line — `gotchas/missing-source.md`
```

Confirm by re-reading the file:

```bash
grep 'missing-source' tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md
```

Expected: matches the new bullet.

- [ ] **Step 4: Extend the clean fixture with Source lines (all three valid forms)**

Edit `tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md`. For each existing entry under `## Entries`, append a `**Source:**` line as the last line of the entry body (before the next `### ` header or EOF). Use a mix of the three valid forms so the lint test exercises all of them:

- First entry: `**Source:** https://example.com/auth-canonical`
- Second entry (if present): `**Source:** observed_locally_unvetted`
- Third entry (if present): `**Source:** observed_locally_unvetted (sample parenthetical hint)`

If the fixture has fewer than three entries, distribute the forms across the entries present and document that you'll need to add Source lines for any future entries you add.

Repeat for `tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md` — append a `**Source:**` line to every entry (any of the three forms is fine; vary them).

After editing, verify:

```bash
# Every entry in clean fixture has a Source line
grep -c '^\*\*Source:\*\* ' tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md
grep -c '^\*\*Source:\*\* ' tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md
# Each count should equal the entry count (grep ^### )
grep -c '^### ' tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md
grep -c '^### ' tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md
```

Expected: Source-line count equals entry count in both files.

- [ ] **Step 5: Extend `tests/lint-knowledge/test-lint.sh` with the new assertions**

Edit `tests/lint-knowledge/test-lint.sh`. Add new assertions to the bad-fixture and clean-fixture sections. After the existing `assert_report_contains "$BAD_REPORT" 'dangling|...' "..."` line in the bad-fixture block, append:

```bash
assert_report_contains "$BAD_REPORT" 'missing \*\*Source:\*\*|missing Source line|malformed \*\*Source:\*\*' "Check 4b: detects missing Source line"
```

The clean-fixture block stays mostly the same — it already asserts "no errors" via `assert_report_clean`. But we want a positive assertion that all three valid Source forms are recognized; add inside the clean-fixture block (after `assert_report_clean`):

```bash
# Sanity-check that the clean fixture exercises all three valid Source forms
grep -h '^\*\*Source:\*\* ' "$CLEAN/patterns/auth.md" "$CLEAN/gotchas/testing.md" > /tmp/clean-sources.txt
if grep -q '^\*\*Source:\*\* https\?://' /tmp/clean-sources.txt; then pass "clean fixture: URL form present"; else fail "clean fixture: URL form missing"; fi
if grep -qE '^\*\*Source:\*\* observed_locally_unvetted$' /tmp/clean-sources.txt; then pass "clean fixture: literal unvetted form present"; else fail "clean fixture: literal unvetted form missing"; fi
if grep -qE '^\*\*Source:\*\* observed_locally_unvetted \(' /tmp/clean-sources.txt; then pass "clean fixture: parenthetical-hint form present"; else fail "clean fixture: parenthetical-hint form missing"; fi
rm -f /tmp/clean-sources.txt
```

- [ ] **Step 6: Run the lint test to verify it fails (RED)**

```bash
bash tests/lint-knowledge/test-lint.sh
```

Expected: FAIL on the "Check 4b: detects missing Source line" assertion (the lint script hasn't been extended yet, so the report doesn't mention missing Source lines). Other new assertions should pass (we set up the fixtures correctly in Steps 2-4).

- [ ] **Step 7: Extend `scripts/lint-knowledge.sh` with Check 4b**

Edit `scripts/lint-knowledge.sh`. Insert this block between the existing Check 4 (`# 4. Each entry has a since-SHA annotation`) and Check 5 (`# 5. SHA resolution via git cat-file`):

```bash
# 4b. Every entry has a **Source:** line matching one of three valid forms.
#     Valid: starts with http:// or https://; equals observed_locally_unvetted;
#     starts with "observed_locally_unvetted (". Anything else: hard error.
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    # Walk entries inside the topic; for each entry section search the body
    # for ^**Source:** lines and classify. Use awk to split into per-entry
    # streams keyed by entry title.
    while IFS=$'\t' read -r entry_title source_value; do
        [ -z "$entry_title" ] && continue
        if [ -z "$source_value" ]; then
            err "missing **Source:** line in entry: $topic:$entry_title"
            continue
        fi
        # Validate the value matches one of the three accepted forms.
        case "$source_value" in
            "http://"*|"https://"*) : ;;  # URL form — OK
            "observed_locally_unvetted") : ;;  # literal — OK
            "observed_locally_unvetted ("*) : ;;  # parenthetical hint — OK
            *)
                err "malformed **Source:** value in entry: $topic:$entry_title (got: $source_value)"
                ;;
        esac
    done < <(awk '
        /^### / {
            if (in_entry) {
                # Emit a TAB-separated record: title<TAB>source_value
                # (source_value is empty when no Source line was found)
                print prev_title "\t" source
            }
            in_entry = 1
            prev_title = $0
            sub(/^### /, "", prev_title)
            source = ""
            next
        }
        in_entry && /^\*\*Source:\*\* / {
            # Strip the marker, keep the value verbatim
            line = $0
            sub(/^\*\*Source:\*\* /, "", line)
            source = line
            next
        }
        END {
            if (in_entry) print prev_title "\t" source
        }
    ' "$topic")
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")
```

- [ ] **Step 8: Run the lint test to verify it passes (GREEN)**

```bash
bash tests/lint-knowledge/test-lint.sh
```

Expected: PASS — bad fixture now reports missing-Source; clean fixture has all three forms and no errors.

- [ ] **Step 9: Confirm this repo's own lint now FAILS (this is intentional)**

```bash
bash scripts/lint-knowledge.sh ./knowledge
echo "exit=$?"
cat knowledge/_meta/lint-report.md
```

Expected: exit 1; report lists 5 missing-Source errors (one for `patterns/repo-conventions.md`, two each for `gotchas/bash-scripts.md` and `gotchas/test-fixtures.md`). The next task closes this window.

- [ ] **Step 10: Commit**

```bash
git add scripts/lint-knowledge.sh tests/lint-knowledge/
git commit -m "feat(lint): Check 4b — every entry must end with **Source:** line

Hard error on missing or malformed Source line. Three valid forms:
URL, observed_locally_unvetted, observed_locally_unvetted (hint).

This commit deliberately leaves the plugin repo's own knowledge/
lint-failing — Task 5 backfills the 5 existing entries to close
the window. The order is intentional: it proves the check works."
```

---

### Task 5: Backfill this repo's 5 existing knowledge entries

**Files:**
- Modify: `knowledge/patterns/repo-conventions.md` (1 entry → `observed_locally_unvetted`)
- Modify: `knowledge/gotchas/bash-scripts.md` (1 entry → bash-manual URL; 1 entry → `observed_locally_unvetted`)
- Modify: `knowledge/gotchas/test-fixtures.md` (2 entries → both `observed_locally_unvetted`)

This task closes the lint-failing window opened by Task 4. We do NOT use the backfill script blindly here — the bash-pipe-into-while entry has a real canonical source we want to cite (the bash manual / BashFAQ), so we hand-edit that one. The other 4 entries are genuine plugin-specific observations with no canonical source, so they get the `observed_locally_unvetted` marker.

- [ ] **Step 1: Append `**Source:** observed_locally_unvetted` to `knowledge/patterns/repo-conventions.md`'s three entries**

Open `knowledge/patterns/repo-conventions.md`. It has three H3 entries today (despite the spec saying "1 entry" — confirm by counting):

```bash
grep -c '^### ' knowledge/patterns/repo-conventions.md
```

If the count is 3, append a `**Source:** observed_locally_unvetted` line at the bottom of each entry body (just before the next `### ` header, or EOF for the last one). Each entry should now end with:

```markdown

**Source:** observed_locally_unvetted
```

(blank line above the Source line, no blank line after — same as the body's other `**Why:**` / `**Avoid:**` markers).

If the spec's "1 entry" count is wrong, that's fine — the rule is the same: every entry gets a Source line.

- [ ] **Step 2: Append `**Source:**` lines to `knowledge/gotchas/bash-scripts.md`**

Open `knowledge/gotchas/bash-scripts.md`. Two entries:

- `### 2026-05-11 — Pipe into while discards array writes (subshell trap) (since 7ddaa9c)` — this is canonical bash behavior; cite a real URL. Append:

  ```markdown

  **Source:** https://mywiki.wooledge.org/BashFAQ/024
  ```

  (BashFAQ/024 is "I set variables in a loop that's in a pipeline. Why do they disappear after the loop terminates?" — the canonical reference for this exact subshell trap.)

- `### 2026-05-11 — hooks/session-start resolves knowledge/INDEX.md via ${PWD} (since d77e453)` — plugin-specific behavior; append:

  ```markdown

  **Source:** observed_locally_unvetted
  ```

- [ ] **Step 3: Append `**Source:** observed_locally_unvetted` to both entries in `knowledge/gotchas/test-fixtures.md`**

Open `knowledge/gotchas/test-fixtures.md`. Two entries, both plugin-specific test-design observations:

- `### 2026-05-11 — Bad-fixture must actually exceed the threshold it tests (since 6868f02)` — append `**Source:** observed_locally_unvetted`.
- `### 2026-05-11 — Curator test regex is literal-phrase-sensitive (since aae076d)` — append `**Source:** observed_locally_unvetted`.

- [ ] **Step 4: Verify all entries now have a Source line**

```bash
# Compare entry count vs. Source-line count per topic
for topic in knowledge/patterns/*.md knowledge/gotchas/*.md; do
    entries=$(grep -c '^### ' "$topic")
    sources=$(grep -c '^\*\*Source:\*\* ' "$topic")
    echo "$topic: entries=$entries sources=$sources"
done
```

Expected: every topic shows entries == sources.

- [ ] **Step 5: Run the lint to confirm clean exit**

```bash
bash scripts/lint-knowledge.sh ./knowledge
echo "exit=$?"
```

Expected: exit 0 (no errors). Warnings may persist (oversized entries, etc.) — those are not changed by this task.

- [ ] **Step 6: Commit**

```bash
git add knowledge/patterns/repo-conventions.md knowledge/gotchas/bash-scripts.md knowledge/gotchas/test-fixtures.md
git commit -m "docs(knowledge): backfill **Source:** lines on existing entries

Adds Source lines to the 5 existing entries:
- patterns/repo-conventions.md (3 entries): observed_locally_unvetted
- gotchas/bash-scripts.md:
  - Pipe-into-while: BashFAQ/024 (canonical bash subshell reference)
  - session-start \${PWD}: observed_locally_unvetted
- gotchas/test-fixtures.md (2 entries): observed_locally_unvetted

Closes the lint-failing window opened by Check 4b in the previous
commit. \`scripts/lint-knowledge.sh ./knowledge\` exits 0 again."
```

---

### Task 6: Add step-0 invocation to the 5 agents that already have "Before You Begin"

**Files:**
- Modify: `agents/architect.md` (line ~23, "## Before You Begin")
- Modify: `agents/planner.md` (line ~24, "## Before You Begin")
- Modify: `agents/implementer-default.md` (line ~27, "## Before You Begin")
- Modify: `agents/implementer-expo.md` (line ~23, "## Before You Begin")
- Modify: `agents/implementer-fastapi.md` (line ~23, "## Before You Begin")

Each of these agents already has a "Before You Begin" section. We prepend a numbered step 0 that invokes the discovery skill. Existing content stays. After this task, 5/12 agents carry the invocation.

The exact insertion text is identical across files (DRY — copy-paste from the spec):

```markdown
0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context.
```

- [ ] **Step 1: Insert step 0 into `agents/architect.md`**

Read the current "Before You Begin" section to see how it's structured:

```bash
sed -n '/^## Before You Begin/,/^## /p' agents/architect.md
```

The existing section is prose (no numbered list). We need to introduce a numbered list. Use the `Edit` tool: replace the existing "Before You Begin" paragraph with:

```markdown
## Before You Begin

0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context.
1. Read CODE_CONTEXT in full. Re-read QUESTION carefully — make sure you're answering the actual question, not a question you would have preferred. If the question is too broad to give a focused recommendation, ask the dispatcher to scope it down before proceeding.
2. If the question is vague or ambiguous in a way that materially changes the answer, ask one clarifying question rather than inventing assumptions.
```

(The numbering converts the existing two prose paragraphs into items 1 and 2. Content stays identical — only formatting changes.)

- [ ] **Step 2: Insert step 0 into `agents/planner.md`**

The planner's "Before You Begin" already uses numbered items 1-3. Prepend:

```markdown
0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context.
```

Place this immediately after `## Before You Begin\n\n` and before the existing `1. Read SPEC_PATH in full.` line.

- [ ] **Step 3: Insert step 0 into `agents/implementer-default.md`**

The implementer's "Before You Begin" is bulleted prose, not numbered. Insert step 0 at the top of the section, before the existing bullets:

```markdown
## Before You Begin

0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context.

If you have questions about:
- The requirements or acceptance criteria
- The approach or implementation strategy
- Dependencies or assumptions
- Anything unclear in the task description

**Ask them now.** Raise any concerns before starting work.
```

(Step 0 sits cleanly above the bulleted prose; the rest of the section is unchanged.)

- [ ] **Step 4: Insert step 0 into `agents/implementer-expo.md`**

Same structural shape as `implementer-default.md`. Insert step 0 at the top of "Before You Begin", preserving everything below it.

- [ ] **Step 5: Insert step 0 into `agents/implementer-fastapi.md`**

Same shape. Insert step 0 at the top.

- [ ] **Step 6: Confirm all 5 agents now reference the skill**

```bash
for agent in agents/architect.md agents/planner.md agents/implementer-default.md agents/implementer-expo.md agents/implementer-fastapi.md; do
    grep -l 'superpowers:using-project-knowledge' "$agent" || echo "MISSING: $agent"
done
```

Expected: each path prints (no "MISSING:" lines).

- [ ] **Step 7: Run existing structural tests to confirm nothing broke**

```bash
bash tests/architect/test-structure.sh
bash tests/planner/test-structure.sh
# Implementer agents have no per-agent structural test (yet) — covered by
# tests/architect/test-structure.sh's cross-file BLOCKED:ARCHITECTURAL check
```

Expected: all PASS — we only added a section/step, didn't remove any tracked content.

- [ ] **Step 8: Commit**

```bash
git add agents/architect.md agents/planner.md agents/implementer-default.md agents/implementer-expo.md agents/implementer-fastapi.md
git commit -m "feat(agents): step-0 using-project-knowledge invocation (5 agents)

Adds 'Skill(\"superpowers:using-project-knowledge\")' to step 0 of
'Before You Begin' for architect, planner, and the three implementer
variants. Discovery layer foundation — every plugin agent will self-load
the project knowledge INDEX at the start of its task.

5 / 12 agents updated; remaining 7 follow in subsequent tasks."
```

---

### Task 7: Add "Before You Begin" + step-0 to the 5 reviewer agents

**Files:**
- Modify: `agents/reviewer-code-quality.md`
- Modify: `agents/reviewer-migration-safety.md`
- Modify: `agents/reviewer-multitenant-isolation.md`
- Modify: `agents/reviewer-security.md`
- Modify: `agents/reviewer-spec.md`

Reviewer agents today go directly from `## Per-Call Context` to checklist/criteria content — they have no "Before You Begin" section. We create one and put step 0 inside.

The text block to insert is identical across files:

```markdown
## Before You Begin

0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context. Project gotchas (especially around the technologies you're reviewing) often inform whether a pattern in the diff is correct or a known footgun.

If any Per-Call Context field is missing or unclear, ask the dispatcher before proceeding.

```

Insert this block immediately after the `## Per-Call Context` section closes (i.e., after the field list ends and before the next H2).

- [ ] **Step 1: Insert "Before You Begin" into `agents/reviewer-code-quality.md`**

Find the end of "## Per-Call Context" (the field list) and the start of the next H2. Insert the block between them.

Verify:

```bash
grep -n '^## ' agents/reviewer-code-quality.md
grep -n 'superpowers:using-project-knowledge' agents/reviewer-code-quality.md
```

Expected: "Before You Begin" H2 appears in section listing, and the skill invocation line resolves to a line under it.

- [ ] **Step 2-5: Repeat for the four remaining reviewers**

For each of `reviewer-migration-safety.md`, `reviewer-multitenant-isolation.md`, `reviewer-security.md`, `reviewer-spec.md`:

1. Find the end of the `## Per-Call Context` field list and the start of the next H2.
2. Insert the same "Before You Begin" block.
3. Verify with `grep`.

- [ ] **Step 6: Confirm all 5 reviewers now reference the skill**

```bash
for agent in agents/reviewer-code-quality.md agents/reviewer-migration-safety.md agents/reviewer-multitenant-isolation.md agents/reviewer-security.md agents/reviewer-spec.md; do
    grep -l 'superpowers:using-project-knowledge' "$agent" || echo "MISSING: $agent"
done
```

Expected: each path prints.

- [ ] **Step 7: Run existing reviewer structural tests**

```bash
bash tests/reviewer-code-quality/test-structure.sh
bash tests/reviewer-spec/test-structure.sh
```

Expected: PASS. (Other reviewers have no per-agent structural test today.)

- [ ] **Step 8: Commit**

```bash
git add agents/reviewer-code-quality.md agents/reviewer-migration-safety.md agents/reviewer-multitenant-isolation.md agents/reviewer-security.md agents/reviewer-spec.md
git commit -m "feat(agents): add Before-You-Begin + step-0 to reviewer agents

Reviewers previously went straight from Per-Call Context to checklist
content; they now have a 'Before You Begin' section whose step 0 is
the using-project-knowledge invocation. 10 / 12 agents now carry the
invocation; curator (Task 8) and reviser (Task 9) round out the set."
```

---

### Task 8: Curator vetting changes + step-0 + extended report shape

**Files:**
- Modify: `agents/curator.md` (add "Before You Begin", pre-write vetting step, source emission rule, extended report shape, anti-pattern)
- Modify: `tests/curator/test-structure.sh` (extend assertions)

This is the biggest single agent edit. The curator gains: (a) step-0 in a new "Before You Begin", (b) a new pre-write vetting step in "Your Job" between "identify candidates" and "write entries", (c) `**Source:** <value>` as a mandatory entry line, (d) a structured "Flagged for review" section in the report, (e) an explicit anti-pattern against silent downgrade of contradictions.

We extend the structural test first (RED), then update the agent body (GREEN).

- [ ] **Step 1: Extend `tests/curator/test-structure.sh` with new assertions (RED)**

Edit `tests/curator/test-structure.sh`. Append these assertions after the existing assertions (before the `echo ""; echo "Results: ..."` block):

```bash
# --- New assertions for vetting layer ---

# Step 0: using-project-knowledge invocation
assert_grep "$AGENT" 'Before You Begin' "section: Before You Begin (new)"
assert_grep "$AGENT" 'superpowers:using-project-knowledge' "step 0: using-project-knowledge invocation"

# Pre-write vetting step
assert_grep "$AGENT" '[Pp]re-write vetting|vetting.*per candidate|vet.*candidate' "vetting: pre-write step present"
assert_grep "$AGENT" 'mcp__exa__|mcp__ref__' "vetting: MCP prefix detection documented"
assert_grep "$AGENT" 'exa/Ref unavailable|exa.Ref unavailable' "vetting: degraded-mode phrase present"

# Three classifications
assert_grep "$AGENT" 'Confirms|Confirmed' "vetting: Confirms classification"
assert_grep "$AGENT" 'No relevant hit|no relevant hit|Unvetted' "vetting: Unvetted classification"
assert_grep "$AGENT" 'Contradicts|Contradicted' "vetting: Contradicts classification"

# **Source:** emission rule
assert_grep "$AGENT" '\*\*Source:\*\*' "Source line: emission rule present"
assert_grep "$AGENT" 'observed_locally_unvetted' "Source: observed_locally_unvetted form documented"
assert_grep "$AGENT" 'http://|https://|<URL>' "Source: URL form documented"

# Extended report — Flagged for review block when contradictions
assert_grep "$AGENT" 'Flagged for review|Flagged for user review' "report: Flagged-for-review block"
assert_grep "$AGENT" 'NOT written|not written|did not write' "report: Flagged entries NOT written"

# Anti-pattern: no silent downgrade
assert_grep "$AGENT" 'silently downgrade|silent downgrade|silently mark as observed_locally_unvetted' "anti-pattern: no silent downgrade of contradictions"
```

Run the test to confirm it now fails (RED):

```bash
bash tests/curator/test-structure.sh
```

Expected: FAIL on each of the new assertions.

- [ ] **Step 2: Update `agents/curator.md` — add "Before You Begin" + step 0**

Edit `agents/curator.md`. Insert a new section between `## Per-Call Context` and `## Your Job`:

```markdown
## Before You Begin

0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context. This gives you situational awareness; it does NOT replace your `EXISTING_INDEX` per-call field — you use `EXISTING_INDEX` (the verbatim INDEX content) for deduplication decisions when deciding APPEND vs CREATE.

Verify all 8 Per-Call Context fields are populated before starting. If any is missing or empty, return NEEDS_CONTEXT and name the gap.
```

- [ ] **Step 3: Update `agents/curator.md` — add pre-write vetting step in "Your Job"**

Locate the existing `## Your Job` section. After item 3 (`Identify candidate learnings`) and before item 4 (`For each candidate, decide APPEND ...`), insert a new item 4 (renumber 4-9 to 5-10):

```markdown
4. **Pre-write vetting per candidate.** Ground each candidate against canonical sources before writing.

   a. **Detect available MCPs.** Inspect available tools for any prefixed `mcp__exa__` or `mcp__ref__`. If neither family is available, skip vetting; every entry written in this run will carry `**Source:** observed_locally_unvetted (vetting skipped — exa/Ref unavailable)`, and the report will note "vetting skipped — exa/Ref unavailable" once at the top. Continue normally.

   b. **Construct a focused search query** combining (i) the library/framework name (from the entry body, diff paths, or topic) and (ii) the specific API/decorator/config under discussion. Examples: `starlette BaseHTTPMiddleware ContextVar`; `FastAPI Depends override testing`.

   c. **Run the search via the available MCP.** Read the top 1-3 results (use `WebFetch` for deeper reads if needed). Classify against the candidate's claim:
      - **Confirms** — canonical source aligns with the entry. Record the canonical URL; this entry will be written with `**Source:** <URL>`.
      - **No relevant hit** (Unvetted) — entry captures local observation; canonical source is silent. This entry will be written with `**Source:** observed_locally_unvetted`.
      - **Contradicts** — canonical source explicitly recommends against the entry's claim. DO NOT WRITE this entry. Add it to the report's "Flagged for review" block with the contradicting URL and a 1-2 line summary of canonical guidance. Continue with other candidates.

   d. **On MCP search error** (timeout, mid-run failure): bucket this entry as Unvetted with `**Source:** observed_locally_unvetted (vetting error)`. Do not abort the run.
```

- [ ] **Step 4: Update `agents/curator.md` — add `**Source:**` to the entry-writing step**

Locate item 5 (originally 4, then renumbered) — "Write entries". Append a new bullet to its style list:

```markdown
   - End every entry with a `**Source:**` line — one of: `**Source:** <URL>`, `**Source:** observed_locally_unvetted`, or `**Source:** observed_locally_unvetted (<short hint>)`. Determined by the vetting classification from step 4.
```

- [ ] **Step 5: Update `agents/curator.md` — extend "Report Format" with Flagged-for-review block**

Locate the `## Report Format` section. After the existing "Flagged for user review — entries you're unsure about (categorization, style, accuracy)" line, append:

```markdown

When candidates were contradicted by canonical sources (step 4c), surface a structured block of contradictions — these entries were NOT written:

```
Flagged for review (N entries — NOT written):

- gotchas/middleware.md · 2026-05-12 — BaseHTTPMiddleware ContextVar issue
  Contradicts: https://www.starlette.io/middleware/#pure-asgi-middleware
  Canonical guidance: Starlette docs explicitly recommend pure ASGI middleware
  for anything stateful; BaseHTTPMiddleware is documented as having TaskGroup
  limitations.
  Candidate text (not written):
    <verbatim text the curator was about to write>
```

The dispatching skill surfaces this interactively for user resolution.
```

- [ ] **Step 6: Update `agents/curator.md` — add anti-pattern against silent downgrade**

Locate the `## Anti-Patterns — What NOT to Do` section. Under the "DO NOT:" list, append a new bullet:

```markdown
- Silently downgrade a contradicted entry to `observed_locally_unvetted` and write it anyway. Contradictions are user-in-the-loop signals — surface them in "Flagged for review", do NOT write them as if they were Unvetted.
```

- [ ] **Step 7: Run `tests/curator/test-structure.sh` to verify GREEN**

```bash
bash tests/curator/test-structure.sh
```

Expected: all assertions (including the new ones) PASS.

- [ ] **Step 8: Sanity-check current INDEX field count unchanged**

The spec preserves `EXISTING_INDEX` as a per-call field. Confirm:

```bash
grep -c 'EXISTING_INDEX' agents/curator.md
```

Expected: ≥ 1 occurrence (the field is still declared in Per-Call Context).

- [ ] **Step 9: Commit**

```bash
git add agents/curator.md tests/curator/test-structure.sh
git commit -m "feat(curator): pre-write vetting + **Source:** emission + step-0

Adds:
- Step 0 in new Before-You-Begin: superpowers:using-project-knowledge
  (additive to EXISTING_INDEX, which stays for deduplication)
- Pre-write vetting per candidate: MCP detect (exa/Ref prefix) → search
  → classify (Confirms / Unvetted / Contradicts) → emit **Source:**
  accordingly
- Mandatory **Source:** line on every entry (URL / observed_locally_unvetted
  / observed_locally_unvetted (hint))
- Extended report: structured 'Flagged for review' block when canonical
  sources contradict candidates (entries NOT written)
- Anti-pattern: no silent downgrade of contradictions to unvetted

11 / 12 agents now carry the using-project-knowledge invocation."
```

---

### Task 9: `reviser` agent + structural test + integration test scaffold

**Files:**
- Create: `agents/reviser.md`
- Create: `tests/reviser/test-structure.sh`
- Create: `tests/reviser/fixtures/contradicted-entry.md`
- Create: `tests/reviser/test-integration.sh`
- Modify: `agents/README.md` (librarian family row gains reviser; per-call fields table gains reviser row)

The reviser is a librarian-family agent (sibling to curator). It takes one contradicted entry + canonical URL/summary, fetches the URL, and rewrites the entry in place. Preserves H3 date + since-SHA verbatim — only the recommended response moves.

- [ ] **Step 1: Write the failing structural test**

Create `tests/reviser/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for reviser agent.
# Pure grep + file existence checks. Cross-file checks for vetting-knowledge.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/reviser.md"
FIX="$SCRIPT_DIR/fixtures"
README="$REPO_ROOT/agents/README.md"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

assert_file() {
    local path="$1" name="$2"
    if [ -f "$path" ]; then pass "$name exists"; else fail "$name missing: $path"; fi
}

assert_grep() {
    local path="$1" pattern="$2" name="$3"
    if grep -qE "$pattern" "$path" 2>/dev/null; then
        pass "$name"
    else
        fail "$name (pattern '/$pattern/' not in $path)"
    fi
}

echo "========================================"
echo " reviser: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/reviser.md"
assert_grep "$AGENT" '^name: reviser$' "frontmatter: name=reviser"
assert_grep "$AGENT" '^color: teal$' "frontmatter: color=teal (librarian palette)"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Before You Begin' "section: Before You Begin"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"

# Step-0 invocation
assert_grep "$AGENT" 'superpowers:using-project-knowledge' "step 0: using-project-knowledge"

# Required per-call context fields (all 5)
for field in ENTRY_PATH ENTRY_TITLE CURRENT_ENTRY_TEXT CANONICAL_URL CANONICAL_SUMMARY; do
    assert_grep "$AGENT" "$field" "context field: $field"
done

# Job behavior
assert_grep "$AGENT" 'WebFetch.*CANONICAL_URL|fetch.*CANONICAL_URL|WebFetch\(CANONICAL_URL\)' "job: fetches CANONICAL_URL"
assert_grep "$AGENT" '[Pp]reserve.*H3|preserve.*date|H3.*verbatim' "job: preserves H3 date verbatim"
assert_grep "$AGENT" 'since.*SHA|since-SHA' "job: preserves since-SHA"
assert_grep "$AGENT" '\*\*Source:\*\* .*CANONICAL_URL|Source.*matches.*CANONICAL_URL' "job: Source line matches CANONICAL_URL"
assert_grep "$AGENT" 'in place|replace.*entry.*in place' "job: replaces entry in place"

# Anti-patterns (all required)
assert_grep "$AGENT" '[Dd]o NOT.*change the H3 date|do not change.*H3' "anti-pattern: do not change H3 date"
assert_grep "$AGENT" '[Dd]o NOT.*modify other entries|not modify other entries|not touch surrounding' "anti-pattern: do not modify other entries"
assert_grep "$AGENT" '[Dd]o NOT modify.*INDEX|not modify.*INDEX\.md|not touch.*INDEX' "anti-pattern: do not modify INDEX"
assert_grep "$AGENT" '[Dd]o NOT escalate.*BLOCKED:ARCHITECTURAL|never emit.*BLOCKED:ARCHITECTURAL|does NOT emit.*BLOCKED:ARCHITECTURAL' "anti-pattern: no architect escalation"

# Status verdicts
assert_grep "$AGENT" 'DONE' "verdict: DONE"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "verdict: NEEDS_CONTEXT"

# Fixture presence
assert_file "$FIX/contradicted-entry.md" "fixture: contradicted-entry.md"

# Cross-file: agents/README.md librarian row mentions reviser
assert_grep "$README" 'reviser' "README.md: librarian family mentions reviser"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

Make executable:

```bash
chmod +x tests/reviser/test-structure.sh
```

- [ ] **Step 2: Create the test fixture**

Create `tests/reviser/fixtures/contradicted-entry.md`:

```markdown
# Fixture: contradicted entry for reviser integration test

## ENTRY_PATH

knowledge/patterns/auth.md

## ENTRY_TITLE

2026-04-22 — Session shape and role checks

## CURRENT_ENTRY_TEXT

```markdown
### 2026-04-22 — Session shape and role checks (since b1d2c3a)

Use the request-level session object directly via `request.state.session`
to check the user role. Mutate it in middleware to flow auth context to
handlers.

**Why:** middleware can populate it once per request; handlers read it.

**Avoid:** dependency injection for session — extra indirection.

**Source:** observed_locally_unvetted
```

## CANONICAL_URL

https://fastapi.tiangolo.com/tutorial/dependencies/sub-dependencies/

## CANONICAL_SUMMARY

FastAPI documentation explicitly recommends dependency-injection-based
session retrieval (`Depends(get_current_session)`) for testability and
override semantics. Direct mutation of `request.state` is documented as
escape-hatch behavior for ASGI middleware integration, not the default
pattern.

## EXPECTED REVISER BEHAVIOR (not asserted by structural test)

The reviser should:
1. Fetch CANONICAL_URL via WebFetch
2. Rewrite the entry, preserving the H3 header `### 2026-04-22 — Session shape and role checks (since b1d2c3a)` verbatim
3. Replace the body to recommend `Depends(get_current_session)` over direct `request.state.session` access
4. End the entry with `**Source:** https://fastapi.tiangolo.com/tutorial/dependencies/sub-dependencies/`
5. Not modify any other entry in the same file, and not touch INDEX.md
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
bash tests/reviser/test-structure.sh
```

Expected: FAIL — agent file missing, fixture missing, README.md doesn't mention reviser yet.

- [ ] **Step 4: Create `agents/reviser.md`**

Create the file with this body:

```markdown
---
name: reviser
description: Use to rewrite a single knowledge entry that contradicts canonical guidance, aligning it with the canonical source. Dispatched by superpowers:vetting-knowledge per contradicted entry; user reviews diff before commit.
color: teal
model: opus
effort: xhigh
---

You are a librarian subagent. The vetting layer found that one entry in the project's `knowledge/` directory contradicts canonical guidance from an upstream documentation source. Your job is to rewrite that one entry to align with the canonical source — preserving the entry's identity (H3 date and since-SHA) and leaving every other entry untouched.

## Per-Call Context

The dispatcher provides five pieces of per-call context in your prompt:

- **ENTRY_PATH** — file path of the topic, e.g. `knowledge/patterns/auth.md`
- **ENTRY_TITLE** — exact dated H3 header text, e.g. `2026-04-22 — Session shape and role checks`
- **CURRENT_ENTRY_TEXT** — verbatim body of the entry currently on disk
- **CANONICAL_URL** — URL of the contradicting canonical source
- **CANONICAL_SUMMARY** — 2-3 sentence summary of what the canonical guidance says

If any are missing or unclear, return NEEDS_CONTEXT with the gap named.

## Before You Begin

0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context. This gives you the surrounding patterns/gotchas; you'll touch only one entry but you want awareness of related ones to flag conflicts in self-review.

Verify all 5 Per-Call Context fields are populated.

## Your Job

1. **Verify the contradiction.** `WebFetch(CANONICAL_URL)` and read the relevant section of the canonical page. Confirm CANONICAL_SUMMARY matches what you see there. If the summary mischaracterizes the canonical source (e.g., the page actually supports the entry or is silent on it), return `NEEDS_CONTEXT` with a precise gap description. Do NOT fabricate an alignment to a misread source.

2. **Read ENTRY_PATH in full** with the `Read` tool. This shows you the surrounding entries — preserve style and formatting conventions (the **Why:** / **Avoid:** / **Source:** body shape).

3. **Draft new entry text** that:
   - **Preserves the dated H3 header verbatim** — `### YYYY-MM-DD — <title> (since <SHA>)`. Same date and same `since` SHA as the original. The observation hasn't moved; only the recommended response has.
   - **Rewrites the body** to reflect canonical guidance.
   - Keeps the `**Why:**` line if the root cause still applies; otherwise replace.
   - Updates the `**Avoid:**` / `**Use:**` line to match the canonical prescription.
   - **Ends with `**Source:** <CANONICAL_URL>`** — the audit trail. The source line MUST match CANONICAL_URL exactly.

4. **Replace the existing entry in place** in ENTRY_PATH using the `Edit` tool. The old `### ENTRY_TITLE` H3 block (header + body, ending before the next `### ` header or EOF) becomes the new H3 block with the same header and the new body. Do not touch surrounding entries, frontmatter, or `INDEX.md`.

5. **Self-review** before reporting back:
   - Is the `**Source:**` line present and exactly equal to CANONICAL_URL?
   - Entry ≤ 200 words?
   - Text reflects canonical guidance — no hedging?
   - H3 date and since-SHA preserved verbatim?
   - Did any other entry in the same topic just become inconsistent with the new text? If so, flag it (the user may need a separate revise pass).

## When You're in Over Your Head

It is OK to return NEEDS_CONTEXT rather than fabricate. Bad rewrites are worse than no rewrite.

**STOP and return NEEDS_CONTEXT when:**
- `WebFetch(CANONICAL_URL)` fails or returns content unrelated to CANONICAL_SUMMARY
- The canonical page is silent on the entry's claim (so there's no contradiction to align with — the entry should remain unvetted, not revised)
- The right action is entry deletion, not rewrite (canonical says "this issue doesn't exist") — out of reviser scope; surface to user
- CANONICAL_SUMMARY clearly mischaracterizes what the canonical source actually says

**DO NOT escalate `BLOCKED:ARCHITECTURAL`** — librarian agents don't have that path. Return `NEEDS_CONTEXT` with the gap described.

## Report Format

When done, report:

- **Status:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT
- **Files touched** — just ENTRY_PATH
- **One-line summary** of the change ("rewrote to recommend dependency injection over request.state mutation")
- **Self-review findings** — any conflicts with other entries in the same topic; flag for user follow-up
- End with exactly one of:
  - **Verdict: DONE — entry revised**
  - **Verdict: DONE_WITH_CONCERNS — entry revised, see self-review notes**
  - **Verdict: NEEDS_CONTEXT — <field-name or gap-description>**

## Anti-Patterns — What NOT to Do

**DO:**
- WebFetch and read the canonical source before rewriting
- Preserve the H3 date and since-SHA verbatim — those record when the observation was made, not when the recommendation was last reviewed
- End the new entry with `**Source:** <CANONICAL_URL>` exactly
- Flag conflicts with other entries in self-review

**DO NOT:**
- Change the H3 date or since-SHA — they're load-bearing; the observation didn't move
- Add meta-commentary in the entry body ("originally said X, now updated to Y"). The `**Source:**` line is the audit trail; git history is the rest
- Modify other entries in the same file, even if they look stale — surface them in self-review and let the user decide
- Modify `knowledge/INDEX.md` (entry title/slug isn't changing on a revision; INDEX stays)
- Escalate `BLOCKED:ARCHITECTURAL` — librarian agents don't have that path; return NEEDS_CONTEXT instead
- Fabricate alignment to a canonical source you couldn't read or whose content didn't match CANONICAL_SUMMARY
```

- [ ] **Step 5: Update `agents/README.md` — add reviser to the librarian family**

Edit `agents/README.md`. Find the "Agent families" table. Update the Librarian row to mention reviser:

```markdown
| Librarian | `curator`, `reviser` | teal / cyan | Distills project patterns + gotchas into `knowledge/` from completed branches (`curator`); rewrites contradicted entries to align with canonical guidance (`reviser`) |
```

Find the "Per-call context fields by agent" table. Append a row for reviser:

```markdown
| `reviser` | ENTRY_PATH, ENTRY_TITLE, CURRENT_ENTRY_TEXT, CANONICAL_URL, CANONICAL_SUMMARY |
```

Find the "Files in this directory" table. Append a row:

```markdown
| `reviser.md` | Rewrites one contradicted knowledge entry to align with canonical guidance |
```

- [ ] **Step 6: Create the integration test scaffold**

Create `tests/reviser/test-integration.sh`:

```bash
#!/usr/bin/env bash
# Integration test for reviser agent.
# Dispatches via `claude` CLI; verifies the agent (a) preserves H3 header
# verbatim, (b) updates **Source:** to CANONICAL_URL, (c) doesn't modify
# any other entry in the same file.
#
# Requires: claude CLI on PATH, network access for WebFetch.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

if ! command -v claude >/dev/null 2>&1; then
    echo "  [SKIP] integration test: claude CLI not on PATH"
    exit 0
fi

# Set up a working knowledge tree with one contradicted entry
WORK=$(mktemp -d)
mkdir -p "$WORK/knowledge/patterns"
cat > "$WORK/knowledge/INDEX.md" <<'EOF'
# Knowledge Index

## Patterns

- **auth** — Sample auth pattern — `patterns/auth.md`
EOF

cat > "$WORK/knowledge/patterns/auth.md" <<'EOF'
---
topic: auth
category: patterns
last-updated: 2026-04-22
last-since: b1d2c3a
---

# Auth patterns

## Entries

### 2026-04-22 — Session shape and role checks (since b1d2c3a)

Use the request-level session object directly via `request.state.session`
to check the user role.

**Why:** middleware can populate it once per request; handlers read it.

**Avoid:** dependency injection for session — extra indirection.

**Source:** observed_locally_unvetted

### 2026-04-23 — Other entry that must stay untouched (since c2d3e4f)

This entry has unrelated content and must not be modified by the reviser.

**Why:** scoping check.

**Avoid:** modifying any entry other than the one named in ENTRY_TITLE.

**Source:** observed_locally_unvetted
EOF

# Snapshot the second entry's content for change-detection
snap_other=$(awk '/^### 2026-04-23/,/^### |^$/' "$WORK/knowledge/patterns/auth.md")

# Build the per-call context block and dispatch the reviser via claude
PROMPT=$(cat <<'EOF'
You are dispatched as the reviser subagent.

ENTRY_PATH: WORK_PLACEHOLDER/knowledge/patterns/auth.md
ENTRY_TITLE: 2026-04-22 — Session shape and role checks
CURRENT_ENTRY_TEXT: |
  ### 2026-04-22 — Session shape and role checks (since b1d2c3a)

  Use the request-level session object directly via `request.state.session`
  to check the user role.

  **Why:** middleware can populate it once per request; handlers read it.

  **Avoid:** dependency injection for session — extra indirection.

  **Source:** observed_locally_unvetted
CANONICAL_URL: https://fastapi.tiangolo.com/tutorial/dependencies/
CANONICAL_SUMMARY: FastAPI canonical guidance recommends dependency-injection-based session retrieval via Depends(...) for testability and override semantics.

Rewrite the entry in place and report back.
EOF
)
PROMPT="${PROMPT//WORK_PLACEHOLDER/$WORK}"

# Dispatch via claude CLI subagent_type=reviser
# (Exact CLI invocation may vary across versions; this is a smoke test scaffold.)
output=$(echo "$PROMPT" | claude --subagent reviser 2>&1 || true)

# Assertions:
# (1) H3 header preserved verbatim
if grep -q '^### 2026-04-22 — Session shape and role checks (since b1d2c3a)$' "$WORK/knowledge/patterns/auth.md"; then
    pass "H3 header preserved verbatim"
else
    fail "H3 header was changed (date or since-SHA modified)"
fi

# (2) Source line updated to CANONICAL_URL
if grep -q '^\*\*Source:\*\* https://fastapi.tiangolo.com' "$WORK/knowledge/patterns/auth.md"; then
    pass "Source line updated to CANONICAL_URL"
else
    fail "Source line not updated to CANONICAL_URL"
fi

# (3) Other entry left untouched
snap_other_after=$(awk '/^### 2026-04-23/,/^### |^$/' "$WORK/knowledge/patterns/auth.md")
if [ "$snap_other" = "$snap_other_after" ]; then
    pass "other entry left untouched"
else
    fail "other entry was modified"
fi

rm -rf "$WORK"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

Make executable:

```bash
chmod +x tests/reviser/test-integration.sh
```

Note: this integration test is best-effort — the exact `claude --subagent` invocation may need adjustment for the current CLI surface. If `claude --subagent reviser` isn't the right shape, the test should print SKIP and exit 0 (or fail gracefully so it doesn't block the rest of the suite).

- [ ] **Step 7: Run the structural test to verify GREEN**

```bash
bash tests/reviser/test-structure.sh
```

Expected: PASS for all assertions.

- [ ] **Step 8: Commit**

```bash
git add agents/reviser.md agents/README.md tests/reviser/
git commit -m "feat(agents): add reviser librarian agent

Sibling to curator. Takes one contradicted knowledge entry + canonical
URL/summary, fetches the URL, rewrites the entry in place. Preserves
the H3 date and since-SHA verbatim; only the recommended response
moves. Does NOT modify INDEX or other entries.

Five per-call fields: ENTRY_PATH, ENTRY_TITLE, CURRENT_ENTRY_TEXT,
CANONICAL_URL, CANONICAL_SUMMARY.

12 / 12 agents now carry the using-project-knowledge invocation."
```

---

### Task 10: `vetting-knowledge` skill + structural test + integration test scaffold

**Files:**
- Create: `skills/vetting-knowledge/SKILL.md`
- Create: `tests/vetting-knowledge/test-structure.sh`
- Create: `tests/vetting-knowledge/fixtures/sample-knowledge/INDEX.md`
- Create: `tests/vetting-knowledge/fixtures/sample-knowledge/patterns/sample.md`
- Create: `tests/vetting-knowledge/test-integration.sh`

The skill body is large (8 steps from the spec). We follow the spec's structure verbatim. The structural test asserts the step ordering, report frontmatter shape, per-call block to reviser, degraded-mode handling.

- [ ] **Step 1: Write the failing structural test**

Create `tests/vetting-knowledge/test-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural test for vetting-knowledge skill.
# Pure grep + file existence checks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/vetting-knowledge/SKILL.md"
FIX="$SCRIPT_DIR/fixtures/sample-knowledge"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

assert_file() {
    local path="$1" name="$2"
    if [ -f "$path" ]; then pass "$name exists"; else fail "$name missing: $path"; fi
}

assert_grep() {
    local path="$1" pattern="$2" name="$3"
    if grep -qE "$pattern" "$path" 2>/dev/null; then
        pass "$name"
    else
        fail "$name (pattern '/$pattern/' not in $path)"
    fi
}

echo "========================================"
echo " vetting-knowledge: structural tests"
echo "========================================"

# Skill file presence and frontmatter
assert_file "$SKILL" "skills/vetting-knowledge/SKILL.md"
assert_grep "$SKILL" '^name: vetting-knowledge$' "frontmatter: name=vetting-knowledge"
assert_grep "$SKILL" '^description: Use to audit' "frontmatter: description starts with 'Use to audit'"
assert_grep "$SKILL" 'Announce at start' "skill announces itself at start"

# Required steps (1-8 in order) — assert presence
for label in 'Preflight' 'Enumerate' 'Vet each entry' '[Cc]odebase grep' 'Write the report' '[Ss]urface results' 'Fix loop' 'Async resume'; do
    assert_grep "$SKILL" "$label" "step present: $label"
done

# MCP detection
assert_grep "$SKILL" 'mcp__exa__|mcp__ref__' "MCP detection: exa/Ref prefixes"
assert_grep "$SKILL" 'exa.Ref unavailable|degraded' "degraded-mode language"

# Classifications
assert_grep "$SKILL" 'Confirmed|confirmed' "classification: Confirmed"
assert_grep "$SKILL" 'Unvetted|unvetted' "classification: Unvetted"
assert_grep "$SKILL" 'Contradicted|contradicted' "classification: Contradicted"

# Report path + filename format
assert_grep "$SKILL" '_meta/vetting-reports' "report path: _meta/vetting-reports/"
assert_grep "$SKILL" 'YYYY-MM-DDTHHMMSSZ|ISO|sortable' "report filename: ISO-sortable timestamp"

# Report frontmatter shape
assert_grep "$SKILL" 'generated:|mcps_used:|buckets:' "report frontmatter: machine-readable YAML"
assert_grep "$SKILL" 'confirmed:|unvetted:|contradicted:' "report frontmatter: bucket counts"
assert_grep "$SKILL" 'contradicted:' "report frontmatter: contradicted[] list"

# Per-call block to reviser (5 fields)
for field in ENTRY_PATH ENTRY_TITLE CURRENT_ENTRY_TEXT CANONICAL_URL CANONICAL_SUMMARY; do
    assert_grep "$SKILL" "$field" "reviser per-call field: $field"
done
assert_grep "$SKILL" 'subagent_type=reviser|Task\(subagent_type=reviser' "reviser dispatch: subagent_type=reviser"

# Async resume
assert_grep "$SKILL" 'apply fixes from|async resume' "async resume documented"

# Anti-patterns
assert_grep "$SKILL" 'DO NOT auto-commit|do not auto-commit' "anti-pattern: no auto-commit"
assert_grep "$SKILL" '[Dd]o NOT modify .*INDEX|not modify INDEX' "anti-pattern: do not modify INDEX"
assert_grep "$SKILL" '_meta' "anti-pattern: do not vet _meta/"

# Fixture presence
assert_file "$FIX/INDEX.md" "integration fixture: INDEX.md"
assert_file "$FIX/patterns/sample.md" "integration fixture: sample topic"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

Make executable:

```bash
chmod +x tests/vetting-knowledge/test-structure.sh
```

- [ ] **Step 2: Create the fixture knowledge tree**

Create `tests/vetting-knowledge/fixtures/sample-knowledge/INDEX.md`:

```markdown
# Knowledge Index

## Patterns

- **sample** — Sample patterns topic for vetting integration test — `patterns/sample.md`
```

Create `tests/vetting-knowledge/fixtures/sample-knowledge/patterns/sample.md`:

```markdown
---
topic: sample
category: patterns
last-updated: 2026-05-01
last-since: abc1234
---

# Sample patterns

## Entries

### 2026-05-01 — Sample observation (since abc1234)

A sample observation captured during a fixture run.

**Why:** placeholder.

**Avoid:** treating this as real guidance — it's a test fixture.

**Source:** observed_locally_unvetted
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
bash tests/vetting-knowledge/test-structure.sh
```

Expected: FAIL — skill body doesn't exist yet.

- [ ] **Step 4: Write the skill body**

Create `skills/vetting-knowledge/SKILL.md`:

```markdown
---
name: vetting-knowledge
description: Use to audit every entry in knowledge/ against canonical sources (via exa/Ref MCPs), producing a timestamped report grouping entries by confirmed/unvetted/contradicted. Offers to dispatch the reviser agent per contradicted entry. Typically run before stack version bumps, after major library upgrades, or quarterly.
---

# Vetting Knowledge

## Overview

On-demand audit of the project's `knowledge/` directory. Walks every entry, runs a focused canonical search per entry via the available exa/Ref MCPs, classifies into Confirmed / Unvetted / Contradicted, writes a timestamped report, and offers to dispatch the `reviser` agent per contradicted entry.

**Announce at start:** "I'm using the vetting-knowledge skill to audit the project's knowledge directory."

## The Process

### Step 1: Preflight

1. Verify `./knowledge/INDEX.md` exists. If not, report `Project has no knowledge/ directory; nothing to vet` and exit clean.
2. Detect available MCPs by inspecting tools for `mcp__exa__*` and `mcp__ref__*` prefixes. Record which families are available.
   - If neither family is available: surface `exa/Ref unavailable — all entries will be bucketed as unvetted (degraded mode)` and continue.
3. Resolve current HEAD SHA for the report header:

   ```bash
   HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "no-git")
   ```

### Step 2: Enumerate

Walk `INDEX.md`. For each listed topic (`- **<slug>** — <hook> — \`<category>/<slug>.md\``), read the topic file. Parse each dated H3 entry into a tuple:

```
{
  entry_path: knowledge/<category>/<slug>.md
  entry_title: 2026-04-22 — Session shape and role checks
  entry_text:  <body of the entry, between this ### and the next ###>
  current_source: <value from the entry's **Source:** line>
}
```

### Step 3: Vet each entry (per-entry loop)

For each enumerated entry:

1. **Construct a focused search query** from the topic name + identifiers in the entry body (CamelCase tokens, snake_case tokens, dotted import paths). Example: `starlette BaseHTTPMiddleware ContextVar`.

2. **If exa/Ref unavailable** → classify as `Unvetted (no search available)`. Skip to next entry.

3. **Run the search** via the available MCP. Read the top 1-3 results. Use `WebFetch` for deeper reads if the search-result snippet is insufficient.

4. **Classify** based on the canonical content vs. the entry's claim:
   - **Confirmed** — canonical aligns with entry. Record URL.
   - **Unvetted** — no relevant canonical hit. Record the search query (for the report).
   - **Contradicted** — canonical explicitly contradicts. Record URL + a 2-3 sentence summary of canonical guidance.

5. **On search error** (timeout, MCP failure mid-run) → bucket the entry as `Unvetted (vetting error)` with the error noted. Continue.

### Step 4: Best-effort codebase grep

For each entry, grep the project tree (excluding `knowledge/`, `docs/`, `tests/`) for identifiers in the entry body. Surface the file count + paths in the report under `files_referencing`. For contradicted entries this is the "may need code review" flag.

Best-effort: skip silently if too slow (no user prompt). False positives and false negatives are both acceptable — the precision contract is loose.

### Step 5: Write the report

Path: `knowledge/_meta/vetting-reports/<ISO-timestamp>.md`. Filename format `YYYY-MM-DDTHHMMSSZ.md` — Windows-safe (no colons), ISO-sortable.

```bash
mkdir -p knowledge/_meta/vetting-reports
TS=$(date -u +%Y-%m-%dT%H%M%SZ)
REPORT="knowledge/_meta/vetting-reports/${TS}.md"
```

Report structure: YAML frontmatter for machine parsing + Markdown body for humans.

```markdown
---
generated: 2026-05-12T14:23:00Z
generated_at_sha: abc1234
mcps_used: [exa]
mcps_unavailable: [ref]
buckets:
  confirmed: 12
  unvetted: 5
  contradicted: 1
contradicted:
  - entry_path: knowledge/patterns/auth.md
    entry_title: "2026-04-22 — Session shape and role checks"
    canonical_url: https://fastapi.tiangolo.com/.../sessions
    canonical_summary: |
      FastAPI deprecated the pattern in v0.110 in favor of dependency-
      injection-based session retrieval.
    files_referencing:
      - src/auth/middleware.py
      - src/auth/decorators.py
---

# Knowledge vetting report

Generated: 2026-05-12T14:23:00Z (HEAD abc1234)
Confirmed: 12   Unvetted: 5   Contradicted: 1

## Contradicted (review required)

### patterns/auth.md · 2026-04-22 — Session shape and role checks

- **Contradicts:** https://fastapi.tiangolo.com/.../sessions
- **Canonical guidance:** FastAPI deprecated the pattern in v0.110 in favor
  of dependency-injection-based session retrieval.
- **Files referencing this pattern (codebase grep):**
  - src/auth/middleware.py
  - src/auth/decorators.py
- **Current entry text:**

  ```
  <verbatim entry body>
  ```

## Unvetted

- gotchas/middleware.md · 2026-05-11 — BaseHTTPMiddleware ContextVar issue
  - Search query: `starlette BaseHTTPMiddleware ContextVar`
  - No relevant canonical hit; observation may be genuinely local-only.

## Confirmed

- patterns/repo-conventions.md · 2026-05-11 — Base-branch fallback chain
  - Confirmed by: <URL>
```

The `_meta/vetting-reports/` directory should be gitignored by default — consuming projects opt in by removing the entry if they want history committed.

### Step 6: Surface results in chat + offer fix loop

```
Vetting complete. Report: knowledge/_meta/vetting-reports/<filename>
  Confirmed: <N> / Unvetted: <M> / Contradicted: <K>

<K> contradicted entries found:
- patterns/auth.md · 2026-04-22 — Session shape and role checks
  Contradicts: https://fastapi.tiangolo.com/.../sessions

Dispatch reviser now to propose rewrites? [y / n / later]
```

- `y` → proceed to Step 7 (fix loop) immediately.
- `n` → done.
- `later` → done; the report persists for async resume (Step 8).

### Step 7: Fix loop (immediate or async)

For each entry in the report's `contradicted[]` list:

1. **Re-read CURRENT_ENTRY_TEXT** fresh from disk (in case the file has changed since the report was generated). If the on-disk text differs significantly from the report's snapshot, warn the user but proceed.

2. **Build the reviser's per-call context block** (5 fields) and dispatch:

   ```
   Task(
     subagent_type=reviser,
     description="Revise contradicted entry: <ENTRY_TITLE>",
     prompt=<per-call block below>
   )
   ```

   Per-call block:

   ```
   ENTRY_PATH: <path from report>
   ENTRY_TITLE: <title from report>
   CURRENT_ENTRY_TEXT: <verbatim re-read from disk>
   CANONICAL_URL: <from report>
   CANONICAL_SUMMARY: <from report>
   ```

3. **On reviser DONE** → run `git diff <ENTRY_PATH>` and prompt:

   ```
   Reviser proposed this rewrite. Options:
     (a) commit as-is
     (b) leave the change unstaged so you can edit further
     (c) discard (git checkout <entry-path>)
   ```

   Execute the user's choice. Move to next contradicted entry.

4. **After all contradicted entries** → summarize what landed (N revised, M edited further, K discarded).

### Step 8: Async resume

The user can invoke later: *"apply fixes from `knowledge/_meta/vetting-reports/<file>.md`"*. The skill loads the report's frontmatter, runs Step 7 against `contradicted[]`. If an entry's current on-disk text has drifted from what the report captured, surface a per-entry warning (the report may itself be stale).

## Anti-Patterns — What NOT to Do

**DO NOT:**
- Auto-commit reviser output — user reviews `git diff` first per entry.
- Modify `INDEX.md` (the reviser doesn't either; the entry slug/hook isn't changing on a revision).
- Delete old report files — retention is the user's call.
- Run vetting against `knowledge/_meta/` (lint reports, vetting reports — they're not knowledge entries).
- Silently swallow MCP search errors — bucket the entry as `Unvetted (vetting error)` with the error noted.
- Refuse to run when exa/Ref are unavailable — degraded mode (all entries → Unvetted) is the intended fallback.
```

- [ ] **Step 5: Create the integration test scaffold**

Create `tests/vetting-knowledge/test-integration.sh`:

```bash
#!/usr/bin/env bash
# Integration test for vetting-knowledge skill (degraded path).
# No MCPs available; verifies report writes with every entry bucketed
# as 'unvetted (no search available)'. Tests the timestamped-filename
# format and frontmatter-parses contract.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIX="$SCRIPT_DIR/fixtures/sample-knowledge"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

if ! command -v claude >/dev/null 2>&1; then
    echo "  [SKIP] integration test: claude CLI not on PATH"
    exit 0
fi

WORK=$(mktemp -d)
cp -R "$FIX" "$WORK/knowledge"

# Invoke the vetting-knowledge skill via claude
# (Use a non-interactive prompt that runs the skill and returns control.)
output=$(cd "$WORK" && echo "Use superpowers:vetting-knowledge to audit ./knowledge. Answer 'n' if asked about the fix loop." | claude 2>&1 || true)

# Assertion 1: report file written with ISO-sortable timestamp filename
report=$(find "$WORK/knowledge/_meta/vetting-reports" -type f -name '*.md' 2>/dev/null | head -1)
if [ -n "$report" ]; then
    pass "report file written"
    # Filename matches YYYY-MM-DDTHHMMSSZ.md
    base=$(basename "$report")
    if echo "$base" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z\.md$'; then
        pass "report filename format: YYYY-MM-DDTHHMMSSZ.md"
    else
        fail "report filename format: got $base"
    fi
else
    fail "no report file written"
fi

# Assertion 2: report has YAML frontmatter with required keys
if [ -n "$report" ]; then
    for key in generated mcps_used mcps_unavailable buckets; do
        if grep -q "^${key}:" "$report"; then
            pass "report frontmatter: $key key present"
        else
            fail "report frontmatter: $key key missing"
        fi
    done

    # Degraded mode: every entry bucketed as unvetted
    if grep -qE 'unvetted: [1-9]' "$report"; then
        pass "degraded mode: at least one entry bucketed as unvetted"
    else
        fail "degraded mode: no unvetted entries"
    fi
fi

rm -rf "$WORK"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

Make executable:

```bash
chmod +x tests/vetting-knowledge/test-integration.sh
```

- [ ] **Step 6: Run the structural test to verify GREEN**

```bash
bash tests/vetting-knowledge/test-structure.sh
```

Expected: PASS for all assertions.

- [ ] **Step 7: Commit**

```bash
git add skills/vetting-knowledge/ tests/vetting-knowledge/
git commit -m "feat(skills): add vetting-knowledge audit skill

8-step process per spec: preflight (MCP detect) → enumerate (walk
INDEX + topics) → vet (search per entry; classify Confirmed/Unvetted/
Contradicted) → best-effort codebase grep → write timestamped report
(YAML frontmatter + Markdown body at _meta/vetting-reports/<ISO>.md)
→ surface results + offer fix loop → dispatch reviser per contradicted
entry (with diff-review/commit/discard prompt) → async resume via
'apply fixes from report XYZ'.

Degraded path (no exa/Ref MCPs) is the intended fallback — every entry
bucketed as Unvetted; no failure. Tested via integration scaffold."
```

---

### Task 11: Update dispatcher skills (`finishing-a-development-branch`, `curating-knowledge`, `linting-knowledge`)

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md` (Step 2 — handle "Flagged for review" block)
- Modify: `skills/curating-knowledge/SKILL.md` (Step 3 — same handling)
- Modify: `skills/linting-knowledge/SKILL.md` (Step 2 — surface Check 4b errors)

The curator (Task 8) now emits a structured "Flagged for review" block when canonical sources contradict candidates. The two dispatchers that call the curator must handle this interactively. The lint dispatcher must surface the new check 4b error class.

- [ ] **Step 1: Update `skills/finishing-a-development-branch/SKILL.md` — Step 2 verdict handling**

Edit the file. Find the "Handle the verdict:" block under Step 2 (Capture Knowledge). After the existing `DONE — N entries...` handling and before the `NOTHING_TO_LEARN` handling, insert a new sub-handler for the contradicted case:

```markdown
**If the curator's report includes a "Flagged for review" block** (canonical sources contradicted one or more candidates):

```
The curator wrote N entries and flagged M candidates because canonical
guidance contradicts them. For each one:

  (a) accept canonical, skip the entry (no write — canonical wins)
  (b) write as observed_locally_unvetted (you disagree with canonical;
      the entry lands with a note that vetting was overridden)
  (c) edit to align with canonical (dispatch the reviser agent to
      produce a rewrite aligned with the canonical source)
```

Prompt the user per flagged entry. Execute the chosen option:

- **(a) accept canonical** — no further action; the entry was already not written by the curator. Note it in the branch summary.
- **(b) write as observed_locally_unvetted** — open `<entry_path>` and manually append the entry with `**Source:** observed_locally_unvetted (user override of canonical contradiction at <URL>)` body line.
- **(c) edit to align** — build the reviser's 5-field per-call block and `Task(subagent_type=reviser, ...)`. On reviser DONE, run `git diff <entry_path>` and present the standard commit/edit/discard prompt.

Resolve all flagged entries before proceeding to Step 3. Do not auto-resolve.
```

- [ ] **Step 2: Update `skills/curating-knowledge/SKILL.md` — Step 3 verdict handling**

Edit the file. Step 3 ("Handle the Verdict") today has three bullets (DONE / NOTHING_TO_LEARN / NEEDS_CONTEXT). Append a fourth bullet:

```markdown
- **Flagged for review** (when the curator's report includes a "Flagged for review" block from contradicted candidates) — interactive resolution per flagged entry:

  ```
  The curator wrote N entries and flagged M candidates because canonical
  guidance contradicts them. For each one:
    (a) accept canonical, skip the entry
    (b) write as observed_locally_unvetted (user override)
    (c) edit to align with canonical (dispatch the reviser)
  ```

  Same execution semantics as `finishing-a-development-branch` Step 2 (see that skill for the full per-option behavior).
```

- [ ] **Step 3: Update `skills/linting-knowledge/SKILL.md` — Step 2 surface Check 4b errors**

Edit the file. Find the "Errors" bullet under Step 2 (Parse the Report). Update it to include the new check class:

```markdown
- **Errors** — orphan INDEX hooks, missing frontmatter, dangling since-SHAs, **missing or malformed `**Source:**` lines (Check 4b)**. Must be fixed before next merge.
```

In Step 3 (Surface Findings), add this bullet at the top of the for-each-error guidance:

```markdown
- For missing-Source errors: print the entry's topic-path and title; suggest either (a) re-running curator with vetting (to attempt URL discovery), (b) appending `**Source:** observed_locally_unvetted`, or (c) running `scripts/backfill-knowledge-sources.sh` for bulk backfill.
- For malformed-Source errors: print the topic-path, title, and the offending value; show the three valid forms (URL / `observed_locally_unvetted` / `observed_locally_unvetted (hint)`).
```

- [ ] **Step 4: Verify the changes**

```bash
grep -A 3 'Flagged for review' skills/finishing-a-development-branch/SKILL.md
grep -A 3 'Flagged for review' skills/curating-knowledge/SKILL.md
grep -A 1 'Check 4b\|missing-Source\|malformed-Source' skills/linting-knowledge/SKILL.md
```

Expected: each query returns matching content.

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md skills/curating-knowledge/SKILL.md skills/linting-knowledge/SKILL.md
git commit -m "feat(skills): handle curator 'Flagged for review' + lint Check 4b

- finishing-a-development-branch: Step 2 verdict-handling block now
  surfaces curator's Flagged-for-review (a/b/c) options when canonical
  sources contradict candidates; (c) dispatches reviser
- curating-knowledge: same handling in Step 3
- linting-knowledge: Step 2 lists missing/malformed **Source:** under
  Errors; Step 3 surfaces remediation options (re-curate, manual
  observed_locally_unvetted, bulk backfill)"
```

---

### Task 12: Wire new test paths into the runner

**Files:**
- Modify: `tests/claude-code/run-skill-tests.sh` (extend `tests=(...)` and `integration_tests=(...)`)

Without this wiring, the new structural and integration tests don't run in CI. Constraint 12 requires the runner update to land in the same commit as the test files; in practice we land them together at the end of the branch so the runner doesn't reference paths that don't exist yet partway through. (Each prior task's structural test was run by hand via `bash tests/<name>/test-structure.sh` — the runner registration here closes that loop.)

- [ ] **Step 1: Append new test paths to `tests/claude-code/run-skill-tests.sh`**

Edit the file. Locate the `tests=(...)` array (around line 112). Append four entries:

```bash
    "../using-project-knowledge/test-structure.sh"
    "../reviser/test-structure.sh"
    "../vetting-knowledge/test-structure.sh"
    "../backfill-knowledge-sources/test.sh"
```

Locate the `integration_tests=(...)` array (around line 124). Append three entries:

```bash
    "../using-project-knowledge/test-integration.sh"
    "../reviser/test-integration.sh"
    "../vetting-knowledge/test-integration.sh"
```

Locate the `--help` text block (around line 60-75). Add the new test descriptions under "Tests:" and "Integration Tests:" sections so `--help` output stays accurate. For each test, add a line like:

```
echo "  ../using-project-knowledge/test-structure.sh      Lint using-project-knowledge skill structure"
echo "  ../reviser/test-structure.sh                      Lint reviser agent + cross-file README wiring"
echo "  ../vetting-knowledge/test-structure.sh            Lint vetting-knowledge skill structure"
echo "  ../backfill-knowledge-sources/test.sh             Test backfill script: backfills missing + idempotent"
```

And under integration:

```
echo "  ../using-project-knowledge/test-integration.sh    Skill loads INDEX into agent context"
echo "  ../reviser/test-integration.sh                    Reviser preserves H3 + updates Source"
echo "  ../vetting-knowledge/test-integration.sh          Vetting in degraded mode produces report"
```

- [ ] **Step 2: Run the full test suite**

```bash
bash tests/claude-code/run-skill-tests.sh
```

Expected: all structural tests PASS. Integration tests run only with `--integration`; they're not part of this run.

If a test fails, fix it before proceeding. Common failure modes:

- A structural test you wrote in a prior task references a fixture path that's slightly different from what you created (typo in path) — fix the path in the test.
- A skill file is missing a section the test asserts — go back and add it. Don't loosen the test.

- [ ] **Step 3: Run the lint on this repo's own knowledge — confirm still clean**

```bash
bash scripts/lint-knowledge.sh ./knowledge
echo "exit=$?"
```

Expected: exit 0 (Task 5 backfilled the entries).

- [ ] **Step 4: Commit**

```bash
git add tests/claude-code/run-skill-tests.sh
git commit -m "test: wire new structural + integration tests into runner

Adds 4 new structural tests (using-project-knowledge, reviser,
vetting-knowledge, backfill-knowledge-sources) and 3 new integration
tests (using-project-knowledge, reviser, vetting-knowledge) to the
runner arrays. --help text updated to list each."
```

---

### Task 13: Version bump 5.2.0 → 5.3.0 + RELEASE-NOTES

**Files:**
- Modify: `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (via `scripts/bump-version.sh 5.3.0`)
- Modify: `RELEASE-NOTES.md` (append v5.3.0 entry)

- [ ] **Step 1: Run the bumper**

```bash
./scripts/bump-version.sh --check
```

Expected: shows all 3 files at 5.2.0.

```bash
./scripts/bump-version.sh 5.3.0
```

Expected: bumps all 3 files to 5.3.0. Audit reports no undeclared files contain `5.2.0`.

```bash
./scripts/bump-version.sh --check
```

Expected: all 3 files at 5.3.0.

- [ ] **Step 2: Append v5.3.0 entry to RELEASE-NOTES.md**

Edit `RELEASE-NOTES.md`. Insert a new top-most section:

```markdown
## v5.3.0 — Knowledge discovery + vetting

### What's new

- **Discovery layer.** Every plugin agent (architect, planner, three implementer variants, five reviewers, curator, and the new reviser) now invokes `superpowers:using-project-knowledge` as Step 0 of "Before You Begin". The skill loads `./knowledge/INDEX.md` (if present) into the agent's context. Silent return when absent — no failures, no consuming-project changes required.
- **Source provenance.** Every entry in `knowledge/` now carries a `**Source:**` line. Three valid forms: a canonical URL, the literal `observed_locally_unvetted`, or `observed_locally_unvetted (<hint>)`. Lint Check 4b enforces this as a hard error.
- **Curator pre-write vetting.** Before writing each candidate, the curator detects available MCPs (`mcp__exa__*` / `mcp__ref__*`), constructs a focused search query, and classifies the candidate as Confirmed (canonical URL recorded), Unvetted (no canonical hit), or Contradicted (NOT written; surfaced for user review). Degrades gracefully to all-Unvetted when no MCPs are available.
- **`superpowers:vetting-knowledge` skill.** On-demand audit of every entry against canonical sources. Produces a timestamped report at `knowledge/_meta/vetting-reports/<ISO>.md` (machine-readable YAML frontmatter + human-readable body). Offers to dispatch the new `reviser` agent per contradicted entry.
- **`reviser` librarian agent.** Sibling to `curator`. Takes one contradicted entry + canonical URL/summary, rewrites the entry in place to align with canonical guidance, preserves the H3 date and since-SHA verbatim, does NOT modify INDEX or other entries.

### Migration

If your `knowledge/` directory pre-dates v5.3, run the one-shot backfill once:

```bash
bash <CLAUDE_PLUGIN_ROOT>/scripts/backfill-knowledge-sources.sh ./knowledge
```

The script appends `**Source:** observed_locally_unvetted` to every entry missing a Source line; existing Source lines are untouched. Idempotent.

### Smoke-test checklist (manual; not in CI)

- [ ] After updating, run any plugin agent and confirm the project knowledge INDEX (if any) appears in its context as a system-reminder
- [ ] Run `superpowers:vetting-knowledge` against a project with knowledge; confirm a timestamped report is written
- [ ] In a project with exa/Ref MCPs, run curator on a branch; confirm new entries get `**Source:** <URL>` (not `observed_locally_unvetted`)
- [ ] Run `superpowers:linting-knowledge`; confirm it surfaces missing-Source errors with remediation options
```

- [ ] **Step 3: Run the full test suite one more time**

```bash
bash tests/claude-code/run-skill-tests.sh
```

Expected: all PASS.

```bash
bash scripts/lint-knowledge.sh ./knowledge
echo "exit=$?"
```

Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json RELEASE-NOTES.md
git commit -m "chore: bump version 5.2.0 → 5.3.0

v5.3.0 ships the knowledge discovery + vetting layer:
- using-project-knowledge skill (Step 0 for all 12 agents)
- **Source:** provenance enforced via lint Check 4b
- Curator pre-write vetting (exa/Ref MCPs; graceful degradation)
- vetting-knowledge audit skill + reviser agent

See RELEASE-NOTES.md for the full migration story."
```

---

## Self-Review

This section captures the planner's self-review against the spec, run after writing all 13 tasks.

### 1. Spec coverage

| Spec section | Tasks covering it |
|---|---|
| §1 Discovery skill (`using-project-knowledge`) — frontmatter, behavior, fallback | Task 1 |
| §1 Agent body invocation across 12 agents | Tasks 6, 7, 8 (curator), 9 (reviser) |
| §1 Exception preserved: curator EXISTING_INDEX | Task 8, Step 8 |
| §2 Source schema (three valid forms) | Task 2 (schema doc), Task 4 (lint), Task 8 (curator emission), Task 9 (reviser emission) |
| §2 Example entry post-spec | Task 2, Step 2 (sample in schema doc) |
| §3 Curator pre-write vetting per candidate | Task 8, Step 3 |
| §3 Three classifications (Confirms / Unvetted / Contradicts) | Task 8, Step 3 |
| §3 MCP detection by prefix | Task 8, Step 3 (sub-step a) |
| §3 Entry-writing change (Source line) | Task 8, Step 4 |
| §3 Extended report format (Flagged for review block) | Task 8, Step 5 |
| §3 Anti-pattern: no silent downgrade | Task 8, Step 6 |
| §4 Reviser agent frontmatter | Task 9, Step 4 |
| §4 Reviser per-call context (5 fields) | Task 9, Step 4 (and structural test Step 1) |
| §4 H3 preservation rule | Task 9, Step 4 (and structural test) |
| §4 Reviser anti-patterns (5 items) | Task 9, Step 4 (anti-patterns block) |
| §4 Repo wiring (README, test) | Task 9, Step 5-7 |
| §5 Vetting-knowledge skill (8 steps) | Task 10, Step 4 |
| §5 Step 1 preflight + MCP detect | Task 10 (skill Step 1) |
| §5 Step 2 enumerate | Task 10 (skill Step 2) |
| §5 Step 3 per-entry vet | Task 10 (skill Step 3) |
| §5 Step 4 best-effort codebase grep | Task 10 (skill Step 4) |
| §5 Step 5 timestamped report (YAML + Markdown) | Task 10 (skill Step 5) |
| §5 Step 6 surface results | Task 10 (skill Step 6) |
| §5 Step 7 fix loop | Task 10 (skill Step 7) |
| §5 Step 8 async resume | Task 10 (skill Step 8) |
| §5 Anti-patterns | Task 10 (skill Anti-Patterns block) |
| §6 Lint Check 4b | Task 4 |
| §6 Schema doc update | Task 2 |
| §7 Backfill (this repo's 5 entries) | Task 5 |
| §7 Migration script + idempotency | Task 3 |
| §Testing (structural mandatory) | Task 1 (using-project-knowledge), Task 3 (backfill), Task 4 (lint), Task 8 (curator extend), Task 9 (reviser), Task 10 (vetting-knowledge) |
| §Testing (integration encouraged) | Task 1 (using-project-knowledge integration), Task 9 (reviser integration), Task 10 (vetting-knowledge integration) |
| §Reversibility | Each task's commits are independent reverts; no foreign-key-style hard couplings |

All spec requirements have at least one task. No gaps detected.

### 2. Placeholder scan

Searched the plan text for prohibited tokens. Found:

- No `TBD`, `TODO`, `implement later`, `fill in details`.
- No `Add appropriate error handling` or similar hand-waving.
- No `Similar to Task N` — each task's code/text is repeated where it appears.
- All code-bearing steps have inline code blocks (not free-text descriptions).
- One exception: Task 4 Step 4 says "If the fixture has fewer than three entries, distribute the forms across the entries present" — this is a real branch in the work, not a placeholder, because the existing fixture's entry count isn't visible from the plan; the engineer reads the file in Step 1 of the task and adapts. This is acceptable.

### 3. Type / name consistency

Cross-checked names across tasks:

- Skill name: `superpowers:using-project-knowledge` in Tasks 1, 6, 7, 8 (curator), 9 (reviser), 10 (vetting-knowledge). Consistent.
- Skill name: `superpowers:vetting-knowledge` in Tasks 10, 11. Consistent.
- Agent name: `reviser` in Tasks 9, 10, 11. Consistent.
- Per-call fields for reviser: `ENTRY_PATH`, `ENTRY_TITLE`, `CURRENT_ENTRY_TEXT`, `CANONICAL_URL`, `CANONICAL_SUMMARY` — used in Tasks 9 (agent body), 9 (structural test), 10 (vetting-knowledge skill body dispatch block). Consistent.
- Lint check identifier: `Check 4b` in Tasks 4, 11 (linting-knowledge skill update). Consistent.
- Source forms: `**Source:** <URL>` / `**Source:** observed_locally_unvetted` / `**Source:** observed_locally_unvetted (<hint>)` — used in Tasks 2, 4, 5, 8, 9, 11. Consistent.
- Report filename format: `YYYY-MM-DDTHHMMSSZ.md` in Task 10 (skill body and integration test). Consistent.
- Backfill script: `scripts/backfill-knowledge-sources.sh` in Tasks 3, 11, 13. Consistent.
- Knowledge subdir: `knowledge/_meta/vetting-reports/` in Task 10 (skill body), Task 11 (linting-knowledge update mentions). Consistent.

No name drift detected.

### 4. Order + lint-failing window

The spec/constraints require the lint-failing window to be one task long, between "add Check 4b" and "backfill". Task 4 opens it; Task 5 closes it. Between Task 4 commit and Task 5 commit, exactly one commit exists where `bash scripts/lint-knowledge.sh ./knowledge` exits 1. This is the intended single-task window.

Each other task either leaves the runner green (`bash tests/claude-code/run-skill-tests.sh` passes after the task's commits) or is part of a RED→GREEN pair where the RED step explicitly notes the expected failure. The only persistent RED state across task boundaries is the lint-failing window (Tasks 4→5).

---

## Open questions surfaced for implementation

1. **`claude --subagent` CLI shape** — the integration tests in Tasks 9 and 10 dispatch via `claude` CLI. The exact invocation flag/shape may differ in the current version; the test scaffolds skip on missing `claude` and may need adjustment when run for real. This isn't blocking — the tests have a graceful skip path — but the engineer should expect to tune them.

2. **BashFAQ/024 URL stability** — Task 5 cites `https://mywiki.wooledge.org/BashFAQ/024` for the pipe-into-while gotcha. If that URL is unstable, swap to the bash manual's "shell grammar / pipelines" section. Either is canonical; the choice doesn't affect lint correctness.

3. **Existing test fixture entry counts** — Tasks 4 and 5 assume specific entry counts in the lint-knowledge clean fixture and in this repo's existing knowledge files. The engineer should `cat` these in the task's Step 1 and adapt the Step 2/3 source-line edits to the actual entry count. The plan documents this as a branch where it occurs (Task 4, Step 4; Task 5, Step 1).
