---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

This skill dispatches the `planner` agent to transform a design spec into an implementation plan with bite-sized, TDD-shaped tasks. The agent's system prompt holds the canonical planning rules (file structure, task granularity, no-placeholders, self-review). This skill is a thin dispatcher.

**Announce at start:** "I'm using the writing-plans skill to dispatch the planner agent."

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (the agent does this — user preferences for plan location override this default and should be passed in `PROJECT_CONTEXT`).

## When to Use

- After `superpowers:brainstorming` produces an approved spec.
- When a user types `/writing-plans` directly with a spec already in hand.

Do NOT use this skill if no spec exists. Brainstorm first.

## How to Dispatch

Build the per-call context block with all four fields populated:

```
SPEC_PATH: <path to the approved design spec>
WORKING_DIRECTORY: <where the planner should work from>
PROJECT_CONTEXT: <relevant existing structure — apps/api layout, tech stack, conventions, existing plans dir if non-default>
CONSTRAINTS: <hard constraints from brainstorm — must not break X, must ship by Y, etc.>
```

Verify all fields are populated before dispatch — a missing field would cause the planner to plan against empty context.

Then dispatch:

```
Task(
  subagent_type=planner,
  description="Write implementation plan for <feature>",
  prompt=<the per-call context block>
)
```

## After the Plan Is Written

The planner reports back with:

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Plan path
- Task count, decomposition summary
- Open questions (if any)

Handle each status:

- **DONE**: proceed to execution handoff (below)
- **DONE_WITH_CONCERNS**: read the concerns, decide whether to address before execution
- **BLOCKED**: spec is too underspecified — return to brainstorming
- **NEEDS_CONTEXT**: provide the missing context field and re-dispatch

## Execution Handoff

After the plan is committed, offer the user execution choice:

> "Plan complete and saved to `<plan-path>`. Two execution options:
>
> **1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
>
> **2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.
>
> Which approach?"

If Subagent-Driven chosen: REQUIRED SUB-SKILL: superpowers:subagent-driven-development.
If Inline Execution chosen: REQUIRED SUB-SKILL: superpowers:executing-plans.
