# multi-angle-review tests

Tests for the `multi-angle-review` skill (`skills/multi-angle-review/`).

## What's here

- `test-structure.sh` — fast, deterministic. Lints each reviewer template
  for required sections, placeholders, verdict strings, and severity-rule
  coverage. Lints `SKILL.md` for routing-table integrity and the three
  terminal verdict strings. **No `claude` CLI dependency.** Runs in
  seconds. Wired into the main runner's fast suite.
- `test-integration.sh` — slow, opt-in. Dispatches each reviewer template
  via headless `claude -p` against the checked-in fixtures and asserts
  verdicts. Requires `claude` in `PATH`. Wired into the main runner's
  `--integration` suite.
- `fixtures/composite-bug/` — composite end-to-end fixture containing
  planted bugs across all three reviewer domains (multitenant-isolation,
  migration-safety, security). Expected aggregate verdict: `BLOCKED`.
- `fixtures/composite-clean/` — composite counter-fixture with the same
  shape but bug-free. Expected aggregate: `APPROVED` (or
  `APPROVED WITH SUGGESTIONS`).

## Running

From the repo root:

```bash
# Structural only (fast)
bash tests/claude-code/run-skill-tests.sh

# Structural + integration (slow; requires `claude` CLI)
bash tests/claude-code/run-skill-tests.sh --integration
```

Or directly:

```bash
bash tests/multi-angle-review/test-structure.sh
bash tests/multi-angle-review/test-integration.sh
```

Override the per-reviewer integration timeout (default 180 s) via:

```bash
MAR_INTEGRATION_TIMEOUT=300 bash tests/multi-angle-review/test-integration.sh
```

## Why both layers

- **Structural** catches regressions in template or SKILL.md edits without
  spending tokens on a model. It runs on every change.
- **Integration** validates that an actual reviewer model still arrives at
  the expected verdict given the templates as written. It is
  nondeterministic and slow, so it's gated behind `--integration` and only
  run before merge or when the templates change.
