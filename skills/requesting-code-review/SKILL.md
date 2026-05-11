---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch the `reviewer-code-quality` agent at whole-branch scope to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development (use SCOPE: per-task — see superpowers:subagent-driven-development)
- After completing a major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**

```bash
BASE_SHA=$(git merge-base HEAD origin/main)   # branch base
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch reviewer-code-quality at whole-branch scope:**

```
Task(
  subagent_type=reviewer-code-quality,
  description="Review whole-branch code quality",
  prompt=<per-call context block below>
)
```

**Per-call context block (verify all fields populated before dispatch):**

```
SCOPE: whole-branch
DESCRIPTION: <brief summary of what you built>
PLAN_OR_REQUIREMENTS: <plan file path or requirements>
BASE_SHA: <starting commit>
HEAD_SHA: <ending commit>
```

**3. Act on the verdict:**

- Fix Critical issues immediately
- Fix Important issues before merging
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Follow-up: Multi-Angle Review

If the project has the multi-angle-review skill conventions (typically: a multi-tenant SaaS with FastAPI + Postgres + Alembic), after `reviewer-code-quality` returns APPROVED, run `superpowers:multi-angle-review` as a follow-up. It dispatches role-specific reviewers (multitenant-isolation, migration-safety, security) based on what the diff touches. Critical findings from multi-angle-review block the same way the standard reviewer's Critical findings do.

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification
