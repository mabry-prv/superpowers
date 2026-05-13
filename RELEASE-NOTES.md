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
- Fixed CLAUDE.md skill count (`14` → `16`) after `multi-angle-review` and `dispatching-domain-agents` were added.
- Added `multi-angle-review` skill: dispatches role-specific reviewer subagents (multitenant-isolation, migration-safety, security) based on diff content. Three reviewer templates ship initially, each pressure-tested against planted-bug + clean counter-fixtures. Integration note added to `requesting-code-review/SKILL.md`. Composite end-to-end fixtures (`tests/multi-angle-review/fixtures/composite-bug` and `composite-clean`) checked in, with `tests/multi-angle-review/test-structure.sh` (always-run lint of templates + SKILL.md) and `tests/multi-angle-review/test-integration.sh` (opt-in via `--integration` — dispatches each reviewer against each fixture and asserts BLOCKED vs APPROVED). Both wired into `tests/claude-code/run-skill-tests.sh`.
- Tightened `multi-angle-review` reviewer templates after audit: `reviewer-security.md` adds path traversal, insecure deserialization (RCE-equivalent), SSRF, XXE to Critical and open redirect, ReDoS to Important; `reviewer-migration-safety.md` splits the NOT-NULL Critical rule to cover both `add NEW column with non-constant server_default on a large table` (table-rewrite outage) and `ALTER existing column to NOT NULL without prior backfill`.
- Broadened `multi-angle-review` SKILL.md routing predicates: multi-tenant fires on any `**/*.py` with org-scoped query patterns (not just `apps/api/**`); security predicate keyword list expanded with dynamic code execution (`eval`/`exec`/`compile`), deserialization (`pickle`, `yaml.load`, `marshal`), redirect/URL handling, regex on user input, XML parsing with external entities, and outbound calls with user-controlled host. Predicates explicitly framed as soft signals — "when in doubt, dispatch."
- Added `multi-angle-review` SKILL.md `## Error Handling` section covering reviewer timeouts, missing/unreadable templates, severity-conflict deduplication (max severity wins), and malformed verdict re-prompt-then-block.
- Added pre-dispatch placeholder substitution check in `multi-angle-review` SKILL.md — refuses to dispatch any prompt still containing `{DESCRIPTION}` / `{PLAN_OR_REQUIREMENTS}` / `{FILES_TO_REVIEW}` literally.
- Added `dispatching-domain-agents` skill: routes SDD's implementer dispatch to a domain-specific template based on the task's primary file paths. Three templates ship: `implementer-default.md` (mirrors upstream), `implementer-fastapi.md` (SQLAlchemy 2.0 async, multi-tenant session factory rule, Pydantic v2, Alembic etiquette, OpenAPI completeness), `implementer-expo.md` (expo-router, TypeScript-first, native-rebuild constraints, Hermes, MobileMCP for verification). Each specialized template comparative RED/GREEN-validated: same fixture, same model (sonnet), default-vs-specialized template. Both produced 6+ template-specific improvements over the default baseline at the same correctness floor. Integration note added to `subagent-driven-development/SKILL.md`. Phase 1.5 deferred refactor: move templates into Claude Code agent definitions (`agents/*.md`) so the skill becomes a router that dispatches `Task(subagent_type=implementer-fastapi, ...)` directly — same content, cleaner delivery.
- Note on framework meta-plan progress (`~/.claude/plans/this-is-forked-repo-mossy-steele.md`): `multi-angle-review` shipped. `dispatching-domain-agents` shipped (this iteration). `scaffolding-saas-project` remains the last Phase 1 skill; not yet started.
- **Phase 1.5 — templates → agent definitions.** Lifted the canonical content of all six prompt templates out of `skills/<skill>/templates/` and into proper Claude Code agent definitions at `agents/` (plugin root, auto-discovered). Six agents shipped: three reviewers (`reviewer-multitenant-isolation`, `reviewer-migration-safety`, `reviewer-security`) and three implementers (`implementer-default`, `implementer-fastapi`, `implementer-expo`). Each agent's frontmatter declares `name` (matches filename, used as `subagent_type` lookup key), `description` (when-to-use), and `color`; `model` and `tools` left unset (inherit). Each agent body documents a `## Per-Call Context` section so callers know what fields to pass. Both orchestrator skills refactored: `multi-angle-review/SKILL.md` Process step 4 and `dispatching-domain-agents/SKILL.md` Process step 3 now dispatch via `Task(subagent_type=<agent-name>)` with a structured context block instead of rendering full templates inline. The pre-dispatch placeholder-substitution check became a per-call field-population check. The two `templates/` directories and 8 files (1223 lines) were removed atomically. Structure tests updated to assert against `agents/` paths and to verify the per-call-context contract instead of placeholder presence; integration test updated to load agent bodies from the new path. Reference examples followed: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/feature-dev/agents/code-architect.md` and `pr-review-toolkit/agents/code-reviewer.md`.

## v5.3.0 — Knowledge discovery + vetting

### What's new

- **Discovery layer.** Every plugin agent (architect, planner, three implementer variants, five reviewers, curator, and the new reviser) now invokes `superpowers:using-project-knowledge` as Step 0 of "Before You Begin". The skill loads `./knowledge/INDEX.md` (if present) into the agent's context. Silent return when absent — no failures, no consuming-project changes required.
- **Source provenance.** Every entry in `knowledge/` now carries a `**Source:**` line. Three valid forms: a canonical URL, the literal `observed_locally_unvetted`, or `observed_locally_unvetted (<hint>)`. Lint Check 4b enforces this as a hard error.
- **Curator pre-write vetting.** Before writing each candidate, the curator detects available MCPs (`mcp__exa__*` / `mcp__ref__*`), constructs a focused search query, and classifies the candidate as Confirmed (canonical URL recorded), Unvetted (no canonical hit), or Contradicted (NOT written; surfaced for user review). Degrades gracefully to all-Unvetted when no MCPs are available.
- **`superpowers:vetting-knowledge` skill.** On-demand audit of every entry against canonical sources. Produces a timestamped report at `knowledge/_meta/vetting-reports/<ISO>.md` (machine-readable YAML frontmatter + human-readable body). Offers to dispatch the new `reviser` agent per contradicted entry.
- **`reviser` librarian agent.** Sibling to `curator`. Takes one contradicted entry + canonical URL/summary, rewrites the entry in place to align with canonical guidance, preserves the H3 date and since-SHA verbatim, does NOT modify INDEX or other entries.

### Migration

If your `knowledge/` directory pre-dates v5.3, run the one-shot backfill once:

```bash
bash <CLAUDE_PLUGIN_ROOT>/scripts/backfill-knowledge-sources.sh ./knowledge
```

The script appends `**Source:** observed_locally_unvetted` to every entry missing a Source line; existing Source lines are untouched. Idempotent.

### Smoke-test checklist (manual; not in CI)

- [ ] After updating, run any plugin agent and confirm the project knowledge INDEX (if any) appears in its context as a system-reminder
- [ ] Run `superpowers:vetting-knowledge` against a project with knowledge; confirm a timestamped report is written
- [ ] In a project with exa/Ref MCPs, run curator on a branch; confirm new entries get `**Source:** <URL>` (not `observed_locally_unvetted`)
- [ ] Run `superpowers:linting-knowledge`; confirm it surfaces missing-Source errors with remediation options
