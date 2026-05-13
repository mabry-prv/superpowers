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

The lint script ships with the `superpowers` plugin at `scripts/lint-knowledge.sh` (relative to the plugin root). It accepts the knowledge directory as its single argument (defaults to `./knowledge`).

When running inside the plugin's own repo:

```bash
bash scripts/lint-knowledge.sh        # defaults to ./knowledge
bash scripts/lint-knowledge.sh /path/to/some/other/knowledge
```

When running inside a consuming project (the normal case): the plugin's resolved path is exposed via Claude Code's plugin mechanism. If `${CLAUDE_PLUGIN_ROOT}` is set in the agent's environment, prefer it:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/lint-knowledge.sh" ./knowledge
```

Otherwise, locate the cached plugin script with:

```bash
LINT=$(find "${HOME}/.claude/plugins/cache" -path '*superpowers*/scripts/lint-knowledge.sh' 2>/dev/null | head -1)
bash "$LINT" ./knowledge
```

The script writes its report to `<knowledge-dir>/_meta/lint-report.md` and exits with:
- 0 — clean (or only soft warnings)
- 1 — errors found
- 2 — usage error (e.g. directory not found)

### Step 2: Parse the Report

Read `knowledge/_meta/lint-report.md`. Three sections of interest:

- **Errors** — orphan INDEX hooks, missing frontmatter, dangling since-SHAs, **missing or malformed `**Source:**` lines (Check 4b)**. Must be fixed before next merge.
- **Warnings** — oversized entries (>200 words), oversized topics (>300 lines), missing Why/How/Avoid structure. Soft; user judgment.
- **Suggestions** — possible duplicates flagged by title overlap. Human review required.

### Step 3: Surface Findings

- For missing-Source errors (lint report line begins with `missing **Source:** line`): print the entry's topic-path and title; suggest either (a) re-running curator with vetting (to attempt URL discovery), (b) appending `**Source:** observed_locally_unvetted`, or (c) running `scripts/backfill-knowledge-sources.sh` for bulk backfill.
- For malformed-Source errors (lint report line begins with `malformed **Source:** value`): print the topic-path, title, and the offending value; show the three valid forms (URL / `observed_locally_unvetted` / `observed_locally_unvetted (hint)`).

For each error: print `file:line` (or topic name), what's wrong, how to fix.
For warnings + suggestions: print summary; offer to walk through.

## Anti-Patterns — What NOT to Do

**DO NOT:**
- Auto-fix issues — lint is a read-only health check, not a writer
- Skip warnings without surfacing them (the user may not notice the report file)
- Run lint as part of a hot path — it's a manual check, not session-start material
