# Knowledge Discovery + Vetting — Design Spec

**Date:** 2026-05-12
**Status:** Approved (brainstorming)
**Author:** Marcin + Claude (brainstorming session)
**Builds on:** `2026-05-11-knowledge-system-design.md`

---

## Context

The knowledge system shipped in v5.2.0 (the `curator` agent + `knowledge/` directory) closes the "where do project-specific lessons live" gap. Two structural problems remain that limit its usefulness in practice:

1. **Discovery.** The SessionStart hook injects `knowledge/INDEX.md` into the main session, but plugin-dispatched subagents (planner, implementer-*, reviewer-*, architect, curator) do NOT inherit that injection. They see only their agent body + the dispatcher's per-call context block. Knowledge gets written by the curator and then dies in place — every subagent rediscovers what prior work already learned.

2. **Authority.** The curator writes "the practice we landed on" but does not verify that practice against canonical sources (official docs, well-known issues, framework guides). Locally-correct-but-globally-suboptimal patterns get captured as "knowledge," then propagate across future slices via the discovery path (once it works), multiplying the original mistake. Without a vetting layer, `knowledge/` risks being net-negative.

This spec addresses both gaps. It introduces a new lightweight discovery skill, a per-entry `**Source:**` provenance line, pre-write vetting in the curator, a standalone `vetting-knowledge` audit skill, and a new `reviser` librarian agent that rewrites contradicted entries to align with canonical guidance.

## Framework evolution note

The original superpowers principle — "the controller curates exactly what the subagent needs" — was written when there was effectively one default agent and everything in its context was inherently per-task. The framework has since added specialized agents (`implementer-fastapi`, `reviewer-multitenant-isolation`) that already carry stack-specific knowledge in their bodies, and a standardized `knowledge/` artifact at a known relative path.

This spec adopts a refined principle:

- **Per-task dynamic context** → dispatcher curates. (`SPEC_PATH`, `IMPLEMENTER_REPORT`, `FILES_TO_REVIEW` — these vary per call and only the dispatcher knows them.)
- **Project-stable environmental context** → agent self-loads. (`INDEX.md` and future stable artifacts at known paths.)

Discovery falls under the second category. The dispatcher has nothing the agent can't discover for itself.

## Goals

1. Every plugin subagent sees `knowledge/INDEX.md` (if any) at the start of its task, with no per-dispatcher wiring.
2. Every entry in `knowledge/` carries explicit provenance — either a canonical URL or the literal `observed_locally_unvetted`. No silent middle ground.
3. New entries are vetted at write time. The curator searches canonical sources via exa/Ref MCPs before committing each entry. Contradictions block the write and surface to the user.
4. Existing entries can be re-audited on demand. The `vetting-knowledge` skill walks every entry, produces a timestamped report grouped by `confirmed`/`unvetted`/`contradicted`, and offers to dispatch the reviser per contradicted entry.
5. Graceful degradation. Projects without exa/Ref MCPs see every new entry marked `observed_locally_unvetted` with a one-line note — no failures, no prompts.
6. No change to the consuming project. Discovery is plugin-internal. Consuming projects don't modify their `CLAUDE.md` or settings.

## Non-goals

1. **Auto-loading topic files.** Only `INDEX.md` is injected. Topic files load on demand via the agent's `Read` tool when an INDEX hook matches the task.
2. **Code fixes from vetting.** When vetting finds a contradicted entry, the reviser rewrites the *entry*. Project code that follows the now-deprecated pattern is flagged in the report (files-referencing list) but NOT auto-modified.
3. **Cross-project knowledge sharing.** Each project's `knowledge/` remains its own; no cross-repo aggregation.
4. **Embeddings / vector search.** Same as the v5.2 spec — plain text, explicit reads.
5. **Modifying the consuming project's `CLAUDE.md`.** Discovery is fully internal to the plugin (existing SessionStart hook for the main session; new skill for subagents).
6. **Auto-commits.** No reviser output lands without an explicit user OK per entry. No curator write proceeds past a contradiction without explicit user OK.

## Architecture

Three coordinated layers. The first is always-on; the others trigger at well-defined points.

### Layer A — Discovery (always-on, per dispatch)

