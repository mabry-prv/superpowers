# Knowledge System — Design Spec

**Date:** 2026-05-11
**Status:** Approved (brainstorming)
**Author:** Marcin + Claude (brainstorming session)

---

## Context

Agents working in this repo (and any repo using the `superpowers` plugin) currently rediscover the same project-specific patterns and gotchas in every session. There is no shared, durable place for "how this codebase does X" or "this test flakes when Y." Skills hold *universal* methodology; `CLAUDE.md` holds *project conventions for humans + Claude Code at session start*; the user's auto-memory at `~/.claude/projects/.../memory/` is **private and conversational**. None of these accumulate the operational, agent-readable knowledge that emerges from successful and failed task executions.

This spec adds a **knowledge system** — a plugin-shipped convention plus a librarian agent (`curator`) that distills lessons from completed work into a structured, agent-readable directory inside each consuming project.

The pattern is inspired by Andrej Karpathy's "LLM Wiki" — markdown files maintained by an LLM, three operations (ingest → query → lint), no embeddings, plain-text storage. We adapt it to the superpowers context: the "raw" input is task output (diffs + reports), the "wiki" is the curated `knowledge/` directory, and lint is a manual sanity pass.

## Goals

1. Eliminate re-rediscovery of project-specific patterns and gotchas across sessions and branches.
2. Auto-grow without per-task ceremony — fires once per branch via existing terminal skill.
3. Universal read path — every agent sees the index in session context without per-agent prompt changes.
4. Plain markdown, git-tracked, human-reviewable.
5. Plugin-shipped — the convention and tooling live in `superpowers`; consuming projects own their content.

## Non-goals

1. **Architectural decisions / rationale.** Those belong in ADRs (separate doc convention). Curator does not capture them.
2. **User-preference / conversational memory.** That belongs in the personal auto-memory under `~/.claude/`. Curator's anti-pattern guidance excludes it.
3. **Plugin meta-knowledge / agent envelope rules.** Those stay in `agents/README.md` as static documentation.
4. **Retroactive backfill of pre-existing branches.** Going forward only (manual dispatch available for one-off backfills).
5. **Cross-project knowledge sharing.** Each project's `knowledge/` is its own; no cross-repo aggregation.
6. **Embeddings / vector search / RAG.** Index is one-line hooks per topic; full reads are explicit `Read` calls. No retrieval layer.

## Architecture

Two layers, clean separation.

### Plugin side (superpowers — this repo)

Defines the schema, the curator agent, the read path, the lint op. Ships no content.

```
superpowers/
├── agents/
│   ├── curator.md                       # NEW — librarian family
│   └── README.md                        # updated: librarian family entry
├── skills/
│   ├── curating-knowledge/              # NEW — thin dispatcher for curator
│   │   └── SKILL.md
│   ├── linting-knowledge/               # NEW — thin wrapper for lint script
│   │   └── SKILL.md
│   └── finishing-a-development-branch/  # MODIFIED — auto-dispatch curator
│       └── SKILL.md
├── hooks/
│   └── session-start                    # MODIFIED — inject INDEX content
├── scripts/
│   └── lint-knowledge.sh                # NEW — programmatic lint
└── docs/
    └── knowledge-schema.md              # NEW — single source of truth
```

### Consuming project side

Each consuming project gets a `knowledge/` directory at its repo root. Created on first curator run.

```
<repo>/
├── knowledge/
│   ├── INDEX.md                # auto-loaded; one-line hook per topic
│   ├── patterns/
│   │   ├── auth.md
│   │   └── …
│   ├── gotchas/
│   │   ├── testing.md
│   │   └── …
│   └── _meta/
│       └── lint-report.md      # last lint pass output (optional)
├── .knowledgeignore            # optional — gitignore-syntax veto
└── …
```

Top-level `knowledge/` (not `.claude/knowledge/`) for visibility: humans browse it, git tracks it, diffs are reviewable in PRs.

## Components

### `agents/curator.md`

New agent. Family: **librarian** (new family, color teal/cyan, one member for now). Model `opus`, effort `xhigh`.

**Per-Call Context fields:**

| Field | Purpose |
|---|---|
| `WORKING_DIRECTORY` | Project root (must contain or be allowed to create `knowledge/`) |
| `TASK_DESCRIPTION` | One-paragraph summary of what was attempted on this branch |
| `PLAN_OR_SPEC` | Path to the spec/plan that drove the work (if any) |
| `BASE_SHA` | Branch base commit |
| `HEAD_SHA` | Branch tip commit |
| `IMPLEMENTER_REPORT` | DONE / DONE_WITH_CONCERNS / BLOCKED report(s) |
| `REVIEWER_REPORTS` | Reviewer outputs (spec, code-quality) — rejected patterns surface conventions |
| `EXISTING_INDEX` | Contents of `knowledge/INDEX.md` (empty string on first run) |

