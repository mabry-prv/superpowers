# Knowledge System — Schema

> The single source of truth for the `knowledge/` directory convention shipped by the `superpowers` plugin. Curator's prompt references this doc; humans editing knowledge entries follow the same rules; the lint script validates against it.

## Directory layout

```
<repo>/
├── knowledge/
│   ├── INDEX.md
│   ├── patterns/
│   │   └── <topic-slug>.md
│   ├── gotchas/
│   │   └── <topic-slug>.md
│   └── _meta/
│       └── lint-report.md
├── .knowledgeignore     # optional
└── …
```

## `knowledge/INDEX.md`

- One `# Knowledge Index` header.
- One `## <Category>` (e.g. `Patterns`, `Gotchas`) per category.
- Bullets under each category: `- **<slug>** — <≤120-char hook> — \`<category>/<slug>.md\``.
- Categories seeded as `Patterns` and `Gotchas`. Curator may add new categories autonomously when substantive content doesn't fit existing ones. Lint warns on single-entry categories that linger.

Example minimal INDEX:

````markdown
# Knowledge Index

## Patterns

- **auth** — Login + session shape + role checks — `patterns/auth.md`

## Gotchas

- **testing** — Flake causes, fixture ordering — `gotchas/testing.md`
````

## Topic file (`knowledge/<category>/<slug>.md`)

File-level frontmatter (single YAML block at top):

| Field | Type | Required | Notes |
|---|---|---|---|
| `topic` | string | yes | Slug; matches filename (without `.md`) |
| `category` | string | yes | Matches parent directory |
| `last-updated` | YYYY-MM-DD | yes | Date of most recent entry |
| `last-since` | SHA (short ok) | yes | SHA recorded with the most recent entry's (since <SHA>) annotation — typically the branch HEAD_SHA at the time of curation |

Body:
- One `# <Topic title>` H1
- One `## Entries` H2
- Dated entries as `### YYYY-MM-DD — <one-line entry title> (since <SHA>)` H3, append-only

Note: `last-since` (frontmatter) and `since: <SHA>` (in entry headers) refer to the same SHA at the time an entry is added. Older entries keep their original `since:` SHA; frontmatter `last-since` only tracks the most recent.

## Entry style

Soft guideline (lint warns on missing structure; doesn't fail):

1. **Lead** with the rule or gotcha (1-2 sentences).
2. **Why:** root cause / context (1 line).
3. **How:** or **Avoid:** prescription (1 line).
4. Concrete `file:line` references where useful.
5. ≤200 words per entry. Exceed → curator auto-splits into a new topic file rather than bloat existing one.

No generic advice ("use clean code", "write tests"). Every entry must be specific to THIS codebase.

### Source line

Every entry MUST end with a `**Source:**` line. Three valid forms:

- `**Source:** <URL>` — any string starting with `http://` or `https://`. Use when canonical documentation supports the entry.
- `**Source:** observed_locally_unvetted` — use when the entry captures a local observation the curator couldn't ground against canonical sources.
- `**Source:** observed_locally_unvetted (<optional hint>)` — same as above, with a short parenthetical hint (e.g. `observed_locally_unvetted (vetting skipped — exa/Ref unavailable)`).

Anything else is a lint error (hard). See `scripts/lint-knowledge.sh` Check 4b.

Example:

```markdown
### 2026-05-11 — BaseHTTPMiddleware breaks ContextVars (since abc1234)

Using `BaseHTTPMiddleware` from Starlette loses request-scoped ContextVars
between middleware and the route handler.

**Why:** Starlette runs `BaseHTTPMiddleware` via a TaskGroup; ContextVar
writes inside it don't propagate to the route handler's task.

**Avoid:** use pure ASGI middleware (`call/await scope, receive, send`)
for anything that mutates ContextVars.

**Source:** https://github.com/encode/starlette/issues/1273
```

## Naming

- Topic slugs: lowercase, hyphens. `auth.md`, `migrations.md`, `auth-session.md`.
- Auto-split convention: `<parent>-<sub>.md` (e.g. `auth.md` → `auth-session.md` + `auth-permissions.md`).

## `.knowledgeignore` (optional, repo root)

Gitignore-syntax veto. Curator skips diffs in matching paths. Anything in `.gitignore` is already implicitly excluded when the curator inspects `git diff` — untracked or git-ignored paths don't appear in the diff range.

Recommended uses: secrets, generated code, vendored deps.

```
.env*
secrets/**
generated/**
*.pb.go
```

NOT recommended: hiding "stuff I don't want documented" — that's curator-prompt discipline, not infrastructure.

## Bootstrap

First curator run in a project with no `knowledge/`:

1. Create `knowledge/`, `knowledge/patterns/`, `knowledge/gotchas/`, `knowledge/_meta/`
2. Create `knowledge/INDEX.md` with the seed template (two empty category sections)
3. Write any initial entries (if curator extracted lessons); otherwise the seed stays empty

Subsequent runs append/update only.

## Curator inputs (per-call context)

The curator agent's `## Per-Call Context` block declares:

- `WORKING_DIRECTORY` — project root
- `TASK_DESCRIPTION` — one-paragraph summary of branch work
- `PLAN_OR_SPEC` — path to spec/plan that drove the work (if any)
- `BASE_SHA` — branch base commit
- `HEAD_SHA` — branch tip commit
- `IMPLEMENTER_REPORT` — DONE / DONE_WITH_CONCERNS / BLOCKED report(s)
- `REVIEWER_REPORTS` — reviewer outputs
- `EXISTING_INDEX` — contents of `knowledge/INDEX.md` (empty string on first run)

Dispatchers MUST populate all eight fields before calling. `EXISTING_INDEX` may be the empty string when `knowledge/` does not yet exist (first run); all other fields require content.

## Curator output

Status verdict (last line of report): `DONE` | `NOTHING_TO_LEARN` | `NEEDS_CONTEXT`.

- `DONE` — N entries written across M topics. Wrapping skill pauses for `git diff knowledge/` review.
- `NOTHING_TO_LEARN` — Nothing worth capturing on this branch. No writes. Wrapping skill proceeds.
- `NEEDS_CONTEXT` — Required input missing/unreadable. No writes. Wrapping skill surfaces gap.

`BLOCKED:ARCHITECTURAL` is out-of-band for this agent. If emitted, wrapping skill surfaces as unexpected; does NOT dispatch architect.
