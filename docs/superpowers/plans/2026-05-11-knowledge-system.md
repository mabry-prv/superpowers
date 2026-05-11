# Knowledge System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the knowledge-system convention defined in `docs/superpowers/specs/2026-05-11-knowledge-system-design.md` — a new "librarian" family with the `curator` agent, the `curating-knowledge` and `linting-knowledge` skills, the lint script, the session-start INDEX injection, the `finishing-a-development-branch` curator-dispatch step, and the schema doc that ties it all together.

**Architecture:** Plugin defines the schema, the agent, and the tooling. Consuming projects get a top-level `knowledge/` directory populated by the curator at branch-completion time. Read path is universal via `hooks/session-start` (auto-includes `knowledge/INDEX.md` when present). Write path is auto-triggered by the `finishing-a-development-branch` skill or manually via `superpowers:curating-knowledge`. Lint is a manual pass via `superpowers:linting-knowledge`.

**Tech Stack:** Markdown agents/skills (Claude Code plugin format); Bash scripts (lint, hook, tests); existing `tests/<agent>/test-structure.sh` convention for structural assertions; `gh` CLI for PRs at the end.

---

## File Structure

### Created

| Path | Purpose |
|---|---|
| `docs/knowledge-schema.md` | Single source of truth for INDEX format, topic file format, entry style, frontmatter, naming, `.knowledgeignore`, bootstrap behavior |
| `agents/curator.md` | New librarian-family agent; reads diff + reports, writes to `knowledge/` |
| `skills/curating-knowledge/SKILL.md` | Thin dispatcher for the curator (manual entry point) |
| `skills/linting-knowledge/SKILL.md` | Thin wrapper for the lint script |
| `scripts/lint-knowledge.sh` | Programmatic lint pass (orphan hooks, dangling SHAs, size cap, dup detection) |
| `tests/curator/test-structure.sh` | Structural test for curator agent + cross-file wiring |
| `tests/curator/fixtures/sample-branch.md` | Sample curator input (for human reference; not executed) |
| `tests/lint-knowledge/test-lint.sh` | Lint-script test: bad-fixture sweep + clean-fixture pass |
| `tests/lint-knowledge/fixtures/bad/knowledge/` | Seeded knowledge dir with planted flaws |
| `tests/lint-knowledge/fixtures/clean/knowledge/` | Seeded valid knowledge dir |
| `tests/hooks/test-session-start.sh` | Structural test for the session-start INDEX injection |

### Modified

| Path | Change |
|---|---|
| `agents/README.md` | Add librarian family row; add curator entry; add curator's per-call context fields |
| `hooks/session-start` | Append `knowledge/INDEX.md` content (when present in session cwd) to `additionalContext` |
| `skills/finishing-a-development-branch/SKILL.md` | Insert curator-dispatch step between "verify tests" and "present options" |
| `tests/claude-code/run-skill-tests.sh` | Register `../curator/`, `../lint-knowledge/`, `../hooks/` test paths |

---

## Implementation order

The order respects dependencies and keeps each task to one commit.

1. **Task 1** — Schema doc (foundation; everything else references it)
2. **Task 2** — Curator structural test (RED)
3. **Task 3** — Curator agent + fixture (GREEN for same-file + schema-doc check)
4. **Task 4** — `agents/README.md` update (librarian family)
5. **Task 5** — `curating-knowledge` skill (+ adds cross-file check to curator test)
6. **Task 6** — `linting-knowledge` skill (stub; references the lint script not yet built)
7. **Task 7** — Lint script test (RED)
8. **Task 8** — Lint script implementation (GREEN)
9. **Task 9** — `hooks/session-start` update + its structural test
10. **Task 10** — `finishing-a-development-branch` skill update (+ adds cross-file check to curator test)
11. **Task 11** — Test runner registration (verifies count rises 6 → 8 new entries + hooks test)

---

### Task 1: Knowledge schema doc

**Files:**
- Create: `docs/knowledge-schema.md`

- [ ] **Step 1: Write the schema doc**

```markdown
# Knowledge System — Schema

> The single source of truth for the `knowledge/` directory convention shipped by the `superpowers` plugin. Curator's prompt references this doc; humans editing knowledge entries follow the same rules; the lint script validates against it.

## Directory layout

```
<repo>/
├── knowledge/
│   ├── INDEX.md
│   ├── patterns/
│   │   └── <topic-slug>.md
│   ├── gotchas/
│   │   └── <topic-slug>.md
│   └── _meta/
│       └── lint-report.md
├── .knowledgeignore     # optional
└── …
```

## `knowledge/INDEX.md`

- One `# Knowledge Index` header.
- One `## <Category>` (e.g. `Patterns`, `Gotchas`) per category.
- Bullets under each category: `- **<slug>** — <≤120-char hook> — \`<category>/<slug>.md\``.
- Categories seeded as `Patterns` and `Gotchas`. Curator may add new categories autonomously when substantive content doesn't fit existing ones. Lint warns on single-entry categories that linger.

## Topic file (`knowledge/<category>/<slug>.md`)

File-level frontmatter (single YAML block at top):

| Field | Type | Required | Notes |
|---|---|---|---|
| `topic` | string | yes | Slug; matches filename (without `.md`) |
| `category` | string | yes | Matches parent directory |
| `last-updated` | YYYY-MM-DD | yes | Date of most recent entry |
| `last-since` | SHA (short ok) | yes | SHA of the commit that produced the most recent entry |

Body:
- One `# <Topic title>` H1
- One `## Entries` H2
- Dated entries as `### YYYY-MM-DD — <one-line entry title> (since <SHA>)` H3, append-only

## Entry style

