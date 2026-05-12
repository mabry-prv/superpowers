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

- DO NOT auto-commit reviser output — user reviews `git diff` first per entry.
- Do NOT modify `INDEX.md` (the reviser doesn't either; the entry slug/hook isn't changing on a revision).
- DO NOT delete old report files — retention is the user's call.
- DO NOT run vetting against `knowledge/_meta/` (lint reports, vetting reports — they're not knowledge entries).
- DO NOT silently swallow MCP search errors — bucket the entry as `Unvetted (vetting error)` with the error noted.
- DO NOT refuse to run when exa/Ref are unavailable — degraded mode (all entries → Unvetted) is the intended fallback.
