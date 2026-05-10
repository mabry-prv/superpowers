# Release Notes (personal fork)

## Forked

Forked from [obra/superpowers](https://github.com/obra/superpowers) at upstream v5.1.0 (2026-04-30) on 2026-05-09.

All upstream release notes prior to the fork are at the upstream repo. This file tracks changes made in the fork.

## Unreleased

- Stripped non-CC harness code paths (Cursor, Codex, Gemini, Copilot CLI, OpenCode). Repo is now Claude-Code only.
- Simplified README, CLAUDE.md, and PR template for personal-fork posture.
- Trimmed `docs/plans/` and `docs/superpowers/{plans,specs}/` (project history not relevant to fork).
- Trimmed `.version-bump.json` from 6 manifests to 3.
- Retargeted marketplace metadata at `superpowers-personal`; retargeted `.claude-plugin/plugin.json` author to Marcin and removed upstream `homepage`/`repository` URLs (README still credits upstream).
- Deleted `.github/FUNDING.yml` and `.github/ISSUE_TEMPLATE/` (personal fork; no third-party issue intake or Sponsors target). Kept `PULL_REQUEST_TEMPLATE.md`.
- Fixed CLAUDE.md skill count (`14` → `16`) after `multi-angle-review` and `dispatching-domain-agents` were added.
- Added `multi-angle-review` skill: dispatches role-specific reviewer subagents (multitenant-isolation, migration-safety, security) based on diff content. Three reviewer templates ship initially, each pressure-tested against planted-bug + clean counter-fixtures. Integration note added to `requesting-code-review/SKILL.md`. Composite end-to-end fixtures (`tests/multi-angle-review/fixtures/composite-bug` and `composite-clean`) checked in, with `tests/multi-angle-review/test-structure.sh` (always-run lint of templates + SKILL.md) and `tests/multi-angle-review/test-integration.sh` (opt-in via `--integration` — dispatches each reviewer against each fixture and asserts BLOCKED vs APPROVED). Both wired into `tests/claude-code/run-skill-tests.sh`.
- Tightened `multi-angle-review` reviewer templates after audit: `reviewer-security.md` adds path traversal, insecure deserialization (RCE-equivalent), SSRF, XXE to Critical and open redirect, ReDoS to Important; `reviewer-migration-safety.md` splits the NOT-NULL Critical rule to cover both `add NEW column with non-constant server_default on a large table` (table-rewrite outage) and `ALTER existing column to NOT NULL without prior backfill`.
- Broadened `multi-angle-review` SKILL.md routing predicates: multi-tenant fires on any `**/*.py` with org-scoped query patterns (not just `apps/api/**`); security predicate keyword list expanded with dynamic code execution (`eval`/`exec`/`compile`), deserialization (`pickle`, `yaml.load`, `marshal`), redirect/URL handling, regex on user input, XML parsing with external entities, and outbound calls with user-controlled host. Predicates explicitly framed as soft signals — "when in doubt, dispatch."
- Added `multi-angle-review` SKILL.md `## Error Handling` section covering reviewer timeouts, missing/unreadable templates, severity-conflict deduplication (max severity wins), and malformed verdict re-prompt-then-block.
- Added pre-dispatch placeholder substitution check in `multi-angle-review` SKILL.md — refuses to dispatch any prompt still containing `{DESCRIPTION}` / `{PLAN_OR_REQUIREMENTS}` / `{FILES_TO_REVIEW}` literally.
- Note on framework meta-plan progress (`~/.claude/plans/this-is-forked-repo-mossy-steele.md`): `multi-angle-review` shipped (this iteration). `dispatching-domain-agents` is in progress on a separate branch — scaffold + `implementer-default` template + implementation plan have landed; `implementer-fastapi`, `implementer-expo`, and the SKILL.md body are still pending. `scaffolding-saas-project` has not been started.