A new lightweight skill `superpowers:using-project-knowledge`. Every plugin agent body gains a single new "Before You Begin" step: invoke the skill first. The skill checks for `./knowledge/INDEX.md`; if present, surfaces it as a system-reminder in the agent's context with an instruction to `Read` matching topic files when relevant; if absent, returns silently.

### Layer B — Vetting (two trigger points)

**B1 — Auto vetting (per curator run).**
On every branch finish, the curator does pre-write vetting on each candidate entry. exa/Ref search confirms / contradicts / produces no canonical hit. Confirmed entries land with `**Source:** <URL>`. No-hit entries land with `**Source:** observed_locally_unvetted`. Contradicted entries are NOT written — they're surfaced in the curator's DONE report under "Flagged for review" with the contradicting URL.

**B2 — Periodic re-audit (manual, on demand).**
A new skill `superpowers:vetting-knowledge` walks every entry in `knowledge/`, re-runs exa/Ref search per entry, produces a timestamped report (machine-readable YAML frontmatter + human-readable body) at `knowledge/_meta/vetting-reports/<ISO-timestamp>.md`, and offers to dispatch the reviser per contradicted entry.

### Layer C — Lint enforcement (every health check)

`linting-knowledge` (and the underlying `scripts/lint-knowledge.sh`) gains a new check: every entry must end with a `**Source:**` line. Hard error on miss.

### Fix path

A new librarian agent `reviser` (sibling to `curator`) takes one contradicted entry + a canonical URL + summary, fetches the URL, rewrites the entry to align with canonical guidance, and updates the file in place. Dispatched by `vetting-knowledge` (optionally during the same run, or async via "apply fixes from report XYZ"). User reviews the `git diff` and approves before commit.

## Design

### 1. Discovery skill — `superpowers:using-project-knowledge`

**New file:** `skills/using-project-knowledge/SKILL.md`

**Frontmatter:**
```yaml
---
name: using-project-knowledge
description: Use at the start of every subagent task to load the project's knowledge index (patterns + gotchas captured from prior work). Surfaces ./knowledge/INDEX.md as a system-reminder and instructs the agent to Read specific topic files when their hook matches the task.
---
```

**Behavior:**
1. Test for `./knowledge/INDEX.md`. If absent: emit a one-line note ("Project has no `knowledge/` directory; proceeding without project knowledge") and return.
2. If present: read its contents. Surface as a system-reminder block to the invoking agent.
3. Append instruction text: "Treat the index above as authoritative for project-specific patterns and gotchas. When a row's hook matches your current task, `Read` the referenced topic file before proceeding. Do NOT auto-load every topic file — only the ones whose hooks match what you're working on."
4. Exit.

**Agent body change.** Every existing plugin agent (11 files: `architect`, `curator`, `implementer-default`, `implementer-expo`, `implementer-fastapi`, `planner`, `reviewer-code-quality`, `reviewer-migration-safety`, `reviewer-multitenant-isolation`, `reviewer-security`, `reviewer-spec`) gets one new line under "Before You Begin":

> 0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill will surface the project knowledge index (if any) into your context.

The new `reviser` agent (added in this branch — see §4) gets the same step from creation. Total post-spec: 12 agents with the invocation.

**Exception preserved:** the curator's existing `EXISTING_INDEX` per-call context field stays. Curator uses INDEX two ways — situational awareness (now via the skill) AND deduplication source (verbatim contents it must compare against when deciding APPEND vs CREATE). The latter is per-task context; the dispatcher still resolves it.

**Why INDEX-only, not topic files.** Topic files can grow to ~300 lines each; auto-loading all topics in a knowledge tree with 10 topics is 2k lines of irrelevant context per dispatch. INDEX hooks are ≤120 chars — enough for the agent to recognize relevance and `Read` selectively. Same size-budget reasoning as the existing SessionStart hook for the main session.

### 2. Source schema

**Per-entry body line.** Every entry now ends with a `**Source:**` line, parallel to `**Why:**` and `**Avoid:**`. Three valid forms:

- `**Source:** <URL>` (any string starting with `http://` or `https://`)
- `**Source:** observed_locally_unvetted`
- `**Source:** observed_locally_unvetted (parenthetical hint)`