**Captures:** project-specific patterns (reused or worth reusing); gotchas (test flakes, library footguns, ordering matters); conventions enforced by reviewer feedback.

**Skips:** ADR-style decisions; user-preference / conversational memory; superpowers-meta-knowledge.

**Status verdicts:** `DONE` | `NOTHING_TO_LEARN` | `NEEDS_CONTEXT`.

**Does NOT escalate `BLOCKED:ARCHITECTURAL`** — librarian role, not designer. If the curator emits architectural framing, the wrapping skill surfaces as unexpected (no architect dispatch).

**Mechanics:**
1. Read all inputs end-to-end. Run `git diff $BASE_SHA..$HEAD_SHA` for the diff.
2. Apply `.knowledgeignore` (if present) to filter file paths.
3. For each candidate learning: decide APPEND to existing topic (matches INDEX hook) or CREATE new topic.
4. Bootstrap on first run: create `knowledge/`, `patterns/`, `gotchas/`, `_meta/`, seed `INDEX.md`.
5. Auto-split: if appending pushes a topic file past 300 lines, split into sub-topics, update INDEX.
6. Each new/updated entry carries `since: <SHA>` for traceability.
7. Update `INDEX.md` hooks (one line per topic, ≤120 chars).
8. Report back.

### `skills/curating-knowledge/SKILL.md`

Thin dispatcher for the curator agent. Manual entry point (retroactive backfill, ad-hoc captures, or when the terminal skill is skipped). Fills the per-call context block and dispatches `Task(subagent_type=curator, …)`. Mirrors `writing-plans` skill shape (thin dispatcher → designer-family agent).

### `skills/linting-knowledge/SKILL.md`

Thin wrapper for `scripts/lint-knowledge.sh`. Runs the script, parses output, summarizes findings in chat. Manual trigger only.

### `skills/finishing-a-development-branch/SKILL.md` (modified)

Existing terminal skill. New step inserted between "confirm tests + reviewer pass" and "merge / PR":

1. (Existing) Confirm tests pass and reviewer-code-quality returned APPROVED.
2. **(NEW)** Auto-dispatch `curating-knowledge` with whole-branch context. Wait for completion.
3. **(NEW)** If curator returned `DONE`, pause: prompt user to review `git diff knowledge/` and commit/edit/discard before proceeding.
4. **(NEW)** If curator returned `NOTHING_TO_LEARN`, proceed silently.
5. **(NEW)** If curator returned `NEEDS_CONTEXT`, surface the gap to user; do not proceed until resolved.
6. (Existing) Proceed with merge / PR / cleanup.

### `hooks/session-start` (modified)

Existing hook is updated. New behavior: if `<cwd>/knowledge/INDEX.md` exists, read it and append its contents to the session-start output (the existing using-superpowers content stays). Output format:

```
[existing using-superpowers content]

---

# Project knowledge index (from knowledge/INDEX.md)

[verbatim contents of INDEX.md]
```

No-op when `knowledge/` doesn't exist. No agent prompts need to change.

### `scripts/lint-knowledge.sh`

Programmatic lint pass. Checks:

1. Every INDEX hook resolves to an existing topic file.
2. Every topic file has valid frontmatter (`topic`, `category`, `last-updated`, `last-since`).
3. Each entry has a `since: <SHA>` annotation.
4. `git cat-file -e <SHA>` passes for every `since:` ref (catches orphan SHAs post rebase/squash).
5. No entry exceeds the soft size cap (~200 words).
6. No topic file exceeds the soft split threshold (300 lines).
7. Best-effort duplicate detection (title overlap + simple textual similarity) — flagged for human review, not failed.
8. No empty / placeholder topics (zero entries linger).

Outputs `knowledge/_meta/lint-report.md`. Exit code: 0 on clean, 1 on errors, 0 with warnings on soft findings.

### `docs/knowledge-schema.md` (new)

Single source of truth for the conventions: INDEX format, topic file format, entry style, frontmatter shape, naming rules, bootstrap behavior, `.knowledgeignore` syntax. Curator's prompt references it directly. Humans editing entries follow the same doc.

## Data flow

### Write flow (auto, end-of-branch)

