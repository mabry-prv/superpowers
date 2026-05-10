# Agent Set Extension — Design Spec

**Date:** 2026-05-10
**Status:** Draft

## Goal

Close the pipeline-coverage gap: every step of the brainstorm → plan → implement → review pipeline that benefits from a fresh-context subagent should be backed by a **named agent file** with pinned model and effort, not by an inline prompt template inside a skill.

Today, three role-bearing subagent calls dispatch `subagent_type=general-purpose` with their full prompt inlined: per-task spec compliance review, per-task code-quality review, and the standard whole-branch code review. Two pipeline roles have no subagent presence at all: plan-writing (runs in main session) and architectural consultation (no equivalent exists). This spec adds four agent files and aligns the consuming skills to dispatch them by name.

## Non-goals

- **Renaming or restructuring the existing six agents.** The path-based implementer split (`fastapi`, `expo`, `default`) and the concern-based reviewer split (`security`, `multitenant-isolation`, `migration-safety`) stay as-is.
- **Stack-specialized planners or architects.** One generic of each. Specialized variants (`planner-fastapi`, `architect-expo`, etc.) can be added later if real use justifies them, using the same "Adding a New Agent" process documented in the existing dispatching skills.
- **A `dispatching-design-agents` skill.** With one planner and one architect there is nothing to route between. If multiple variants ever exist, the skill can be added then.
- **Brainstorming as a subagent.** Brainstorming is interactive Q&A with the user; delegating it would force every user message through a relay. It stays in the main session.
- **A `debugger` agent.** Systematic debugging is reactive and is already covered by the `superpowers:systematic-debugging` skill from main session. Out of scope here.

## Agent inventory (the four new agents)

| Name | Color | Model | Effort | Trigger | Purpose |
|---|---|---|---|---|---|
| `reviewer-spec` | red | opus | xhigh | Per-task, after implementer reports DONE | Verify code matches the plan task — no missing requirements, no extra unrequested work |
| `reviewer-code-quality` | red | opus | xhigh | Per-task after spec review passes; **and** as the final whole-branch reviewer | Verify implementation is well-built (separation, tests, naming, file size). One agent, two scopes — per-call `SCOPE` field selects which checklist applies |
| `planner` | green | opus | max | When `brainstorming` skill terminates with an approved spec | Take a design spec, produce an implementation plan with tasks at `docs/plans/YYYY-MM-DD-<topic>.md` |
| `architect` | blue | opus | max | When an implementer reports BLOCKED citing a specific architectural ambiguity ("requires architectural decisions with multiple valid approaches" — the existing escalation rule from the implementer envelope); or directly by main session for a one-off design question. NOT for routine implementation choices | Non-interactive design consultation — given a question + context, return options, tradeoffs, recommendation. Does NOT modify code |

### Color logic

- Warm (pink, orange, yellow) = implementer family.
- Red = reviewer family (existing convention; all three current reviewers are red).
- Cool (green, blue) = designer family — visually distinct from both existing families.

### Effort logic

- `reviewer-spec` and `reviewer-code-quality`: `xhigh` — mechanical checking against a known target.
- `planner` and `architect`: `max` — high-judgment generative work where deeper reasoning pays off.

### System prompt envelope

Every new agent follows the existing 9-section structure already used by the six current agents:

1. Frontmatter (name, description, color, model, effort)
2. Role statement
3. Per-call context fields
4. Before You Begin
5. Your Job
6. Role-specific guidance (the meaty part)
7. When You're in Over Your Head (escalation)
8. Self-review (where applicable)
9. Report format

The role-specific guidance for each:

