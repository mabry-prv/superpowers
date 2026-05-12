# Agents

Plugin-shipped agents dispatched via `Task(subagent_type=<agent-name>, prompt=<per-call context block>)`. The subagent's system prompt holds the canonical role-specific knowledge; consuming skills are thin dispatchers that build the per-call context block.

## Agent families

| Family | Naming | Color | Role |
|---|---|---|---|
| Implementer | `implementer-<stack>` | warm (pink, orange, yellow) | Writes code + tests for one task |
| Reviewer | `reviewer-<concern>` | red | Reads code, returns verdict + findings |
| Designer | `planner` / `architect` | cool (green, blue) | Produces plans or design recommendations |
| Librarian | `curator` (others future) | teal / cyan | Distills project patterns + gotchas into `knowledge/` from completed branches |

## Frontmatter contract

Every agent file has frontmatter with: `name`, `description`, `color`, `model`, `effort`.

The `name` MUST equal the filename minus `.md` — that's the `subagent_type` lookup key. A mismatch means the agent is undiscoverable.

`color` follows the family convention above. `model` is `opus` for all current agents. `effort` is one of: `xhigh` (mechanical or rules-driven work) or `max` (high-judgment generative work).

## System prompt envelope

Every agent follows the same nine-section structure:

1. Frontmatter
2. Role statement (single paragraph)
3. Per-Call Context (labeled fields the dispatcher must populate)
4. Before You Begin
5. Your Job
6. Role-specific guidance (the meaty middle — varies by agent)
7. When You're in Over Your Head (escalation)
8. Self-review (where applicable — implementers and planner have it; reviewers and architect generally don't)
9. Anti-Patterns + Report Format

Most reviewers add a `Severity Rules` subsection (Critical / Important / Suggestion) and a `Report Format` block with a verdict line at the end. `reviewer-spec` uses task-shaped categories (Missing / Extra / Misunderstood); `reviewer-code-quality` uses Critical / Important / Minor with a `Ready to merge?` verdict — both deviations are intentional and reflect the per-task review shape.

## Per-call context contract

Every dispatcher MUST populate every field in the agent's per-call context block before calling. A missing field would cause the agent to hallucinate output on empty context. Verify before dispatch.

## Per-call context fields by agent

| Agent | Per-call fields |
|---|---|
| `implementer-default` / `implementer-fastapi` / `implementer-expo` | TASK_NUMBER, TASK_NAME, TASK_DESCRIPTION, CONTEXT, WORKING_DIRECTORY |
| `reviewer-spec` | TASK_NUMBER, TASK_NAME, TASK_REQUIREMENTS, IMPLEMENTER_REPORT, FILES_TO_REVIEW |
| `reviewer-code-quality` | SCOPE, DESCRIPTION, PLAN_OR_REQUIREMENTS, BASE_SHA, HEAD_SHA |
| `reviewer-security` / `reviewer-multitenant-isolation` / `reviewer-migration-safety` | DESCRIPTION, PLAN_OR_REQUIREMENTS, FILES_TO_REVIEW |
| `planner` | SPEC_PATH, WORKING_DIRECTORY, PROJECT_CONTEXT, CONSTRAINTS |
| `architect` | QUESTION, CODE_CONTEXT, CONSTRAINTS, PRIOR_ATTEMPTS, DECISION_OWNER |
| `curator` | WORKING_DIRECTORY, TASK_DESCRIPTION, PLAN_OR_SPEC, BASE_SHA, HEAD_SHA, IMPLEMENTER_REPORT, REVIEWER_REPORTS, EXISTING_INDEX |

## Adding a new agent

1. **Write the agent body**, following an existing agent in the same family as a template.
2. **If routing logic is needed** (multiple variants), add a row to the relevant dispatching skill (`dispatching-domain-agents` for implementers, `multi-angle-review` for reviewers). Single-variant designers (`planner`, `architect`) don't need a routing skill.
3. **Add a fixture-based test** under `tests/<agent-name>/`. Pure-grep `test-structure.sh` is required; integration test is encouraged but optional.
4. **Wire the structural test** into `tests/claude-code/run-skill-tests.sh` — append the path to the `tests=(...)` array.
5. **Pressure-test RED → GREEN** if the agent has any nontrivial role-specific guidance.
6. **Commit fixture + agent + skill change + README row update + runner update** together.

## Dispatch model

The dispatch model is uniform across families:

```
Task(
  subagent_type=<bare agent name, e.g. "reviewer-spec">,
  description=<one-line description for tooling>,
  prompt=<the structured per-call context block as plain text>
)
```

`subagent_type=general-purpose` is reserved for ad-hoc Explore-style searches that don't fit a role. Role-bearing calls always use a named agent.

## Files in this directory

| File | Purpose |
|---|---|
| `implementer-default.md` | Mixed-path / fallback implementer |
| `implementer-fastapi.md` | `apps/api/**` implementer (FastAPI / SQLAlchemy 2.0 / Alembic / Pydantic v2) |
| `implementer-expo.md` | `apps/mobile/**` implementer (Expo / expo-router / Hermes / MobileMCP) |
| `reviewer-spec.md` | Per-task spec compliance |
| `reviewer-code-quality.md` | Per-task and whole-branch code quality |
| `reviewer-security.md` | Security defects (FastAPI + SQLAlchemy) |
| `reviewer-multitenant-isolation.md` | Tenant boundary correctness |
| `reviewer-migration-safety.md` | Production-safe Alembic migrations |
| `planner.md` | Spec → plan |
| `architect.md` | Design consultation |
| `curator.md` | Distills patterns + gotchas from completed branches into `knowledge/` |