```
[user invokes superpowers:finishing-a-development-branch]
  ↓
[skill confirms tests pass + reviewer-code-quality APPROVED]
  ↓
[skill auto-dispatches curating-knowledge → curator agent with whole-branch context]
  ↓
[curator reads diff + reports + EXISTING_INDEX, applies .knowledgeignore]
  ↓
[curator writes to knowledge/ topic files + INDEX.md (or returns NOTHING_TO_LEARN)]
  ↓
[skill prompts: "curator added N entries — review git diff knowledge/ and commit"]
  ↓
[user reviews, commits / edits / discards]
  ↓
[skill resumes: merge / PR / cleanup]
```

### Write flow (manual)

```
[user invokes superpowers:curating-knowledge]
  ↓
[skill collects per-call context (TASK_DESCRIPTION, BASE/HEAD, …)]
  ↓
[skill dispatches curator]
  ↓
[curator runs identically to auto path]
  ↓
[user reviews git diff knowledge/, commits]
```

### Read flow (every session)

```
[Claude Code session starts in project repo]
  ↓
[hooks/session-start runs; checks <cwd>/knowledge/INDEX.md]
  ↓
[if present: hook appends INDEX content to session-start output]
  ↓
[every agent in the session sees the topic list in its context]
  ↓
[agents Read knowledge/<category>/<topic>.md on demand when hook matches task]
```

No agent prompts change. Universal access via the existing hook mechanism.

## Schemas

### `knowledge/INDEX.md`

```markdown
# Knowledge Index

## Patterns

- **auth** — Login, session shape, role checks — `patterns/auth.md`
- **migrations** — Two-phase NOT NULL, CONCURRENTLY indexes — `patterns/migrations.md`

## Gotchas

- **testing** — Flakes, fixture quirks, ordering pitfalls — `gotchas/testing.md`
- **deps** — Native-rebuild triggers, version pin reasons — `gotchas/deps.md`
```

- One H1, one H2 per category.
- Each bullet: `**slug** — ≤120-char hook — relative-path`.
- Categories seeded as `Patterns` and `Gotchas`. Curator may add new categories autonomously when substantive content doesn't fit existing ones (e.g., `Tooling`). Lint warns on single-entry categories.

### Topic file (e.g., `knowledge/patterns/auth.md`)

```markdown
---
topic: auth
category: patterns
last-updated: 2026-05-11
last-since: 3a1b2c4
---

# Auth patterns

## Entries

### 2026-04-15 — Org-scoped session factory (since 3a1b2c4)

[Lead: the rule/gotcha. Then a one-line **Why:** root cause / context. Then a one-line **How:** or **Avoid:** prescription. Concrete `file:line` references where useful. No generic advice. ≤200 words.]

### 2026-05-02 — Token rotation on login (since 8d2e0a1)

…
```

- File-level frontmatter (single block at top).
- Entries are dated H3 sections, **append-only**, each with `since: <SHA>` traceability.
- Entry style (soft guideline; lint warns on missing): Lead-rule → Why → How/Avoid.
- Soft size cap: ~200 words per entry.

### Naming

- Topic slug: lowercase, hyphens, no extension surprises. `auth-session.md`, `migrations.md`.
- Sub-topic split (after auto-split): `<parent>-<sub>.md`. E.g., `auth.md` → `auth-session.md` + `auth-permissions.md`.

### `.knowledgeignore` (optional, repo root)

Gitignore-syntax veto. Curator skips diffs in matching paths. Examples:

```
# Don't capture secrets
.env*
secrets/**

# Don't capture from generated code
generated/**
*.pb.go
```

Curator reads `.knowledgeignore` on every run. Anything in `.gitignore` is already implicitly excluded (curator works against git diff).

## Edge cases

| Situation | Behavior |
|---|---|
| User discards everything | `git checkout -- knowledge/`; branch merges clean. No persistent state from the rejected run. |
| User edits curator output before commit | Edits land in the diff like any manual change. INDEX may need touch-up if entry titles changed; lint catches mismatches. |
| Stale `since:` SHA after rebase/squash | Lint flags via `git cat-file -e`; user re-anchors to the new tip-SHA. |
| Concurrent branches both update same topic | Standard git merge. Run lint after merge for structural sanity. Future work: 3-way curator merge mode if this becomes a pain point. |
| Curator can't classify cleanly | Prefers best-fit existing category. Only spawns a new category when content clearly belongs to none and is substantive. |
| Topic grows past comfort threshold (300 lines) | Curator auto-splits into sub-topics on the next entry, updates INDEX. |
| Curator wants to capture content matching `.knowledgeignore` | Silently skipped. Lint won't flag (intentional exclusion). |
| First-time bootstrap in fresh project | Curator auto-creates `knowledge/`, `patterns/`, `gotchas/`, `_meta/`, seed `INDEX.md`. No opt-in prompt. |
| Empty diff or empty reports | Curator returns `NEEDS_CONTEXT` — wrapping skill surfaces the gap. |
| `BLOCKED:ARCHITECTURAL` emitted by curator | Out-of-band. Wrapping skill surfaces as unexpected; does not dispatch architect. |
| Personal auto-memory vs project knowledge | No content overlap by design. Auto-memory = user preferences / conversational. Project knowledge = code-anchored, shared. Curator's anti-pattern guidance enforces. |

