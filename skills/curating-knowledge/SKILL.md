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
