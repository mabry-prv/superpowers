# Superpowers (personal fork) — Working notes

This is a personal Claude-Code-only fork of obra/superpowers. The README has the project overview; this file has notes for working *on* the repo.

## Repo layout

- `.claude-plugin/` — Claude Code plugin manifest (`plugin.json`, `marketplace.json`).
- `hooks/session-start` — bootstraps the `using-superpowers` skill into every session.
- `hooks/run-hook.cmd` — cross-platform shim (no-op on Unix; harmless to keep).
- `skills/` — the 16 skills that make up the methodology.
- `tests/claude-code/` — fast skill tests + slow integration tests.
- `tests/skill-triggering/` — naive-prompt triggering tests.
- `tests/explicit-skill-requests/` — tests that named skill requests are honored.
- `tests/subagent-driven-dev/` — end-to-end SDD test fixtures.
- `tests/brainstorm-server/` — unit tests for the visual-companion server.

## Working on skills

Skill content shapes agent behavior. Use `superpowers:writing-skills` when editing — RED/GREEN/REFACTOR with adversarial pressure testing applies to documentation just like it does to code.

The Red Flags table in `skills/using-superpowers/SKILL.md` and the rationalization tables across other skills are carefully tuned. Don't reword them without running evals.

## Bumping version

```bash
./scripts/bump-version.sh --check        # show current versions
./scripts/bump-version.sh 5.2.0          # bump to a new version
```

The bumper updates `package.json`, `.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json` together. See `.version-bump.json`.

## Smoke test

After non-trivial edits, run `tests/claude-code/run-skill-tests.sh` and open a clean Claude Code session in this repo. Confirm `using-superpowers` content is visible in the system context.