## Adoption

For an existing consuming project:

1. Install / update the `superpowers` plugin.
2. Work normally; invoke `superpowers:finishing-a-development-branch` when wrapping up a branch.
3. Curator runs automatically. First time, bootstraps the `knowledge/` directory.
4. User reviews `git diff knowledge/`, commits, merges.
5. From the next session forward, `INDEX.md` is auto-included in session context.

No "enable knowledge system" command. First curator run is the bootstrap event.

### Plugin self-adoption

The `superpowers` repo itself will run the curator on its own branches once shipped. Plugin gets a top-level `knowledge/` directory. Plugin-development gotchas (skill-authoring patterns, agent envelope rules, test patterns) accumulate there. `agents/README.md` continues to hold static documentation; the two don't overlap.

## Testing

Mirrors the existing `tests/<agent>/test-structure.sh` convention. Pure grep + file-existence checks. No agent execution. Integration tests deferred.

### Structural tests (new)

| Test | What it asserts |
|---|---|
| `tests/curator/test-structure.sh` | Frontmatter (name=curator, family/color, model, effort); envelope sections (Per-Call Context, Your Job, Anti-Patterns, Report Format); per-call field names; status verdicts |
| Cross-file checks (same test) | `superpowers:curating-knowledge` dispatches by `subagent_type=curator`; `superpowers:finishing-a-development-branch` references curator step; `docs/knowledge-schema.md` curator-input fields match agent's declared fields |
| `tests/lint-knowledge/test-lint.sh` | Bad-fixture sweep (orphan hooks, missing frontmatter, oversized entries, dangling SHAs); clean-fixture pass |

### Test runner registration

Append `../curator/test-structure.sh` and `../lint-knowledge/test-lint.sh` to `tests/claude-code/run-skill-tests.sh`'s `tests=(...)` array. Structural count: 6 → 8.

### Deferred follow-ups (separate plan)

1. End-to-end integration test for `finishing-a-development-branch` → curator dispatch (slow, agent-execution).
2. Curator quality eval (does it make *good* choices?) — manual during initial rollout.
3. Cross-branch dedup / 3-way merge mode for `knowledge/` topic files.
4. Optional `.knowledgemap` (curator-maintained mapping of topic → code paths) for richer querying.

## Risks & open items

| Risk | Mitigation |
|---|---|
| Curator hallucinates content (e.g., invented patterns, wrong SHA) | User reviews via `git diff knowledge/` before commit. Lint catches structural defects (bad SHA, missing frontmatter). |
| Knowledge grows stale as code evolves | Soft `since: SHA` traceability; lint flags orphan SHAs. Periodic manual `superpowers:linting-knowledge` pass. |
| Curator misclassifies entries (puts a gotcha under patterns) | User can fix in the diff review. Lint best-effort flags single-entry categories. |
| Token cost of always-loaded INDEX | INDEX is bounded by design (~120-char hook per topic, two seed categories). At 50 topics: ~6KB. Acceptable. |
| Adoption friction in projects that skip `finishing-a-development-branch` | Manual `superpowers:curating-knowledge` skill remains available. Document the trigger in skill docs. |
| Merge conflicts in `knowledge/INDEX.md` when many branches in flight | Standard git resolution. INDEX bullets are line-based; conflicts should be minor. Lint after merge. |
| `.knowledgeignore` overuse hiding real lessons | Convention guidance in `docs/knowledge-schema.md`: ignore only secrets / generated / vendored, not "stuff I don't want documented." |

## Inspirations

- [Andrej Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — original pattern (raw/wiki/CLAUDE.md split, three operations).
- [VentureBeat coverage](https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an) — context on the LLM-as-compiler framing.
- [AGENTS.md (Linux Foundation)](https://agents.md/) — cross-tool agent conventions; ours stays Claude-Code-flavored but the convention spirit is shared.
- [Claude Code memory layers](https://code.claude.com/docs/en/memory) — native memory primitives (MEMORY.md, Memory Tool, Subagent Memory). Our knowledge system is **complementary**, not a replacement: native memory is per-user/per-session/per-subagent; knowledge is repo-shared and code-anchored.
