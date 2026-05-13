# Knowledge Index

## Patterns

- **repo-conventions** — Base-branch fallback chain; `.gitignore` allow-listing; lint-artifact ignores; Step 0 = using-project-knowledge; Windows-safe ISO timestamps — `patterns/repo-conventions.md`
- **librarian-agents** — Librarians return NEEDS_CONTEXT (never BLOCKED:ARCHITECTURAL); dispatcher must verify all per-call fields; reviser preserves H3 + since-SHA verbatim — `patterns/librarian-agents.md`

## Gotchas

- **bash-scripts** — `producer | while array+=()` loses writes; session-start hook keys on `${PWD}`; awk-rewrite scripts need `cmp -s` idempotency guard — `gotchas/bash-scripts.md`
- **test-fixtures** — Fixtures must violate the threshold they test; structural-test regexes bake in literal phrasing; integration tests SKIP on rc=0 + missing artifact — `gotchas/test-fixtures.md`
