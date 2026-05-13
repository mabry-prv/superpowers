---
topic: bash-scripts
category: gotchas
last-updated: 2026-05-13
last-since: 702bc46
---

# Bash scripting gotchas

## Entries

### 2026-05-11 — Pipe into `while` discards array writes (subshell trap) (since 7ddaa9c)

`awk … | while IFS= read -r …; do warnings+=("$line"); done` runs the
`while` body in a subshell — every `warnings+=(...)` write is thrown away
when the pipeline ends. The outer script then renders an empty Warnings
section even though the inner loop "saw" hits.

**Why:** in bash, the right-hand side of a pipe forks a new shell. Array
mutations in that subshell never reach the parent. Caught during dev of
`scripts/lint-knowledge.sh` Check 6 (oversized-entry detection) — fix in
commit 7ddaa9c.

**Avoid:** use process substitution so the loop runs in the current shell:

```bash
while IFS=: read -r f title wc; do
    warn "oversized entry in $topic: $title ($wc words)"
done < <(awk '…' "$topic")
```

Any time a lint/check accumulates into an array inside a `while`, the
producer must be a `< <(…)` redirection, not a `producer | while`.
See `scripts/lint-knowledge.sh:69` for the working pattern.

**Source:** https://mywiki.wooledge.org/BashFAQ/024

### 2026-05-11 — `hooks/session-start` resolves `knowledge/INDEX.md` via `${PWD}` (since d77e453)

The session-start hook injects `knowledge/INDEX.md` only when
`${PWD}/knowledge/INDEX.md` exists — `${PWD}` is the directory Claude
Code was launched from, NOT a discovered repo root.

**Why:** the hook deliberately avoids `git rev-parse --show-toplevel` so
it works in non-git project roots and stays cheap. See
`hooks/session-start:31`.

**Avoid:** if a project's `knowledge/` lives at the repo root but the
user starts a session from a subdirectory, the INDEX won't be injected.
Document this in onboarding rather than "fixing" the hook to walk up —
the cwd contract is intentional.

**Source:** observed_locally_unvetted

### 2026-05-13 — `cmp -s tmp orig` idempotency guard for awk-rewrite scripts (since 702bc46)

When a script rewrites a file via an awk state machine, write to a
tmp file FIRST and only `mv` if the bytes differ:

```bash
awk '...' "$topic" > "$tmp"
if ! cmp -s "$topic" "$tmp"; then
    mv "$tmp" "$topic"
else
    rm -f "$tmp"
fi
```

**Why:** `scripts/backfill-knowledge-sources.sh` is idempotent by
contract — re-running it on already-backfilled files must not bump
mtimes or appear in `git status`. The test asserts this via
`shasum` comparison across two runs. A naive `awk ... > "$topic"`
truncates and rewrites every byte even when content is identical,
defeating idempotency and polluting CI signal.

**Avoid:** do not pipe directly back into the source file
(`awk ... > "$topic"` is also wrong because the shell truncates
`$topic` before awk starts reading). Always write to tmp + cmp + mv.
See `scripts/backfill-knowledge-sources.sh:80-86`.

**Source:** observed_locally_unvetted