- **`reviewer-spec`**: lifted from `skills/subagent-driven-development/spec-reviewer-prompt.md`.
- **`reviewer-code-quality`**: merge of `skills/subagent-driven-development/code-quality-reviewer-prompt.md` and `skills/requesting-code-review/code-reviewer.md`. Body has two checklists; per-call `SCOPE` field gates which applies.
- **`planner`**: adapted from `skills/writing-plans/SKILL.md` — input is a spec path, output is a written plan file.
- **`architect`**: new content. Inputs: scoped question, code/spec context, constraints, prior attempts. Output: 2–3 options with tradeoffs, plus a recommendation and reasoning. Explicitly does NOT implement.

## Dispatch contracts

Each new agent has a labeled per-call context block. Every dispatcher MUST verify all fields are populated before calling — same rule as `multi-angle-review`'s "substep is the only mechanical guard between 'forgot to fill the field' and 'reviewer produces a confident review on empty context'."

### `reviewer-spec`

Dispatched by: `subagent-driven-development`.

```
TASK_NUMBER: <e.g. "Task 3">
TASK_NAME: <short task name from the plan>
TASK_REQUIREMENTS: <full text of the task as it appears in the plan>
IMPLEMENTER_REPORT: <what the implementer claims they built>
FILES_TO_REVIEW: <paths or git range covering exactly this task's commits>
```

Returns: `✅ Spec compliant` or `❌ Issues: [missing X, extra Y, with file:line refs]`.

### `reviewer-code-quality`

Dispatched by: `subagent-driven-development` (per-task), `requesting-code-review` (whole-branch).

```
SCOPE: per-task | whole-branch
DESCRIPTION: <brief summary of what was built>
PLAN_OR_REQUIREMENTS: <plan file path, task text, or requirements>
BASE_SHA: <starting commit>
HEAD_SHA: <ending commit>
```

Returns: Strengths / Issues (Critical / Important / Minor) / Recommendations / Assessment + verdict line.

### `planner`

Dispatched by: `brainstorming` (terminal step), `writing-plans` (when invoked directly via `/writing-plans`).

```
SPEC_PATH: <path to the design spec, e.g. docs/superpowers/specs/2026-05-10-foo-design.md>
WORKING_DIRECTORY: <where the planner should work from>
PROJECT_CONTEXT: <relevant existing structure — apps/api layout, tech stack, conventions>
CONSTRAINTS: <hard constraints from brainstorm — must not break X, must ship by Y, etc.>
```

Returns: writes plan to `docs/plans/YYYY-MM-DD-<topic>.md`, reports the path back, summarizes task count and dependencies.

### `architect`

Dispatched by: `subagent-driven-development` orchestrator (when implementer escalates BLOCKED with architectural cause); or directly by main session for ad-hoc consultation.

```
QUESTION: <the specific design question — single, scoped>
CODE_CONTEXT: <relevant file contents or excerpts — what already exists>
CONSTRAINTS: <invariants, conventions, performance / security / compliance requirements>
PRIOR_ATTEMPTS: <what's been tried or considered, if any>
DECISION_OWNER: <who will act on the recommendation — usually "main session" or "implementer for Task N">
```

Returns: 2–3 options, each with a tradeoff analysis, plus a recommendation and the reasoning. Does NOT modify code.

## Skill changes

### Skills updated

| Skill | Change |
|---|---|
| `subagent-driven-development/SKILL.md` | (a) Spec review step → `subagent_type=reviewer-spec`. (b) Code quality review step → `subagent_type=reviewer-code-quality` with `SCOPE: per-task`. (c) Add a paragraph on handling BLOCKED with architectural cause: dispatch `subagent_type=architect`, feed result back to implementer in re-dispatch |
| `requesting-code-review/SKILL.md` | Dispatch `subagent_type=reviewer-code-quality` with `SCOPE: whole-branch`. Skill body shrinks to ~30 lines: intro paragraph, "when to use" section, the dispatch block (Task call with the per-call context), and the verdict-handling rules |
| `brainstorming/SKILL.md` | Terminal step changes from "invoke writing-plans skill" to "dispatch `subagent_type=planner` with the spec path." Update flow diagram accordingly |
| `writing-plans/SKILL.md` | Skill body shrinks to ~30 lines: intro, "when to use," the dispatch block (Task call with `subagent_type=planner` and the per-call context), and the wait-for-result behavior. Canonical "how to write a plan" content (task structure, test-strategy guidance, Files-section format, etc.) moves into `agents/planner.md`. Skill keeps user-invocability via `/writing-plans` |
| Each `agents/implementer-{fastapi,expo,default}.md` | Add one paragraph in "When You're in Over Your Head": when blocker is architectural, the report should explicitly request the orchestrator dispatch the architect agent (not just generic BLOCKED) |

### Files deleted

| File | Reason |
|---|---|
| `skills/subagent-driven-development/spec-reviewer-prompt.md` | Content now in `agents/reviewer-spec.md` |
| `skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Content merged into `agents/reviewer-code-quality.md` |
| `skills/subagent-driven-development/implementer-prompt.md` | Already redundant with implementer agent files (matches the existing "delete templates/ dirs" cleanup pattern from recent commits) |
| `skills/requesting-code-review/code-reviewer.md` | Content merged into `agents/reviewer-code-quality.md` |

### Files added

| File | Purpose |
|---|---|
| `agents/reviewer-spec.md` | New agent (per inventory) |
| `agents/reviewer-code-quality.md` | New agent — per-task + whole-branch checklists, gated by `SCOPE` |
| `agents/planner.md` | New agent — content lifted+adapted from `writing-plans/SKILL.md` |
| `agents/architect.md` | New agent — fresh content (no existing source) |
| `agents/README.md` | Naming convention, per-call-context contract, "how to add a new agent" reference, color/model/effort conventions |

### Skills NOT changed

`dispatching-domain-agents`, `multi-angle-review`, the existing reviewer/implementer agent files — already follow the named-subagent dispatch pattern.

`using-superpowers`, `using-git-worktrees`, `executing-plans`, `finishing-a-development-branch`, `verification-before-completion`, `receiving-code-review`, `systematic-debugging`, `test-driven-development`, `writing-skills`, `dispatching-parallel-agents` — none dispatch role-bearing subagents that need promotion.

## Tests

Each new agent gets a structural test + an integration test, mirroring the `tests/multi-angle-review/` layout (pure-grep `test-structure.sh`, `claude` CLI–driven `test-integration.sh`, plus a `fixtures/` directory).

```
tests/
├── reviewer-spec/
│   ├── fixtures/
│   │   ├── missing-requirement/    # implementer skipped a requirement → expect ❌
│   │   ├── extra-feature/          # implementer added unrequested feature → expect ❌
│   │   └── compliant/              # clean implementation → expect ✅
│   ├── test-structure.sh
│   └── test-integration.sh
├── reviewer-code-quality/
│   ├── fixtures/
│   │   ├── per-task-quality-issue/    # bloated file or poor naming, SCOPE: per-task
│   │   ├── whole-branch-issue/        # cross-file architectural problem, SCOPE: whole-branch
│   │   └── clean/                     # well-built code, both scopes
│   ├── test-structure.sh
│   └── test-integration.sh
├── planner/
│   ├── fixtures/
│   │   ├── small-spec/             # ~3-task plan
│   │   ├── medium-spec/            # ~10-task plan with dependencies
│   │   └── too-large-spec/         # planner should flag scope and suggest decomposition
│   ├── test-structure.sh
│   └── test-integration.sh
├── architect/
│   ├── fixtures/
│   │   ├── pure-design-q/          # "should X be a column or a JSON blob?" → 2-3 options + recommendation
│   │   ├── refactor-q/             # "is it worth extracting Y now?" → tradeoffs
│   │   └── ambiguous-q/            # underspecified question → architect should ask back, not invent
│   ├── test-structure.sh
│   └── test-integration.sh
```

`tests/claude-code/run-skill-tests.sh` already wires up the existing test scripts; if it doesn't pick these up by convention, the runner gets a one-line addition per new test directory.

## `agents/README.md` outline

```
# Agents

Plugin-shipped agents dispatched via `Task(subagent_type=<agent-name>, ...)`.

## Agent families

| Family | Naming | Color | Role |
|---|---|---|---|
| Implementer | `implementer-<stack>` | warm (pink, orange, yellow) | Writes code+tests for one task |
| Reviewer | `reviewer-<concern>` | red | Reads code, returns verdict + findings |
| Designer | `planner` / `architect` | cool (green, blue) | Produces plans or design recommendations |

## Frontmatter contract

Every agent file has frontmatter with: `name`, `description`, `color`, `model`, `effort`.
The `name` MUST equal the filename minus `.md` — that's the `subagent_type` lookup key.

## System prompt envelope

[the 9-section structure: role, per-call context, before-you-begin, your job,
 role-specific guidance, when in over your head, self-review, anti-patterns,
 report format]

## Per-call context contract

Every dispatcher MUST populate every field in the agent's per-call context block before calling.
A missing field would cause the agent to hallucinate output on empty context. Verify before dispatch.

## Per-call context fields by agent

[compact table listing all 10 agents with their per-call context fields, so the
 contract is in one place rather than scattered across skill files]

## Adding a new agent

1. Write the agent body, following an existing agent in the same family as a template.
2. If routing logic is needed (multiple variants), add a row to the relevant dispatching skill.
3. Add a fixture-based test under `tests/<agent-name>/`. Pressure-test RED→GREEN.
4. Commit fixture + agent + skill change + README row together.
```

## End-state agent set (10 agents)

| Family | Name | Triggered by |
|---|---|---|
| Implementer | `implementer-fastapi` | `dispatching-domain-agents` (paths in `apps/api/**`) |
| Implementer | `implementer-expo` | `dispatching-domain-agents` (paths in `apps/mobile/**`) |
| Implementer | `implementer-default` | `dispatching-domain-agents` (mixed/other paths) |
| Reviewer | `reviewer-spec` *(new)* | `subagent-driven-development` (per-task spec gate) |
| Reviewer | `reviewer-code-quality` *(new)* | `subagent-driven-development` (per-task quality gate) + `requesting-code-review` (whole-branch) |
| Reviewer | `reviewer-security` | `multi-angle-review` (security-touching diff) |
| Reviewer | `reviewer-multitenant-isolation` | `multi-angle-review` (org-scoped query diff) |
| Reviewer | `reviewer-migration-safety` | `multi-angle-review` (alembic migration diff) |
| Designer | `planner` *(new)* | `brainstorming` terminal step + `/writing-plans` direct invocation |
| Designer | `architect` *(new)* | Implementer BLOCKED with architectural cause + ad-hoc main-session consultation |

## Scope note for the implementation plan

This spec packages three logically separable changes: (a) promoting the three reviewer prompt templates to agent files, (b) adding `planner` and converting brainstorming/writing-plans to dispatch it, and (c) adding `architect` and the implementer escalation hook. They share `agents/README.md` and the consistent dispatch-by-name principle. The implementation plan can sequence them as three phases inside one branch — each phase is independently testable and committable, but they ship together for a coherent end-state.

## Open questions

- **Test runner integration.** Need to confirm `tests/claude-code/run-skill-tests.sh` discovers new test directories by convention; if not, the runner needs explicit additions for each new agent's test set. To verify when the implementation plan is being written.
- **Architect re-dispatch loop.** When `architect` returns a recommendation that an implementer then acts on, do we re-dispatch the implementer with the architect's recommendation as additional `CONTEXT`, or feed it back through the same implementer turn? Current intent is the former (clean re-dispatch with augmented context); confirm during planning.
- **Backwards compatibility for `/writing-plans`.** If a user types `/writing-plans` directly (without going through brainstorming), the skill becomes a planner-dispatch. Verify the user invocation flow still works after the skill is converted to a thin wrapper.
