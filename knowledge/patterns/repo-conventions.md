---
topic: repo-conventions
category: patterns
last-updated: 2026-05-13
last-since: 918d21a
---

# Repo conventions (gitignore, base-branch resolution)

## Entries

### 2026-05-11 — Base-branch resolution: origin/HEAD → main → master (since d961e72)

When a skill or script needs the project's default branch (for
`git merge-base`, fork-point detection, etc.), use this three-step
fallback rather than hardcoding `main`:

```bash
$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's@^origin/@@' \
  || (git rev-parse --verify main >/dev/null 2>&1 && echo main) \
  || echo master)
```

**Why:** this repo supports both pre-`main` (legacy `master`) checkouts
and forks where origin/HEAD points elsewhere. Hardcoding `main` broke
the curator dispatch in `skills/finishing-a-development-branch/SKILL.md`
on master-default forks (fixed in d961e72).

**How:** if you write a new skill that resolves the base branch, paste
the snippet above and reference this entry. Step 2 (curator dispatch)
and Step 4 (base-branch determination) of finishing-a-development-branch
both use it — keep them in sync.

**Source:** observed_locally_unvetted

### 2026-05-11 — `.gitignore`: allow-list `settings.json` under blanket `.claude/` (since 27db24d)

The repo intentionally ignores everything under `.claude/` EXCEPT the
project's checked-in `settings.json`:

```
.claude/*
!.claude/settings.json
```

**Why:** `.claude/` holds per-user state (history, transcripts, local
session data) that must NOT be committed, but a single
`.claude/settings.json` carries project-level config (`worktree.baseRef`
pinned to `head`) that every clone needs.

**Avoid:** do NOT change `.claude/*` back to `.claude/` (directory
ignore) — git can't un-ignore a file under a directory-ignored parent;
the exception line silently stops working and `.claude/settings.json`
becomes invisible to `git status` on a fresh clone.

**Source:** observed_locally_unvetted

### 2026-05-11 — Lint-test artifacts must be gitignored under fixtures (since 52c7c83)

`scripts/lint-knowledge.sh` writes `<knowledge>/_meta/lint-report.md`
into whatever knowledge dir it lints. Running
`tests/lint-knowledge/test-lint.sh` against the bundled fixtures
therefore creates `tests/lint-knowledge/fixtures/{bad,clean}/knowledge/_meta/lint-report.md`.

**Why:** the test executes the real script for behavior fidelity; the
script has no `--dry-run`. Without ignore, every test run pollutes
`git status`.

**Avoid:** keep the `.gitignore` line
`tests/lint-knowledge/fixtures/*/knowledge/_meta/`. If a new fixture
tree is added under `tests/`, extend the pattern rather than removing
the write — the report is part of the script's contract.

**Source:** observed_locally_unvetted

### 2026-05-13 — Step 0 = `Skill('superpowers:using-project-knowledge')` for every plugin agent (since 44d2700)

Every plugin agent in `agents/*.md` now opens its "Before You Begin"
section with a numbered Step 0 that invokes the
`superpowers:using-project-knowledge` skill. The skill surfaces
`./knowledge/INDEX.md` (if present) as a system-reminder so the agent
gets situational awareness of prior patterns/gotchas before reading
its per-call context.

**Why:** project knowledge is *project-stable* context — it lives at a
known path and is identical across calls. Curating it per-task in the
dispatcher prompt would bloat every dispatch envelope. Letting the
agent self-load via a thin discovery skill keeps dispatcher payloads
focused on dynamic per-task context.

**How:** when adding a new agent under `agents/`, the first item of
"Before You Begin" must be:

```
0. Invoke `Skill('superpowers:using-project-knowledge')`. The skill
   will surface the project knowledge index (if any) into your context.
```

Wired into all 12 plugin agents in commits `ad67a98`, `5d24272`,
`44d2700`, `97def3d`. The discovery skill itself returns silently when
`./knowledge/` is absent, so the Step 0 invocation is safe in every
project.

**Source:** observed_locally_unvetted

### 2026-05-13 — Generated reports use Windows-safe ISO timestamp filenames (since df6bec3)

Files written by skills/scripts into `knowledge/_meta/` use the format
`YYYY-MM-DDTHHMMSSZ.md` (no colons, no fractional seconds, UTC `Z`).
See `skills/vetting-knowledge/SKILL.md:64-71` for the canonical
recipe:

```bash
TS=$(date -u +%Y-%m-%dT%H%M%SZ)
REPORT="knowledge/_meta/vetting-reports/${TS}.md"
```

**Why:** colons (`:`) are illegal in NTFS filenames; a standard ISO
timestamp `2026-05-13T14:23:00Z` would break Windows checkouts the
moment the report file lands on disk. The chosen format is still
ISO-8601 compliant (basic format for time-of-day) and remains
lexicographically sortable.

**Avoid:** do not write `date -u +%Y-%m-%dT%H:%M:%SZ` for any file
PATH (the lint-report's *generated header* string is fine — it's only
the FILENAME that matters). New report-style outputs (vetting,
linting, future audit skills) MUST follow the no-colon format.

**Source:** observed_locally_unvetted
