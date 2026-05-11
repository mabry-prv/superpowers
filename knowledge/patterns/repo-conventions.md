---
topic: repo-conventions
category: patterns
last-updated: 2026-05-11
last-since: 52c7c83
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