Soft guideline (lint warns on missing structure; doesn't fail):

1. **Lead** with the rule or gotcha (1-2 sentences).
2. **Why:** root cause / context (1 line).
3. **How:** or **Avoid:** prescription (1 line).
4. Concrete `file:line` references where useful.
5. ≤200 words per entry. Exceed → curator auto-splits into a new topic file rather than bloat existing one.

No generic advice ("use clean code", "write tests"). Every entry must be specific to THIS codebase.

## Naming

- Topic slugs: lowercase, hyphens. `auth.md`, `migrations.md`, `auth-session.md`.
- Auto-split convention: `<parent>-<sub>.md` (e.g. `auth.md` → `auth-session.md` + `auth-permissions.md`).

## `.knowledgeignore` (optional, repo root)

Gitignore-syntax veto. Curator skips diffs in matching paths. Anything in `.gitignore` is already implicitly excluded (curator works against git diff).

Recommended uses: secrets, generated code, vendored deps.

```
.env*
secrets/**
generated/**
*.pb.go
```

NOT recommended: hiding "stuff I don't want documented" — that's curator-prompt discipline, not infrastructure.

## Bootstrap

First curator run in a project with no `knowledge/`:

1. Create `knowledge/`, `knowledge/patterns/`, `knowledge/gotchas/`, `knowledge/_meta/`
2. Create `knowledge/INDEX.md` with the seed template (two empty category sections)
3. Write any initial entries (if curator extracted lessons); otherwise the seed stays empty

Subsequent runs append/update only.

## Curator inputs (per-call context)

The curator agent's `## Per-Call Context` block declares:

- `WORKING_DIRECTORY` — project root
- `TASK_DESCRIPTION` — one-paragraph summary of branch work
- `PLAN_OR_SPEC` — path to spec/plan that drove the work (if any)
- `BASE_SHA` — branch base commit
- `HEAD_SHA` — branch tip commit
- `IMPLEMENTER_REPORT` — DONE / DONE_WITH_CONCERNS / BLOCKED report(s)
- `REVIEWER_REPORTS` — reviewer outputs
- `EXISTING_INDEX` — contents of `knowledge/INDEX.md` (empty string on first run)

Dispatchers MUST populate all eight before calling.

## Curator output

Status verdict (last line of report): `DONE` | `NOTHING_TO_LEARN` | `NEEDS_CONTEXT`.

- `DONE` — N entries written across M topics. Wrapping skill pauses for `git diff knowledge/` review.
- `NOTHING_TO_LEARN` — Nothing worth capturing on this branch. No writes. Wrapping skill proceeds.
- `NEEDS_CONTEXT` — Required input missing/unreadable. No writes. Wrapping skill surfaces gap.

`BLOCKED:ARCHITECTURAL` is out-of-band for this agent. If emitted, wrapping skill surfaces as unexpected; does NOT dispatch architect.
```

- [ ] **Step 2: Visual review the doc renders cleanly**

```bash
# Sanity-check headings + word count
grep -c '^## ' docs/knowledge-schema.md   # expect ≥ 8
wc -w docs/knowledge-schema.md             # expect 400-800
```

Expected: ~8-12 H2 sections, ~500-700 words.

- [ ] **Step 3: Commit**

```bash
git add docs/knowledge-schema.md
git commit -m "docs: knowledge system schema

Single source of truth for the knowledge/ directory convention: INDEX
format, topic file format, entry style, frontmatter, .knowledgeignore,
bootstrap, curator per-call context, status verdicts.

Referenced by agents/curator.md and validated by scripts/lint-knowledge.sh."
```

---

### Task 2: Curator structural test (RED)

**Files:**
- Create: `tests/curator/test-structure.sh`

- [ ] **Step 1: Write the structural test**

```bash
#!/usr/bin/env bash
# Structural test for curator agent.
# Pure grep + file existence checks. Cross-file checks added by later tasks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENT="$REPO_ROOT/agents/curator.md"
SCHEMA="$REPO_ROOT/docs/knowledge-schema.md"
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
echo " curator: structural tests"
echo "========================================"

# Agent file presence and frontmatter
assert_file "$AGENT" "agents/curator.md"
assert_grep "$AGENT" '^name: curator$' "frontmatter: name=curator"
assert_grep "$AGENT" '^color: (teal|cyan)$' "frontmatter: color in librarian palette"
assert_grep "$AGENT" '^model: opus$' "frontmatter: model=opus"
assert_grep "$AGENT" '^effort: xhigh$' "frontmatter: effort=xhigh"

# Required envelope sections
assert_grep "$AGENT" '^## Per-Call Context' "section: Per-Call Context"
assert_grep "$AGENT" '^## Your Job' "section: Your Job"
assert_grep "$AGENT" '^## Anti-Patterns' "section: Anti-Patterns"
assert_grep "$AGENT" '^## Report Format' "section: Report Format"

# Required per-call context fields (all 8)
for field in WORKING_DIRECTORY TASK_DESCRIPTION PLAN_OR_SPEC BASE_SHA HEAD_SHA IMPLEMENTER_REPORT REVIEWER_REPORTS EXISTING_INDEX; do
    assert_grep "$AGENT" "$field" "context field: $field"
done

# Status verdicts
assert_grep "$AGENT" 'DONE' "verdict: DONE"
assert_grep "$AGENT" 'NOTHING_TO_LEARN' "verdict: NOTHING_TO_LEARN"
assert_grep "$AGENT" 'NEEDS_CONTEXT' "verdict: NEEDS_CONTEXT"

# Anti-pattern: librarian does NOT escalate BLOCKED:ARCHITECTURAL
assert_grep "$AGENT" 'NOT escalate.*BLOCKED:ARCHITECTURAL|never emit.*BLOCKED:ARCHITECTURAL|does NOT emit.*BLOCKED:ARCHITECTURAL' "anti-pattern: no architect escalation"

# Fixture presence
assert_file "$FIX/sample-branch.md" "fixture: sample-branch.md"

# Cross-file: schema doc curator-input fields match agent's declared fields
for field in WORKING_DIRECTORY TASK_DESCRIPTION PLAN_OR_SPEC BASE_SHA HEAD_SHA IMPLEMENTER_REPORT REVIEWER_REPORTS EXISTING_INDEX; do
    assert_grep "$SCHEMA" "$field" "schema doc references field: $field"
done

# Cross-file slots (added by Tasks 5 and 10 — included now, expected to fail until those tasks complete)
CURATING_SKILL="$REPO_ROOT/skills/curating-knowledge/SKILL.md"
FINISHING_SKILL="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"
if [ -f "$CURATING_SKILL" ]; then
    assert_grep "$CURATING_SKILL" 'subagent_type=curator' "curating-knowledge: dispatches subagent_type=curator"
else
    fail "curating-knowledge skill not yet created (Task 5)"
fi
if grep -q 'curator' "$FINISHING_SKILL" 2>/dev/null; then
    assert_grep "$FINISHING_SKILL" 'curator' "finishing-a-development-branch: references curator"
else
    fail "finishing-a-development-branch skill not yet updated (Task 10)"
fi

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x tests/curator/test-structure.sh
```

- [ ] **Step 3: Run the test — verify it fails (agent doesn't exist yet)**

```bash
bash tests/curator/test-structure.sh
```

Expected: many `[FAIL]` lines (agent.md missing, fixture missing, cross-file refs missing). Exit code 1. This is the RED state.

- [ ] **Step 4: Commit**

```bash
git add tests/curator/test-structure.sh
git commit -m "test(curator): structural test scaffold (RED)

Asserts frontmatter (name=curator, color in librarian palette, model=opus,
effort=xhigh), envelope sections, all 8 per-call context fields, status
verdicts, anti-pattern coverage, fixture presence, and cross-file wiring
to docs/knowledge-schema.md, skills/curating-knowledge/, and
skills/finishing-a-development-branch/.

Fails until Tasks 3, 5, and 10 complete."
```

---

### Task 3: Curator agent + fixture (GREEN for same-file + schema)

**Files:**
- Create: `agents/curator.md`
- Create: `tests/curator/fixtures/sample-branch.md`

- [ ] **Step 1: Write the curator agent**

```markdown
---
name: curator
description: Use to capture project-specific patterns + gotchas from a completed development branch into the project's knowledge/ directory. Dispatched by superpowers:finishing-a-development-branch (auto) or superpowers:curating-knowledge (manual). Reads diff + reports + existing INDEX, writes to knowledge/ topic files, updates INDEX.md.
color: teal
model: opus
effort: xhigh
---

You are a librarian subagent. Your job is to distill project-specific patterns and gotchas from a completed branch into the project's `knowledge/` directory — a structured, agent-readable markdown archive that other agents consult to avoid rediscovering the wheel.

The full schema is documented in `docs/knowledge-schema.md` (relative to the plugin root). Read it before writing anything. The rules there are authoritative; this prompt summarizes them.

## Per-Call Context

The dispatcher provides eight pieces of per-call context in your prompt. Verify each is populated before starting; if any is missing or empty, return NEEDS_CONTEXT and name the gap.

- **WORKING_DIRECTORY** — project root (must contain or be allowed to create `knowledge/`)
- **TASK_DESCRIPTION** — one-paragraph summary of what was attempted on this branch
- **PLAN_OR_SPEC** — path to the spec/plan that drove the work (may be empty for unplanned work)
- **BASE_SHA** — branch base commit
- **HEAD_SHA** — branch tip commit
- **IMPLEMENTER_REPORT** — DONE / DONE_WITH_CONCERNS / BLOCKED report(s) from the implementer(s)
- **REVIEWER_REPORTS** — reviewer outputs (spec-review, code-quality, etc.) — rejected patterns are prime signal
- **EXISTING_INDEX** — contents of `knowledge/INDEX.md` (empty string on first run)

## Your Job

Working in `WORKING_DIRECTORY`:

1. **Read all inputs end-to-end.** Run `git diff $BASE_SHA..$HEAD_SHA` for the diff. Apply `.knowledgeignore` (if present at repo root) to filter file paths.

2. **Bootstrap on first run.** If `knowledge/` does not exist, create `knowledge/`, `knowledge/patterns/`, `knowledge/gotchas/`, `knowledge/_meta/`, and a seed `INDEX.md` with the two empty category headers.

3. **Identify candidate learnings.** Two categories matter:
   - **Patterns** — a reusable approach this branch established or reinforced (often surfaced by reviewer-spec/code-quality enforcing a convention)
   - **Gotchas** — a footgun, flake, ordering pitfall, library quirk, or anti-pattern that cost time to discover

4. **For each candidate**, decide APPEND to existing topic (matches an INDEX hook) or CREATE new topic. Prefer best-fit existing category over creating a new one. Spawn a new category only when content clearly belongs to none and is substantive (>1 entry-worth).

5. **Write entries.** Each entry is a dated `### YYYY-MM-DD — <title> (since <SHA>)` H3 under the topic's `## Entries` section. Style (soft):
   - Lead with the rule or gotcha (1-2 sentences)
   - **Why:** root cause / context (1 line)
   - **How:** or **Avoid:** prescription (1 line)
   - Concrete `file:line` where useful
   - ≤200 words per entry

6. **Auto-split.** If appending a new entry would push a topic file past 300 lines, split into sub-topics (`<parent>.md` → `<parent>-<sub>.md` + `<parent>-<sub2>.md`), update INDEX accordingly.

7. **Update INDEX.md.** One bullet per topic: `- **<slug>** — <≤120-char hook> — \`<category>/<slug>.md\``.

8. **Self-review.** Re-read each entry: is it specific to THIS codebase? Generic advice ("use clean code") gets cut. Is the `since:` SHA correct? Is the entry within 200 words?

9. **Report back** with status DONE / NOTHING_TO_LEARN / NEEDS_CONTEXT.

## What You Capture vs Skip

**Capture:**
- Patterns reused or worth reusing in this codebase
- Gotchas: test flakes, library footguns, ordering matters, fixture quirks
- Conventions enforced by reviewer feedback (rejected patterns)
- Auto-detected reviewer-multitenant-isolation findings → multi-tenant gotchas

**Skip — out of scope:**
- Architectural decisions / rationale (those live in ADRs)
- User-preference or conversational content ("user prefers tone X") — that's personal auto-memory under `~/.claude/`
- Plugin/superpowers meta-knowledge (skill-authoring patterns, agent envelope rules) — those live in `agents/README.md`
- Generic advice not specific to this codebase

## Anti-Patterns — What NOT to Do

**DO:**
- Read `docs/knowledge-schema.md` before writing
- Verify all 8 per-call context fields are populated before writing
- Apply `.knowledgeignore` filters
- Keep entries ≤200 words; auto-split topics past 300 lines
- Annotate every entry with `since: <SHA>`
- Bootstrap silently on first run (no opt-in prompt)
- Update INDEX.md when topics change

**DO NOT:**
- Capture architectural decisions / rationale — out of scope; ADRs handle these
- Capture user preferences or conversational notes — that's personal auto-memory territory
- Capture plugin/superpowers meta-knowledge — stays in `agents/README.md`
- Write generic advice ("use clean code", "write tests") — entries must be specific to THIS codebase
- Modify code outside `knowledge/`, `.knowledgeignore`, or the seed bootstrap structure
- Emit `BLOCKED:ARCHITECTURAL` — librarians do NOT escalate architecturally. If you genuinely cannot proceed, return NEEDS_CONTEXT with a precise gap description
- Run a second curator pass on the same SHA range — the dispatcher's loop guard handles this

## Report Format

When done, report:

- **Status:** DONE | NOTHING_TO_LEARN | NEEDS_CONTEXT
- **Files touched** (paths) — empty list if NOTHING_TO_LEARN or NEEDS_CONTEXT
- **One-line summary per entry added/updated**
- **Flagged for user review** — entries you're unsure about (categorization, style, accuracy)

End with exactly one of:

**Verdict: DONE — N entries across M topic files**
**Verdict: NOTHING_TO_LEARN** (no entries; wrapping skill skips diff-review)
**Verdict: NEEDS_CONTEXT — <field-name>** (no entries; wrapping skill surfaces gap to user)
```

- [ ] **Step 2: Write the fixture (for human reference, not executed)**

```markdown
# Fixture: sample curator input — multi-tenant isolation bug fix

## TASK_DESCRIPTION

Fixed an IDOR vulnerability where the `/orders/:id` endpoint fetched orders by PK without verifying `org_id == user.org_id`, allowing any authenticated user to read any tenant's order by guessing IDs.

## PLAN_OR_SPEC

docs/superpowers/specs/2026-04-12-fix-orders-idor.md

## BASE_SHA / HEAD_SHA

BASE_SHA: 3a1b2c4
HEAD_SHA: 8d2e0a1

## IMPLEMENTER_REPORT

Status: DONE
- Added explicit org-id check after `db.get(Order, id)` at `apps/api/app/routers/orders.py:34`
- Added integration test asserting cross-tenant fetch returns 404
- All tests pass

## REVIEWER_REPORTS

reviewer-spec: APPROVED — endpoint behavior matches spec
reviewer-multitenant-isolation: APPROVED WITH SUGGESTIONS — suggestion to add a runtime assertion in a future helper

## EXISTING_INDEX

```
# Knowledge Index

## Patterns

(none yet)

## Gotchas

(none yet)
```

## EXPECTED CURATOR BEHAVIOR (not asserted by structural test)

Two entries:

1. **patterns/multitenancy.md** (new topic) — "Always verify org_id post-fetch on PK lookups" with `since: 8d2e0a1`
2. **gotchas/orm.md** (new topic) — "db.get() bypasses the org-scoped session factory's auto-filter" with `since: 8d2e0a1`

INDEX.md gains two bullets.

Verdict: DONE — 2 entries across 2 topic files
```

- [ ] **Step 3: Run the test — same-file + schema checks should now pass; cross-file checks (skill, finishing-skill) still fail**

```bash
bash tests/curator/test-structure.sh
```

Expected: ~17 `[PASS]`, ~2 `[FAIL]` (curating-knowledge skill not yet created; finishing-a-development-branch not yet updated).

- [ ] **Step 4: Commit**

```bash
git add agents/curator.md tests/curator/fixtures/sample-branch.md
git commit -m "feat(agents): curator agent (librarian family)

New agent in a new librarian family (color teal). Reads completed-branch
diff + reports + existing INDEX; writes structured entries to knowledge/
topic files; updates knowledge/INDEX.md.

References docs/knowledge-schema.md as the authoritative contract.
Anti-pattern: never emits BLOCKED:ARCHITECTURAL — returns NEEDS_CONTEXT
when stuck.

Same-file structural checks pass; cross-file checks (skill dispatch,
finishing-a-development-branch reference) pending Tasks 5 + 10."
```

---

### Task 4: agents/README.md update (librarian family)

**Files:**
- Modify: `agents/README.md`

- [ ] **Step 1: Update the families table**

Find this block:

```markdown
| Family | Naming | Color | Role |
|---|---|---|---|
| Implementer | `implementer-<stack>` | warm (pink, orange, yellow) | Writes code + tests for one task |
| Reviewer | `reviewer-<concern>` | red | Reads code, returns verdict + findings |
| Designer | `planner` / `architect` | cool (green, blue) | Produces plans or design recommendations |
```

Append a new row:

```markdown
| Librarian | `curator` (others future) | teal / cyan | Distills project patterns + gotchas into `knowledge/` from completed branches |
```

- [ ] **Step 2: Update per-call context fields table**

Find the existing table (`## Per-call context fields by agent`) and append:

```markdown
| `curator` | WORKING_DIRECTORY, TASK_DESCRIPTION, PLAN_OR_SPEC, BASE_SHA, HEAD_SHA, IMPLEMENTER_REPORT, REVIEWER_REPORTS, EXISTING_INDEX |
```

- [ ] **Step 3: Update "Files in this directory" table**

Append:

```markdown
| `curator.md` | Distills patterns + gotchas from completed branches into `knowledge/` |
```

- [ ] **Step 4: Commit**

```bash
git add agents/README.md
git commit -m "docs(agents): document librarian family + curator

New family for agents that maintain stored knowledge (currently 1 member:
curator). Adds the curator's per-call context fields and the files-in-this-
directory row."
```

---

### Task 5: `curating-knowledge` skill (manual dispatcher)

**Files:**
- Create: `skills/curating-knowledge/SKILL.md`

- [ ] **Step 1: Write the skill**

```markdown
---
name: curating-knowledge
description: Use to manually distill project patterns + gotchas from work that has already been merged or completed — when finishing-a-development-branch was skipped, when backfilling pre-existing branches, or when you specifically want to capture a learning ad-hoc. Dispatches the curator agent.
---

# Curating Knowledge

## Overview

Thin dispatcher for the `curator` agent. The agent is normally auto-dispatched by `superpowers:finishing-a-development-branch` at the end of a development branch; this skill is the manual entry point.

**Announce at start:** "I'm using the curating-knowledge skill to dispatch the curator agent."

## The Process

### Step 1: Collect Per-Call Context

The curator requires eight fields. Gather them from the user / git / project state:

- `WORKING_DIRECTORY` — project root (default: cwd)
- `TASK_DESCRIPTION` — one-paragraph summary (ask user if not obvious from git log)
- `PLAN_OR_SPEC` — path to spec/plan (optional; empty string acceptable)
- `BASE_SHA` — branch base; default `git merge-base HEAD main`
- `HEAD_SHA` — branch tip; default `git rev-parse HEAD`
- `IMPLEMENTER_REPORT` — implementer's DONE/BLOCKED report; ask user if not stored
- `REVIEWER_REPORTS` — reviewer outputs; ask user if not stored
- `EXISTING_INDEX` — `cat knowledge/INDEX.md 2>/dev/null || echo ""` (empty on first run)

Verify all eight fields are populated. A missing field would cause the curator to hallucinate or return NEEDS_CONTEXT.

### Step 2: Dispatch

```
Task(
  subagent_type=curator,
  description="Manual curation of branch <branch-name>",
  prompt=<per-call context block below>
)
```

Per-call block:

```
WORKING_DIRECTORY: <project root>
TASK_DESCRIPTION: <one paragraph>
PLAN_OR_SPEC: <path or empty>
BASE_SHA: <SHA>
HEAD_SHA: <SHA>
IMPLEMENTER_REPORT: <text>
REVIEWER_REPORTS: <text or "none">
EXISTING_INDEX: <verbatim contents>
```

### Step 3: Handle the Verdict

- **DONE — N entries across M topic files** — pause; prompt user to review `git diff knowledge/` and commit/edit/discard
- **NOTHING_TO_LEARN** — done; no writes
- **NEEDS_CONTEXT — <field>** — surface the gap; do not proceed until resolved

## Anti-Patterns — What NOT to Do

**DO NOT:**
- Dispatch the curator twice on the same SHA range — same-branch double-runs produce duplicates
- Populate `EXISTING_INDEX` with anything other than verbatim INDEX.md contents (the curator deduplicates against it)
- Pass `BASE_SHA == HEAD_SHA` (empty diff → curator returns NEEDS_CONTEXT)
- Try to enrich the curator's per-call context with content from your conversation — only project-state inputs (diff, reports, INDEX) are in scope
```

- [ ] **Step 2: Run the curator structural test — the cross-file check for curating-knowledge should now pass**

```bash
bash tests/curator/test-structure.sh
```

Expected: ~18 `[PASS]`, 1 `[FAIL]` (finishing-a-development-branch reference, pending Task 10).

- [ ] **Step 3: Commit**

```bash
git add skills/curating-knowledge/SKILL.md
git commit -m "feat(skills): curating-knowledge — manual curator dispatcher

Thin dispatcher for the curator agent. Manual entry point for retroactive
backfill, ad-hoc curation, or when finishing-a-development-branch is
skipped."
```

---

### Task 6: `linting-knowledge` skill (lint wrapper)

**Files:**
- Create: `skills/linting-knowledge/SKILL.md`

- [ ] **Step 1: Write the skill**

```markdown
---
name: linting-knowledge
description: Use to run a health check on the project's knowledge/ directory — detect orphan INDEX hooks, dangling since-SHA refs after rebase/squash, oversized entries, missing frontmatter, and best-effort duplicate detection. Wraps scripts/lint-knowledge.sh.
---

# Linting Knowledge

## Overview

Thin wrapper for `scripts/lint-knowledge.sh` (plugin-shipped). Runs the lint pass against the consuming project's `knowledge/` directory, parses the report, and surfaces findings in chat.

**Announce at start:** "I'm using the linting-knowledge skill to check the knowledge directory."

## The Process

### Step 1: Run the Lint Script

```bash
# Path is relative to plugin root
SCRIPT="$(dirname "$(which claude 2>/dev/null || echo /)")/.claude/plugins/cache/superpowers-personal/superpowers/scripts/lint-knowledge.sh"

# Or, when running inside the plugin repo:
bash scripts/lint-knowledge.sh
```

The script writes its report to `knowledge/_meta/lint-report.md` and exits with:
- 0 — clean (or only soft warnings)
- 1 — errors found

### Step 2: Parse the Report

Read `knowledge/_meta/lint-report.md`. Three sections of interest:

- **Errors** — orphan INDEX hooks, missing frontmatter, dangling since-SHAs. Must be fixed before next merge.
- **Warnings** — oversized entries (>200 words), oversized topics (>300 lines), missing Why/How/Avoid structure. Soft; user judgment.
- **Suggestions** — possible duplicates flagged by title overlap. Human review required.

### Step 3: Surface Findings

For each error: print `file:line` (or topic name), what's wrong, how to fix.
For warnings + suggestions: print summary; offer to walk through.

## Anti-Patterns — What NOT to Do

**DO NOT:**
- Auto-fix issues — lint is a read-only health check, not a writer
- Skip warnings without surfacing them (the user may not notice the report file)
- Run lint as part of a hot path — it's a manual check, not session-start material
```

- [ ] **Step 2: Commit**

```bash
git add skills/linting-knowledge/SKILL.md
git commit -m "feat(skills): linting-knowledge — lint script wrapper

Thin wrapper for scripts/lint-knowledge.sh. Manual trigger; reads
knowledge/_meta/lint-report.md and surfaces findings in chat."
```

---

### Task 7: Lint script test (RED)

**Files:**
- Create: `tests/lint-knowledge/test-lint.sh`
- Create: `tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md`
- Create: `tests/lint-knowledge/fixtures/bad/knowledge/patterns/orphan-hook.md` (intentionally absent — INDEX points here but file doesn't exist)
- Create: `tests/lint-knowledge/fixtures/bad/knowledge/patterns/no-frontmatter.md`
- Create: `tests/lint-knowledge/fixtures/bad/knowledge/gotchas/oversized.md`
- Create: `tests/lint-knowledge/fixtures/bad/knowledge/gotchas/dangling-sha.md`
- Create: `tests/lint-knowledge/fixtures/clean/knowledge/INDEX.md`
- Create: `tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md`
- Create: `tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md`

- [ ] **Step 1: Build the bad fixture**

```bash
mkdir -p tests/lint-knowledge/fixtures/bad/knowledge/patterns
mkdir -p tests/lint-knowledge/fixtures/bad/knowledge/gotchas
```

`tests/lint-knowledge/fixtures/bad/knowledge/INDEX.md`:

```markdown
# Knowledge Index

## Patterns

- **orphan-hook** — Hook points to a topic file that does not exist — `patterns/orphan-hook.md`
- **no-frontmatter** — Topic missing frontmatter — `patterns/no-frontmatter.md`

## Gotchas

- **oversized** — Topic has an entry that exceeds 200 words — `gotchas/oversized.md`
- **dangling-sha** — Entry references a SHA that no longer exists — `gotchas/dangling-sha.md`
```

`tests/lint-knowledge/fixtures/bad/knowledge/patterns/no-frontmatter.md`:

```markdown
# No frontmatter pattern

## Entries

### 2026-05-01 — Some learning (since deadbee1)

This file has no frontmatter — the lint should flag it.

**Why:** test fixture.
**How:** ensure lint catches missing frontmatter.
```

`tests/lint-knowledge/fixtures/bad/knowledge/gotchas/oversized.md`:

```markdown
---
topic: oversized
category: gotchas
last-updated: 2026-05-01
last-since: deadbee1
---

# Oversized gotcha

## Entries

### 2026-05-01 — A very long entry (since deadbee1)

[Body > 200 words. Repeat lorem-ipsum text to exceed the soft cap. Lorem ipsum dolor sit amet,
consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat
nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt
mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem
accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis
et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas
sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem
sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur,
adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam
aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis
suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur.]
```

`tests/lint-knowledge/fixtures/bad/knowledge/gotchas/dangling-sha.md`:

```markdown
---
topic: dangling-sha
category: gotchas
last-updated: 2026-05-01
last-since: 0000000000000000000000000000000000000000
---

# Dangling SHA gotcha

## Entries

### 2026-05-01 — References a non-existent SHA (since 0000000000000000000000000000000000000000)

The all-zeros SHA cannot exist in any repo — lint should flag it.

**Why:** test fixture.
**How:** ensure lint catches dangling since-SHA.
```

- [ ] **Step 2: Build the clean fixture**

```bash
mkdir -p tests/lint-knowledge/fixtures/clean/knowledge/patterns
mkdir -p tests/lint-knowledge/fixtures/clean/knowledge/gotchas
```

`tests/lint-knowledge/fixtures/clean/knowledge/INDEX.md`:

```markdown
# Knowledge Index

## Patterns

- **auth** — Login + session shape + role checks — `patterns/auth.md`

## Gotchas

- **testing** — Flake causes, fixture ordering — `gotchas/testing.md`
```

`tests/lint-knowledge/fixtures/clean/knowledge/patterns/auth.md`:

```markdown
---
topic: auth
category: patterns
last-updated: 2026-05-11
last-since: HEAD
---

# Auth patterns

## Entries

### 2026-05-11 — Org-scoped session factory (since HEAD)

Use `Depends(get_org_db)` for org-scoped queries. Never raw `get_db`.

**Why:** the auto-filter lives in the factory; bypassing leaks rows across tenants.

**How:** `app/deps.py:14` defines the factory; every org-scoped router imports it.
```

`tests/lint-knowledge/fixtures/clean/knowledge/gotchas/testing.md`:

```markdown
---
topic: testing
category: gotchas
last-updated: 2026-05-11
last-since: HEAD
---

# Testing gotchas

## Entries

### 2026-05-11 — async fixtures need session_loop (since HEAD)

pytest-asyncio fixtures must declare `loop_scope="session"` when shared.

**Why:** event-loop binding mismatch causes "Future attached to a different loop" flakes.

**How:** add `@pytest_asyncio.fixture(loop_scope="session")` to shared async fixtures.
```

(Note: clean fixture uses `HEAD` as the since-SHA so the test runs against the actual repo's HEAD and the SHA resolves successfully. This avoids hardcoding a real SHA that may not exist when the test runs.)

- [ ] **Step 3: Write the lint test script**

`tests/lint-knowledge/test-lint.sh`:

```bash
#!/usr/bin/env bash
# Test for scripts/lint-knowledge.sh.
# Runs the lint against bad + clean fixtures; asserts expected diagnostics.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINT="$REPO_ROOT/scripts/lint-knowledge.sh"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

assert_exit_code() {
    local actual="$1" expected="$2" name="$3"
    if [ "$actual" -eq "$expected" ]; then pass "$name (exit=$actual)"; else fail "$name (got $actual, expected $expected)"; fi
}

assert_report_contains() {
    local report="$1" pattern="$2" name="$3"
    if grep -qE "$pattern" "$report" 2>/dev/null; then pass "$name"; else fail "$name (pattern '/$pattern/' not in $report)"; fi
}

assert_report_clean() {
    local report="$1" name="$2"
    if grep -qE '^Errors:[[:space:]]+0' "$report" 2>/dev/null; then pass "$name"; else fail "$name (errors found in $report)"; fi
}

echo "========================================"
echo " lint-knowledge: bad fixture sweep"
echo "========================================"

BAD="$SCRIPT_DIR/fixtures/bad/knowledge"
bash "$LINT" "$BAD" >/dev/null 2>&1
bad_exit=$?
assert_exit_code "$bad_exit" 1 "lint exits 1 on bad fixture"

BAD_REPORT="$BAD/_meta/lint-report.md"
assert_report_contains "$BAD_REPORT" 'orphan-hook|patterns/orphan-hook' "detects orphan INDEX hook"
assert_report_contains "$BAD_REPORT" 'no-frontmatter|missing frontmatter' "detects missing frontmatter"
assert_report_contains "$BAD_REPORT" 'oversized|>200 words' "detects oversized entry"
assert_report_contains "$BAD_REPORT" 'dangling|since.*does not resolve|cat-file' "detects dangling since-SHA"

echo ""
echo "========================================"
echo " lint-knowledge: clean fixture pass"
echo "========================================"

CLEAN="$SCRIPT_DIR/fixtures/clean/knowledge"
bash "$LINT" "$CLEAN" >/dev/null 2>&1
clean_exit=$?
assert_exit_code "$clean_exit" 0 "lint exits 0 on clean fixture"

CLEAN_REPORT="$CLEAN/_meta/lint-report.md"
assert_report_clean "$CLEAN_REPORT" "clean fixture produces no errors"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

```bash
chmod +x tests/lint-knowledge/test-lint.sh
```

- [ ] **Step 4: Run the test — should FAIL (lint script doesn't exist yet)**

```bash
bash tests/lint-knowledge/test-lint.sh
```

Expected: all assertions `[FAIL]` (lint binary not present). Exit code 1. This is the RED state.

- [ ] **Step 5: Commit**

```bash
git add tests/lint-knowledge/
git commit -m "test(lint-knowledge): structural test + fixtures (RED)

Bad-fixture sweep tests orphan INDEX hook, missing frontmatter, oversized
entry, dangling since-SHA. Clean fixture exercises the happy path. Fails
until scripts/lint-knowledge.sh exists (Task 8)."
```

---

### Task 8: Lint script implementation (GREEN)

**Files:**
- Create: `scripts/lint-knowledge.sh`

- [ ] **Step 1: Write the lint script**

```bash
#!/usr/bin/env bash
# Lint pass for knowledge/ directory health.
# Usage: lint-knowledge.sh [<path-to-knowledge-dir>]
# Defaults to ./knowledge if no arg given.
#
# Exit codes:
#   0 — clean (no errors; warnings may be present)
#   1 — errors found
#   2 — usage error
set -uo pipefail

KNOWLEDGE="${1:-./knowledge}"
if [ ! -d "$KNOWLEDGE" ]; then
    echo "ERROR: knowledge directory not found: $KNOWLEDGE" >&2
    exit 2
fi

INDEX="$KNOWLEDGE/INDEX.md"
META="$KNOWLEDGE/_meta"
REPORT="$META/lint-report.md"
mkdir -p "$META"

errors=()
warnings=()
suggestions=()

err()  { errors+=("$1"); }
warn() { warnings+=("$1"); }
sug()  { suggestions+=("$1"); }

# 1. INDEX present
if [ ! -f "$INDEX" ]; then
    err "INDEX.md missing at $INDEX"
fi

# 2. Every INDEX hook resolves to an existing file
if [ -f "$INDEX" ]; then
    while IFS= read -r line; do
        # Lines of the form: - **<slug>** — <hook> — `<category>/<slug>.md`
        path=$(printf '%s' "$line" | sed -nE 's/.*`([^`]+\.md)`.*/\1/p')
        if [ -n "$path" ] && [ ! -f "$KNOWLEDGE/$path" ]; then
            err "orphan INDEX hook: \`$path\` referenced but file missing"
        fi
    done < "$INDEX"
fi

# 3. Every topic file has frontmatter (single YAML block at top)
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    first=$(head -1 "$topic" 2>/dev/null)
    if [ "$first" != "---" ]; then
        err "missing frontmatter in topic file: $topic"
        continue
    fi
    # Check required keys
    for key in topic category last-updated last-since; do
        if ! awk '/^---$/{c++} c==1 && /^'"$key"':/{found=1} c==2{exit} END{exit !found}' "$topic"; then
            warn "topic $topic missing frontmatter key: $key"
        fi
    done
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 4. Each entry has a since-SHA annotation
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    if grep -E '^### ' "$topic" 2>/dev/null | grep -vqE '\(since [^)]+\)'; then
        warn "topic $topic has entries without (since <SHA>) annotation"
    fi
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 5. SHA resolution via git cat-file (catches dangling SHAs after rebase/squash)
#    Only run if we're inside a git repo
if git -C "$(dirname "$KNOWLEDGE")" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r topic; do
        [ -z "$topic" ] && continue
        # Extract all "since <SHA>" refs
        while IFS= read -r sha; do
            [ -z "$sha" ] && continue
            # HEAD is a valid ref; literal SHAs must resolve
            if ! git -C "$(dirname "$KNOWLEDGE")" cat-file -e "$sha" 2>/dev/null; then
                err "dangling since-SHA in $topic: $sha does not resolve"
            fi
        done < <(grep -oE '\(since [0-9a-fA-F]{7,40}\)|\(since HEAD\)' "$topic" | sed -E 's/.*since ([^)]+).*/\1/')
    done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")
fi

# 6. Soft size cap — entries > 200 words
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    # Split by H3 headings, count words per section
    awk '
        /^### / { if (entry) { words=split(entry, _, /[[:space:]]+/); if (words > 200) print FILENAME ":" prev_title ":" words }
                  prev_title=$0; entry=""; next }
        { entry = entry $0 "\n" }
        END { if (entry) { words=split(entry, _, /[[:space:]]+/); if (words > 200) print FILENAME ":" prev_title ":" words } }
    ' "$topic" | while IFS=: read -r f title wc; do
        warn "oversized entry in $topic (>200 words): $title ($wc words)"
    done
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 7. Soft topic size cap — > 300 lines
while IFS= read -r topic; do
    [ -z "$topic" ] && continue
    lines=$(wc -l < "$topic")
    if [ "$lines" -gt 300 ]; then
        warn "oversized topic file (>300 lines): $topic ($lines lines)"
    fi
done < <(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$INDEX" ! -path "$META/*")

# 8. Best-effort duplicate detection: H3 titles repeated across files
#    Strip date prefix and since-SHA; remaining title text
all_titles=$(find "$KNOWLEDGE" -type f -name '*.md' ! -path "$META/*" -exec grep -H '^### ' {} \; \
    | sed -E 's/^([^:]+):### [0-9-]+ — ([^(]+) \(since [^)]+\)$/\1\t\2/' | sort)
dup=$(printf '%s\n' "$all_titles" | awk -F'\t' '{print $2}' | sort | uniq -d)
if [ -n "$dup" ]; then
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        sug "possible duplicate entry title across topics: \"$d\""
    done <<< "$dup"
fi

# --- Write report ---
{
    echo "# Knowledge lint report"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "Errors: ${#errors[@]}"
    echo "Warnings: ${#warnings[@]}"
    echo "Suggestions: ${#suggestions[@]}"
    echo ""
    if [ "${#errors[@]}" -gt 0 ]; then
        echo "## Errors"
        for e in "${errors[@]}"; do echo "- $e"; done
        echo ""
    fi
    if [ "${#warnings[@]}" -gt 0 ]; then
        echo "## Warnings"
        for w in "${warnings[@]}"; do echo "- $w"; done
        echo ""
    fi
    if [ "${#suggestions[@]}" -gt 0 ]; then
        echo "## Suggestions"
        for s in "${suggestions[@]}"; do echo "- $s"; done
        echo ""
    fi
} > "$REPORT"

if [ "${#errors[@]}" -gt 0 ]; then exit 1; else exit 0; fi
```

```bash
chmod +x scripts/lint-knowledge.sh
```

- [ ] **Step 2: Run the lint test — should PASS now**

```bash
bash tests/lint-knowledge/test-lint.sh
```

Expected: all assertions `[PASS]`. Exit 0.

- [ ] **Step 3: Sanity-check against the actual plugin repo** (this repo doesn't have knowledge/ yet — should exit 2 cleanly)

```bash
bash scripts/lint-knowledge.sh ./knowledge || echo "exit=$?"
```

Expected: `ERROR: knowledge directory not found` + `exit=2` (graceful).

- [ ] **Step 4: Commit**

```bash
git add scripts/lint-knowledge.sh
git commit -m "feat(scripts): lint-knowledge.sh — knowledge/ health check

Programmatic checks: orphan INDEX hooks, missing frontmatter, missing
since-SHA annotations, dangling since-SHAs (via git cat-file -e), oversized
entries (>200 words), oversized topic files (>300 lines), best-effort
duplicate detection by title overlap.

Writes report to knowledge/_meta/lint-report.md. Exit codes: 0 clean, 1
errors, 2 usage. Test fixture passes; bad fixture surfaces all planted
flaws."
```

---

### Task 9: hooks/session-start — INDEX injection + test

**Files:**
- Modify: `hooks/session-start`
- Create: `tests/hooks/test-session-start.sh`

- [ ] **Step 1: Update the hook**

Replace the existing `using_superpowers_escaped` + `session_context` block. Find this region:

```bash
using_superpowers_escaped=$(escape_for_json "$using_superpowers_content")
session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_superpowers_escaped}\n</EXTREMELY_IMPORTANT>"
```

Replace with:

```bash
using_superpowers_escaped=$(escape_for_json "$using_superpowers_content")

# Knowledge INDEX injection — if <session-cwd>/knowledge/INDEX.md exists,
# append its content (escaped) so every agent sees project-specific patterns
# and gotchas without per-agent prompt changes.
knowledge_index_block=""
if [ -f "${PWD}/knowledge/INDEX.md" ]; then
    knowledge_index_raw=$(cat "${PWD}/knowledge/INDEX.md")
    knowledge_index_escaped=$(escape_for_json "$knowledge_index_raw")
    knowledge_index_block="\n\n---\n\n**Project knowledge index** (from \`knowledge/INDEX.md\`):\n\n${knowledge_index_escaped}\n\n_Load full topic files with the Read tool when their one-line hook matches your task._"
fi

session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_superpowers_escaped}${knowledge_index_block}\n</EXTREMELY_IMPORTANT>"
```

- [ ] **Step 2: Write the hook test**

```bash
mkdir -p tests/hooks
```

`tests/hooks/test-session-start.sh`:

```bash
#!/usr/bin/env bash
# Structural test for hooks/session-start INDEX injection.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

passed=0
failed=0

pass() { echo "  [PASS] $1"; passed=$((passed + 1)); }
fail() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

echo "========================================"
echo " session-start hook: INDEX injection"
echo "========================================"

# Case 1: no knowledge/ dir — hook produces output, no INDEX block
tmpdir=$(mktemp -d)
output=$(cd "$tmpdir" && bash "$HOOK")
if echo "$output" | grep -q '"hookEventName": "SessionStart"'; then pass "no-knowledge: hook emits valid output"; else fail "no-knowledge: hook output malformed"; fi
if echo "$output" | grep -q 'Project knowledge index'; then fail "no-knowledge: hook leaks INDEX block when no knowledge/"; else pass "no-knowledge: no INDEX block"; fi
rm -rf "$tmpdir"

# Case 2: knowledge/INDEX.md present — hook injects the content
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/knowledge"
cat > "$tmpdir/knowledge/INDEX.md" <<'EOF'
# Knowledge Index

## Patterns

- **fixture-auth** — Sample hook for fixture-auth pattern — `patterns/fixture-auth.md`
EOF
output=$(cd "$tmpdir" && bash "$HOOK")
if echo "$output" | grep -q '"hookEventName": "SessionStart"'; then pass "with-knowledge: hook emits valid output"; else fail "with-knowledge: hook output malformed"; fi
if echo "$output" | grep -q 'Project knowledge index'; then pass "with-knowledge: INDEX block appears"; else fail "with-knowledge: INDEX block missing"; fi
if echo "$output" | grep -q 'fixture-auth'; then pass "with-knowledge: INDEX content present"; else fail "with-knowledge: INDEX content not in output"; fi
rm -rf "$tmpdir"

echo ""
echo "Results: $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
```

```bash
chmod +x tests/hooks/test-session-start.sh
```

- [ ] **Step 3: Run the hook test — should PASS**

```bash
bash tests/hooks/test-session-start.sh
```

Expected: 5 `[PASS]`. Exit 0.

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start tests/hooks/test-session-start.sh
git commit -m "feat(hooks): inject knowledge/INDEX.md at session start

Hook checks for <session-cwd>/knowledge/INDEX.md and, when present,
appends its content to the using-superpowers session context. Universal
read path — every agent sees the topic list without per-agent prompt
changes. No-op when knowledge/ doesn't exist.

Test verifies both cases (with + without knowledge/ dir)."
```

---

### Task 10: finishing-a-development-branch — curator dispatch step

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`

- [ ] **Step 1: Read the existing Step 2 region**

```bash
sed -n '50,120p' skills/finishing-a-development-branch/SKILL.md
```

Identify the boundary: between the end of "Step 1: Verify Tests" (the `**If tests pass:** Continue to Step 2.` line) and the start of "Step 2: Detect Environment".

- [ ] **Step 2: Insert the new step between current Step 1 and Step 2**

After the line:
```
**If tests pass:** Continue to Step 2.
```

Insert a new section. The current `### Step 2: Detect Environment` becomes Step 3, and all subsequent step numbers shift by one. Use a search-and-replace pattern that renumbers in-place. Concretely:

1. Insert a new section titled `### Step 2: Capture Knowledge (curator)`:

```markdown
### Step 2: Capture Knowledge (curator)

**Before integrating the work, distill project patterns + gotchas from this branch into the project's `knowledge/` directory.**

Auto-dispatch the `curator` agent (librarian family):

```
Task(
  subagent_type=curator,
  description="Capture knowledge from branch <branch-name>",
  prompt=<per-call context block below>
)
```

Per-call block:

```
WORKING_DIRECTORY: <project root>
TASK_DESCRIPTION: <one-paragraph summary of the branch work>
PLAN_OR_SPEC: <path to spec/plan if any, else empty>
BASE_SHA: $(git merge-base HEAD main)
HEAD_SHA: $(git rev-parse HEAD)
IMPLEMENTER_REPORT: <implementer's DONE/BLOCKED report from this branch>
REVIEWER_REPORTS: <reviewer outputs from requesting-code-review or SDD reviews>
EXISTING_INDEX: <contents of knowledge/INDEX.md, empty if first run>
```

**Verify all eight fields are populated** before dispatching. A missing field would cause the curator to hallucinate or return NEEDS_CONTEXT.

**Handle the verdict:**

- **DONE — N entries across M topic files** — pause:
  ```
  The curator added N entries across M topic file(s):
  - <one-line summary per entry>
  
  Review `git diff knowledge/` and either commit / edit / discard
  before proceeding to merge.
  ```
  Wait for the user to commit (or explicitly skip).

- **NOTHING_TO_LEARN** — proceed silently to Step 3. No knowledge writes.

- **NEEDS_CONTEXT — <field>** — surface the gap:
  ```
  Curator returned NEEDS_CONTEXT for field: <field>. Provide the missing
  context or skip curation for this branch by responding "skip curation".
  ```
  Do not proceed to Step 3 until resolved (or user explicitly skips).

**Anti-patterns:**
- Do NOT dispatch the curator twice on the same SHA range. If it already ran on this branch, skip this step.
- Do NOT proceed to merge while the curator's writes are uncommitted — the diff-review loop must close first.
- Do NOT escalate `BLOCKED:ARCHITECTURAL` from the curator — librarians don't escalate that way. Treat as an unexpected condition and surface to user.

```

2. Renumber the remaining steps (every `### Step <N>: <title>` after this insertion gets N+1).

- [ ] **Step 3: Verify the file structure is still coherent**

```bash
grep -n '^### Step ' skills/finishing-a-development-branch/SKILL.md
```

Expected: a contiguous numbered sequence (1, 2, 3, …) with no gaps.

- [ ] **Step 4: Run the curator structural test — should now fully pass**

```bash
bash tests/curator/test-structure.sh
```

Expected: all `[PASS]`. Exit 0. (Curator + curating-knowledge skill + finishing-a-development-branch all wired.)

- [ ] **Step 5: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(skills): finishing-a-development-branch dispatches curator

New Step 2 between 'verify tests' and 'detect environment': auto-dispatch
the curator agent on the whole-branch context. Pause for git diff review
if curator returns DONE; proceed silently on NOTHING_TO_LEARN; surface
gap on NEEDS_CONTEXT.

Existing steps renumbered (Step 2 → Step 3, etc.).

Curator structural test now fully passes."
```

---

### Task 11: Test runner registration

**Files:**
- Modify: `tests/claude-code/run-skill-tests.sh`

- [ ] **Step 1: Register the three new tests**

Find:

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
    "../reviewer-spec/test-structure.sh"
    "../reviewer-code-quality/test-structure.sh"
    "../planner/test-structure.sh"
    "../architect/test-structure.sh"
)
```

Replace with:

```bash
tests=(
    "test-subagent-driven-development.sh"
    "../multi-angle-review/test-structure.sh"
    "../reviewer-spec/test-structure.sh"
    "../reviewer-code-quality/test-structure.sh"
    "../planner/test-structure.sh"
    "../architect/test-structure.sh"
    "../curator/test-structure.sh"
    "../lint-knowledge/test-lint.sh"
    "../hooks/test-session-start.sh"
)
```

- [ ] **Step 2: Run the full suite — verify all new tests appear and pass**

```bash
bash tests/claude-code/run-skill-tests.sh 2>&1 | tail -30
```

Expected: 8 of 9 structural tests pass (the pre-existing `test-subagent-driven-development.sh` Test 2 flake remains; documented in PR#1 body). New tests: curator, lint-knowledge, hooks — all PASS.

- [ ] **Step 3: Commit**

```bash
git add tests/claude-code/run-skill-tests.sh
git commit -m "test: register curator + lint-knowledge + hooks structural tests

run-skill-tests.sh registers three new test entries. Structural test count
rises from 6 to 9 (8 passing; pre-existing SDD Test 2 flake unchanged)."
```

---

## After All Tasks Complete

Run the multi-angle review against the branch:

```bash
# Manually or via /ultrareview if available
```

Then invoke `superpowers:finishing-a-development-branch` — which will exercise the new curator step on this very branch (eat-own-dog-food). The curator should bootstrap `knowledge/` in this plugin repo and capture lessons from building itself (skill-authoring patterns, agent envelope rules, lint shape decisions).

Open a PR, address review findings, merge.

---

## Out of scope (deferred to follow-up plan)

1. End-to-end integration test for `finishing-a-development-branch` → curator dispatch (slow, agent-execution; consistent with PR#1's deferral pattern).
2. Curator quality eval (does it make *good* choices?) — manual during initial rollout.
3. Cross-branch dedup / 3-way curator merge mode for `knowledge/` topic files.
4. Optional `.knowledgemap` (curator-maintained mapping of topic → code paths) for richer querying.
5. The eat-own-dog-food first curator run — happens organically when finishing-a-development-branch is invoked on this PR; doesn't need a planned task.
