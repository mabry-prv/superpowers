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
