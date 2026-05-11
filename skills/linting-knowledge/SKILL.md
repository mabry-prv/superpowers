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