Anything else is a lint error.

**Schema doc update.** `docs/knowledge-schema.md` "Entry style" section gains a new bullet documenting the source line and the three valid forms.

**Example entry, post-spec:**

```markdown
### 2026-05-11 — BaseHTTPMiddleware breaks ContextVars (since abc1234)

Using `BaseHTTPMiddleware` from Starlette loses request-scoped
ContextVars between middleware and the route handler.

**Why:** Starlette runs `BaseHTTPMiddleware` via a TaskGroup; ContextVar
writes inside it don't propagate to the route handler's task.

**Avoid:** use pure ASGI middleware (`call/await scope, receive, send`)
for anything that mutates ContextVars.

**Source:** https://github.com/encode/starlette/issues/1273
```

### 3. Curator changes — pre-write vetting + source emission

No new per-call context fields. Changes are entirely in the agent body.

**New step in "Your Job"** (between "identify candidate learnings" and "write entries"):

> **Pre-write vetting per candidate.**
>
> 1. **Detect available MCPs.** Inspect available tools for any prefixed `mcp__exa__` or `mcp__ref__`. If neither family is available, skip vetting; every entry written in this run will carry `**Source:** observed_locally_unvetted`, and the report will note "vetting skipped — exa/Ref unavailable" once at the top. Continue normally.
>
> 2. **Construct a focused search query** combining (a) the library/framework name (from the entry body, diff paths, or topic) and (b) the specific API/decorator/config under discussion. Examples: `starlette BaseHTTPMiddleware ContextVar`; `FastAPI Depends override testing`.
>
> 3. **Run the search via the available MCP.** Read the top 1-3 results (use `WebFetch` for deeper reads if needed). Compare against the candidate entry's claim:
>    - **Confirms** → record canonical URL; the entry will be written with `**Source:** <URL>`.
>    - **No relevant hit** (entry captures local observation; canonical source is silent) → entry will be written with `**Source:** observed_locally_unvetted`.
>    - **Contradicts** (canonical source explicitly recommends against the entry's claim) → DO NOT WRITE the entry. Add to the report's "Flagged for review" section with the contradicting URL and 1-2 line summary of the canonical guidance. Continue with other candidates.

**Entry-writing change.** Every entry the curator writes ends with the `**Source:**` line (one of the three valid forms).

**Report format extension.** The curator's existing "Flagged for user review" section becomes a structured block when contradictions are present:

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

The wrapping skill (`finishing-a-development-branch` / `curating-knowledge`) reads the flagged block and surfaces it interactively after DONE:

```
The curator wrote N entries. M candidates were flagged because canonical
guidance contradicts them. For each one:
  (a) accept canonical, skip the entry
  (b) write as observed_locally_unvetted (you disagree with canonical)
  (c) edit to align with canonical (dispatch the reviser)
```

**Anti-pattern (explicit in agent body):** DO NOT silently downgrade a contradiction to `observed_locally_unvetted` and write it anyway. The whole point of the contradiction signal is user-in-the-loop.

### 4. Reviser agent

**New file:** `agents/reviser.md`

**Frontmatter:**
```yaml
---
name: reviser
description: Use to rewrite a single knowledge entry that contradicts canonical guidance, aligning it with the canonical source. Dispatched by superpowers:vetting-knowledge per contradicted entry; user reviews diff before commit.
color: teal
model: opus
effort: xhigh
---
```

Slot in the librarian family alongside the curator. Mechanical/rules-driven work, so `xhigh`.

**Per-Call Context (5 fields):**

| Field | Notes |
|---|---|
| `ENTRY_PATH` | File path of the topic, e.g. `knowledge/patterns/auth.md` |
| `ENTRY_TITLE` | Exact dated H3 header, e.g. `2026-04-22 — Session shape and role checks` |
| `CURRENT_ENTRY_TEXT` | Verbatim body of the entry currently on disk |
| `CANONICAL_URL` | URL of the contradicting canonical source |
| `CANONICAL_SUMMARY` | 2-3 sentence summary of what the canonical guidance says |

**Your Job:**

1. **Verify the contradiction.** `WebFetch(CANONICAL_URL)` and read the relevant section. Confirm `CANONICAL_SUMMARY` matches what you see. If the summary mischaracterizes the canonical source → return `NEEDS_CONTEXT` with a precise gap description (don't fabricate an alignment to a misread source).

2. **Read `ENTRY_PATH` in full** to see neighboring entries — preserve style and formatting conventions.

3. **Draft new entry text** that:
   - Preserves the dated H3 header verbatim — `### YYYY-MM-DD — <title> (since <SHA>)`. Same date and same `since` SHA as the original. (The observation hasn't moved; the recommended response has.)
   - Rewrites the body to reflect canonical guidance.
   - Keeps the `**Why:**` line if the root cause still applies; otherwise replace.
   - Updates the `**Avoid:**` / `**Use:**` line to match canonical prescription.
   - Ends with `**Source:** <CANONICAL_URL>` — the audit trail.

4. **Replace the existing entry in place.** Do not touch surrounding entries, frontmatter, or `INDEX.md`.

5. **Self-review:**
   - `**Source:**` line present and exactly matches `CANONICAL_URL`?
   - Entry ≤ 200 words?
   - Text reflects canonical guidance — no hedging?
   - H3 date and SHA preserved?
   - Did any other entry in the same topic just become inconsistent with the new text? If so, flag it (the user may need a separate revise).

**Report Format:**
- Status: `DONE` | `DONE_WITH_CONCERNS` | `NEEDS_CONTEXT`
- Files touched (just `ENTRY_PATH`)
- One-line summary of the change
- Self-review findings (any conflicts with other entries)
- Verdict line: `**Verdict: DONE — entry revised**` (or failure variants)

**Anti-patterns (explicit in agent body):**
- DO NOT change the H3 date or since-SHA — those record when the observation was made, not when the recommendation was last reviewed.
- DO NOT add meta-commentary in the entry body ("originally said X, now updated to Y"). The `**Source:**` line is the audit trail; git history is the rest.
- DO NOT modify other entries in the same file, even if they look stale. Surface them in self-review; let the user decide.
- DO NOT modify `knowledge/INDEX.md` (entry title/slug isn't changing on a revision; INDEX stays).
- DO NOT escalate `BLOCKED:ARCHITECTURAL` — librarian agents don't have that path. Return `NEEDS_CONTEXT` instead.

**Repo wiring:**
- Add row to `agents/README.md` ("Librarian | `curator`, `reviser`").
- Add `tests/reviser/` fixture-based structural test.
- Wire test into the `tests=(...)` array in `tests/claude-code/run-skill-tests.sh`.

### 5. Vetting-knowledge skill — `superpowers:vetting-knowledge`

**New file:** `skills/vetting-knowledge/SKILL.md`

**Frontmatter:**
```yaml
---
name: vetting-knowledge
description: Use to audit every entry in knowledge/ against canonical sources (via exa/Ref MCPs), producing a timestamped report grouping entries by confirmed/unvetted/contradicted. Offers to dispatch the reviser agent per contradicted entry. Typically run before stack version bumps, after major library upgrades, or quarterly.
---
```

**The Process:**

#### Step 1 — Preflight
- Verify `./knowledge/INDEX.md` exists. If not: report "Project has no `knowledge/` directory; nothing to vet"; exit clean.
- Detect available MCPs by inspecting tools for `mcp__exa__*` and `mcp__ref__*` prefixes. Record which are available. If neither: surface "exa/Ref unavailable — all entries will be bucketed as unvetted" and continue in degraded mode.
- Resolve current HEAD SHA for report header.

#### Step 2 — Enumerate
Walk `INDEX.md`. For each listed topic, read the topic file and parse each dated H3 entry into `{entry_path, entry_title, entry_text, current_source}`.

#### Step 3 — Vet each entry (per-entry loop)
1. Construct a focused search query from the topic name + identifiers in the entry body.
2. If exa/Ref unavailable → classify as `unvetted (no search available)`. Move on.
3. Run search via the available MCP. Read top 1-3 results (`WebFetch` if needed for deeper read).
4. Classify:
   - **Confirmed** — canonical aligns with entry. Record URL.
   - **Unvetted** — no relevant canonical hit. Record the search query (for the report).
   - **Contradicted** — canonical explicitly contradicts. Record URL + 2-3 sentence summary of canonical guidance.
5. On search error (timeout, MCP failure mid-run): bucket the entry as `unvetted (vetting error)` with the error noted.

#### Step 4 — Best-effort codebase grep
For each entry, grep the project tree (excluding `knowledge/`, `docs/`, `tests/`) for identifiers in the entry body (CamelCase, snake_case, dotted paths). Surface file count + paths. For contradicted entries this is the "may need code review" flag. Best-effort: skip silently if too slow (no user prompt).

#### Step 5 — Write the report

Path: `knowledge/_meta/vetting-reports/<ISO-timestamp>.md`. Filename format `YYYY-MM-DDTHHMMSSZ.md` — Windows-safe (no colons), sortable.

Report structure (YAML frontmatter for machine parsing + Markdown body for humans):

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

`_meta/vetting-reports/` gets a recommended `.gitignore` snippet documented in the schema (consuming projects opt in by removing the entry if they want history committed).

#### Step 6 — Surface results in chat + offer fix loop

```
Vetting complete. Report: knowledge/_meta/vetting-reports/2026-05-12T142300Z.md
  Confirmed: 12 / Unvetted: 5 / Contradicted: 1

1 contradicted entry found:
- patterns/auth.md · 2026-04-22 — Session shape and role checks
  Contradicts: https://fastapi.tiangolo.com/.../sessions

Dispatch reviser now to propose rewrites? [y / n / later]
```

- `y` → enter fix loop (Step 7) immediately.
- `n` → done.
- `later` → done; report persists for async resume.

#### Step 7 — Fix loop (immediate or async)

For each entry in `frontmatter.contradicted[]`:

1. Read `CURRENT_ENTRY_TEXT` fresh from disk (in case the file has changed since the report was generated; if it differs significantly, warn the user but proceed).
2. Build the reviser's per-call context block (5 fields from §4) and `Task(subagent_type=reviser, prompt=<block>)`.
3. On reviser `DONE`: run `git diff <ENTRY_PATH>`. Prompt:
   ```
   Reviser proposed this rewrite. Options:
     (a) commit as-is
     (b) leave the change unstaged so you can edit further
     (c) discard (git checkout <entry-path>)
   ```
4. Execute the choice. Move to next contradicted entry.
5. After loop: summarize what landed.

#### Step 8 — Async resume

The user can invoke later: *"apply fixes from `knowledge/_meta/vetting-reports/<file>.md`"*. The skill loads the report's frontmatter, runs Step 7 against `contradicted[]`. If an entry's current on-disk text has drifted from what the report captured, surface a per-entry warning (the report may itself be stale).

#### Anti-patterns
- DO NOT auto-commit reviser output — user reviews diff first.
- DO NOT modify `INDEX.md` (the reviser doesn't either; the entry slug/hook isn't changing on a revision).
- DO NOT delete old report files. Retention is the user's call.
- DO NOT run vetting against `knowledge/_meta/` (lint reports, vetting reports — they're not knowledge entries).
- DO NOT silently swallow MCP search errors. Bucket the entry as `unvetted (vetting error)` with the error noted.

### 6. Lint enforcement

**`scripts/lint-knowledge.sh` — new check** (insert between current Check 4 and Check 5; numbered 4b):

For each topic file, parse the body into per-entry sections (delimited by `### YYYY-MM-DD —` H3 headers). For each section, search the body for a line matching `^\*\*Source:\*\* `. Acceptable values:

- starts with `http://` or `https://`
- equals `observed_locally_unvetted`
- starts with `observed_locally_unvetted (`

Anything else → hard error: `missing **Source:** line in entry: <topic-path>:<entry-title>` (or `malformed **Source:** value in entry: ...` if the line is present but the value isn't one of the three forms).

Hard error means lint exits 1, same severity as orphan INDEX hooks and dangling since-SHAs.

**Schema doc (`docs/knowledge-schema.md`) update.** Add a section under "Entry style":

> **Source line.** Every entry MUST end with a `**Source:**` line. Either a URL pointing to canonical documentation that supports the entry, or the literal `observed_locally_unvetted` for entries that capture local observations the curator couldn't ground against canonical sources. An optional parenthetical hint may follow `observed_locally_unvetted` (e.g. "vetting skipped — exa/Ref unavailable").

### 7. Backfill + migration

**This repo's own `knowledge/` (3 topic files, 5 entries total):**
- `knowledge/patterns/repo-conventions.md` (1 entry) → `**Source:** observed_locally_unvetted` (local plugin convention).
- `knowledge/gotchas/bash-scripts.md` (2 entries):
  - Pipe into `while` discards array writes → canonical bash guidance; backfill with a URL to the bash manual (subshell section) or BashGuide.
  - `session-start` hook resolves via `${PWD}` → plugin-specific; `observed_locally_unvetted`.
- `knowledge/gotchas/test-fixtures.md` (2 entries) → both local plugin test-design observations; `observed_locally_unvetted`.

Backfill happens in the same branch as this work, so the lint check passes on land. The lint failing until backfill is done is intentional — it proves the check works.

**Migration script for consuming projects** — `scripts/backfill-knowledge-sources.sh`:

- Walks every topic file in `knowledge/`. For each H3 entry section missing a `**Source:**` line, appends `**Source:** observed_locally_unvetted` as the last line of the entry body (before the next `### ` or EOF).
- Idempotent (running twice is a no-op).
- One-shot — documented in v5.3 release notes as: "if your `knowledge/` pre-dates v5.3, run `scripts/backfill-knowledge-sources.sh ./knowledge` once to satisfy the new lint rule."

The script never inserts confident URLs into existing entries — it always inserts the honest `observed_locally_unvetted` marker. Users can then run `vetting-knowledge` to upgrade specific entries with real URLs.

## Testing

### Structural tests (mandatory)

| Target | Path | Asserts |
|---|---|---|
| `using-project-knowledge` skill | `tests/using-project-knowledge/test-structure.sh` | Frontmatter shape; presence of INDEX-read step; "do not auto-load topic files" guidance present |
| `reviser` agent | `tests/reviser/test-structure.sh` | Frontmatter (`name=reviser`, `color=teal`, `model=opus`, `effort=xhigh`); all 5 per-call fields named in body; anti-patterns block contains H3-preservation rule |
| Curator (extended) | `tests/curator/test-structure.sh` (extend) | New vetting step present; `**Source:**` emission rule present; three valid source forms documented; degraded-mode behavior described |
| `vetting-knowledge` skill | `tests/vetting-knowledge/test-structure.sh` | Step ordering (preflight → enumerate → vet → grep → write → surface → fix loop → async); report frontmatter shape documented; per-call block to reviser populated correctly |
| Lint check 4b | `tests/lint-knowledge/` (extend) | Fixture entry missing `**Source:**` → exit 1 with expected error message; URL / `observed_locally_unvetted` / `observed_locally_unvetted (...)` all pass |
| Backfill script | `tests/backfill-knowledge-sources/test.sh` | Fixture with mixed missing/present source lines → script adds missing, leaves present untouched; second run is a no-op (idempotent) |

All new test paths get wired into the `tests=(...)` array in `tests/claude-code/run-skill-tests.sh`.

### Integration tests (encouraged)

| Target | Path | What it does |
|---|---|---|
| `using-project-knowledge` end-to-end | `tests/using-project-knowledge/test-integration.sh` | Spin up a session in a fixture dir with a fake `knowledge/INDEX.md`; trigger an agent dispatch; verify INDEX appears in the agent's context |
| Reviser end-to-end | `tests/reviser/test-integration.sh` | Fixture topic file with a known-contradicted entry; dispatch reviser with a canned `CANONICAL_URL` (stable docs page or `file://` fixture); verify rewrite, source line, H3 preservation |
| Vetting-knowledge degraded path | `tests/vetting-knowledge/test-integration.sh` | No MCPs available (default test env); verify report writes with all entries bucketed as `unvetted (no search available)`; timestamped filename; frontmatter parses |

**Not covered by automated CI:**
The confirmed/contradicted paths of curator pre-write vetting and vetting-knowledge require live exa/Ref MCPs. These get manual verification notes in this design doc + a smoke-test checklist in v5.3 release notes. The degraded path IS automated — that's the more important contract (it's what most consumers will see).

## Reversibility / blast radius

| Component | Rollback |
|---|---|
| `using-project-knowledge` skill | Revert the one-line invocation in agent bodies; no data effect |
| Reviser agent | Remove `agents/reviser.md`; vetting-knowledge detects missing reviser and falls back to report-only |
| Curator pre-write vetting | Revert the new step in agent body; new entries land as `observed_locally_unvetted`, same as today's unvetted runs |
| Lint check 4b | Revert the check in `lint-knowledge.sh`. Already-backfilled entries continue to lint clean (the literal is valid in both eras) |
| Backfill | Pure additive text edit; `git revert` reverses it cleanly |

Worst-case land: every consuming project's `knowledge/` lint passes (post-backfill); subagents are agents-plus-INDEX; curator emits `observed_locally_unvetted` for everything (if exa/Ref absent). No degradation vs. current behavior, even if every new MCP capability fails to be discovered.

## Files affected

### New
- `skills/using-project-knowledge/SKILL.md`
- `skills/vetting-knowledge/SKILL.md`
- `agents/reviser.md`
- `scripts/backfill-knowledge-sources.sh`
- `tests/using-project-knowledge/test-structure.sh` (+ integration variant)
- `tests/reviser/test-structure.sh` (+ integration variant)
- `tests/vetting-knowledge/test-structure.sh` (+ integration variant)
- `tests/backfill-knowledge-sources/test.sh`

### Modified
- All 11 existing agent files in `agents/` — add the one-line `using-project-knowledge` invocation under "Before You Begin"
- `agents/curator.md` — add the pre-write vetting step + source emission rule + extended report format
- `agents/README.md` — librarian family row gains `reviser`
- `skills/finishing-a-development-branch/SKILL.md` — handle curator's new "Flagged for review" block in its DONE-pause interaction
- `skills/curating-knowledge/SKILL.md` — same handling
- `skills/linting-knowledge/SKILL.md` — surface the new check 4b errors
- `scripts/lint-knowledge.sh` — add Check 4b
- `docs/knowledge-schema.md` — add Source line section
- `tests/curator/test-structure.sh` — extend for new curator behavior
- `tests/lint-knowledge/` — extend with source-line fixtures
- `tests/claude-code/run-skill-tests.sh` — wire new test paths

### Backfilled in this branch
- `knowledge/patterns/repo-conventions.md` — add Source line to existing entry
- `knowledge/gotchas/bash-scripts.md` — add Source lines to both entries
- `knowledge/gotchas/test-fixtures.md` — add Source lines to both entries

## Open questions

1. **exa/Ref tool name shape.** The exact tool names depend on each MCP's installed surface. The spec instructs the curator/vetting-knowledge to detect via `mcp__exa__*` / `mcp__ref__*` prefix and use the search-shaped one. Implementation needs to confirm what the installed MCPs expose; if the prefix differs (e.g. `mcp__ref-tools__*` vs `mcp__ref__*`), the prefix list expands. Not a design issue — flagged for the planner to resolve at implementation time.

2. **Bash entry's canonical URL.** The "pipe into `while` discards array writes" entry will get a real URL during backfill. Specific URL is implementation detail (bash manual subshell section is the leading candidate).

## Future work (out of scope for this branch)

- **Code-fix loop on top of reviser.** If `vetting-knowledge` finds contradicted entries with `files_referencing` populated, optionally dispatch implementer-* agents to fix the code that follows the deprecated pattern. Requires careful guardrails (tests-first, review loop, real risk of unintended changes). Considered and explicitly deferred to keep v1 scoped.

- **`pattern_match:` field in entry frontmatter.** A structured regex/identifier list per entry would make codebase grep precise rather than best-effort. Defer until we see how often the best-effort grep produces useful signal.

- **Cross-entry consistency checks in the lint.** If two entries in the same topic file recommend opposing things, the lint could flag. Not addressed here.

- **Vetting telemetry.** Track per-project how often vetting flips entries' classifications over time (drift indicator). No infrastructure for telemetry exists; deferred.

- **Reviser handling of entry deletion.** If canonical guidance says "this entry's premise is invalid; the issue it describes doesn't exist" the right action might be entry removal, not rewrite. Out of scope; reviser only rewrites. User can manually delete.
