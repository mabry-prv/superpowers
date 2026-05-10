# Release Notes (personal fork)

## Forked

Forked from [obra/superpowers](https://github.com/obra/superpowers) at upstream v5.1.0 (2026-04-30) on 2026-05-09.

All upstream release notes prior to the fork are at the upstream repo. This file tracks changes made in the fork.

## Unreleased

- Stripped non-CC harness code paths (Cursor, Codex, Gemini, Copilot CLI, OpenCode). Repo is now Claude-Code only.
- Simplified README, CLAUDE.md, and PR template for personal-fork posture.
- Trimmed `docs/plans/` and `docs/superpowers/{plans,specs}/` (project history not relevant to fork).
- Trimmed `.version-bump.json` from 6 manifests to 3.
- Retargeted marketplace metadata at `superpowers-personal`.
- Added `multi-angle-review` skill: dispatches role-specific reviewer subagents (multitenant-isolation, migration-safety, security) based on diff content. Three reviewer templates ship initially, each pressure-tested against planted-bug + clean counter-fixtures. Integration note added to `requesting-code-review/SKILL.md`. End-to-end tests confirmed parallel dispatch + correct aggregation on both paths: composite-bug fixture produces 7 Critical findings across 3 reviewers (BLOCKED); composite-clean fixture produces 0 Critical / 1 Important / 4 Suggestions (APPROVED WITH SUGGESTIONS).
