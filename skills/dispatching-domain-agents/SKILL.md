---
name: dispatching-domain-agents
description: Use when subagent-driven-development is about to dispatch an implementer subagent to pick a domain-specific implementer agent (fastapi, expo, default) based on the task's primary file paths
---

# Dispatching Domain Agents

Layer on top of subagent-driven-development (SDD). When SDD's orchestrator is about to dispatch an implementer subagent for a task, this skill picks a domain-specific implementer agent based on the task's primary file paths. Domain-aware agents produce stack-correct code (async SQLAlchemy for FastAPI tasks, expo-router for Expo tasks) that the generic upstream prompt would miss.

**Core principle:** Route by file path. One agent per task. Default to fallback.

**Announce at start:** "I'm using the dispatching-domain-agents skill to pick the {fastapi|expo|default} implementer agent."

## When to Use

- Run whenever SDD is about to dispatch an implementer subagent. It's a routing helper that runs once per task — not a replacement for SDD's flow. After dispatch, return to SDD's normal review loop.
- Do NOT use this skill when the project lacks the framework's `apps/api/` and `apps/mobile/` layout (it assumes the convention from `scaffolding-saas-project`).
- Do NOT use this skill for non-implementation tasks (docs, planning, research) — SDD doesn't dispatch implementers for those.

## The Routing Table

| Priority | Predicate | Agent |
|---|---|---|
| 1 | All file paths in the task's "Files:" section match `apps/api/**` (no exceptions) | `implementer-fastapi` |
| 2 | All file paths match `apps/mobile/**` (no exceptions) | `implementer-expo` |
| 3 | Anything else (mixed paths, paths outside `apps/`, no recognizable layer) | `implementer-default` |

Mixed-path tasks fall through to default — the implementer needs cross-layer awareness, which the specialized agents don't provide.

## Process

1. **Read the task's Files section.** Extract all paths under "Create:", "Modify:", "Test:".
2. **Apply the routing predicate in priority order.** First match wins. The chosen agent is one of: `implementer-fastapi`, `implementer-expo`, or `implementer-default`.
3. **Dispatch the Task** with the chosen agent and a structured per-call context block:

   ```
   Task(
     subagent_type=<agent-name>,
     description="Implement <TASK_NUMBER>: <TASK_NAME>",
     prompt=<context block>
   )
   ```

   The context block is five labeled fields:

   ```
   TASK_NUMBER: <e.g. "Task 3">
   TASK_NAME: <short name from the plan>
   TASK_DESCRIPTION: <full task text>
   CONTEXT: <scene-setting: where this fits, dependencies, architectural context>
   WORKING_DIRECTORY: <where the implementer should work from>
   ```

   Verify all five fields are populated before dispatching. The agent's system prompt holds the canonical envelope (Before You Begin, Your Job, Stack-Specific Guidance, Code Organization, Self-Review, Anti-Patterns, Report Format) — no template rendering needed.

4. **Return to SDD's normal flow.** Wait for the implementer report, run spec compliance review, run code quality review.

## Flow

```dot
digraph flow {
    rankdir=TB;
    "Read task Files section" [shape=box];
    "All paths in apps/api/**?" [shape=diamond];
    "All paths in apps/mobile/**?" [shape=diamond];
    "Dispatch implementer-fastapi" [shape=box style=filled fillcolor=lightblue];
    "Dispatch implementer-expo" [shape=box style=filled fillcolor=lightblue];
    "Dispatch implementer-default" [shape=box style=filled fillcolor=lightyellow];
    "Return to SDD review loop" [shape=box style=filled fillcolor=lightgreen];

    "Read task Files section" -> "All paths in apps/api/**?";
    "All paths in apps/api/**?" -> "Dispatch implementer-fastapi" [label="yes"];
    "All paths in apps/api/**?" -> "All paths in apps/mobile/**?" [label="no"];
    "All paths in apps/mobile/**?" -> "Dispatch implementer-expo" [label="yes"];
    "All paths in apps/mobile/**?" -> "Dispatch implementer-default" [label="no"];
    "Dispatch implementer-fastapi" -> "Return to SDD review loop";
    "Dispatch implementer-expo" -> "Return to SDD review loop";
    "Dispatch implementer-default" -> "Return to SDD review loop";
}
```

## Integration with subagent-driven-development

This skill runs at SDD's "Dispatch implementer subagent" step. Instead of using the default `subagent-driven-development/implementer-prompt.md`, the SDD orchestrator consults this skill to pick a domain-aware agent and dispatches by `subagent_type=implementer-<name>`. After dispatch, SDD's review loop (spec compliance → code quality) proceeds unchanged.

## Routing Predicate Validation

| Test task — Files: section paths | Expected agent |
|---|---|
| `apps/api/app/routers/notes.py` only | `implementer-fastapi` |
| `apps/api/app/models/note.py` AND `apps/api/alembic/versions/0001_notes.py` | `implementer-fastapi` |
| `apps/mobile/app/notes/index.tsx` only | `implementer-expo` |
| `apps/mobile/app/notes/index.tsx` AND `apps/mobile/lib/store.ts` | `implementer-expo` |
| `apps/api/app/routers/notes.py` AND `apps/mobile/app/notes/index.tsx` | `implementer-default` (mixed) |
| `scripts/seed.py` only | `implementer-default` (outside apps/) |
| `infra/docker-compose.yml` only | `implementer-default` |
| `apps/api/alembic/versions/0042_add_orgs.py` only | `implementer-fastapi` |
| `apps/api/tests/test_notes.py` AND `apps/api/app/routers/notes.py` | `implementer-fastapi` |
| `README.md` only | `implementer-default` |

Validation walked through manually during initial implementation — all rows produce the expected agent under the routing rule above.

## Adding a New Agent

1. Drop a new `implementer-<name>.md` under `/agents/` (at the plugin root) with the same envelope as existing implementer agents — frontmatter (`name`, `description`, `color: green`), opening role statement, `## Per-Call Context` block, the standard envelope sections (Before You Begin, Your Job, Code Organization, When You're in Over Your Head, Self-Review, Report Format), plus stack-specific guidance and anti-patterns. The `name` in the frontmatter MUST equal the filename minus `.md` — that's the `subagent_type` lookup key.
2. Add a row to the routing table at the appropriate priority. Choose the predicate carefully — overlap with existing predicates breaks the "first match wins" rule. The Agent column holds the bare agent name.
3. Build a planted task fixture and validate via the existing pressure-test loop (RED with default agent + GREEN with new agent). The expected pattern is comparative: same fixture, same model, RED with default vs GREEN with the new agent — GREEN should not regress on RED's checks AND should add observable agent-specific improvements.
4. Commit fixture and agent together.

## Anti-Patterns

**Don't:**
- Dispatch multiple agents for one task (exactly one fires per task).
- Use a specialized agent for a mixed-path task — fall back to default. Cross-layer awareness matters.
- Skip the announce step — the user/orchestrator needs to know which agent was chosen.
- Fork upstream's `subagent-driven-development/implementer-prompt.md` content into specialized agents without keeping `implementer-default` in sync. When upstream improves the prompt, propagate to default first, then re-merge into specialized variants.
- Add a new agent without a planted fixture and pressure-test — untested agents are worse than no agent (they give false confidence).

## Future Agents

Future agents not in initial scope, added per real-world need: `implementer-nextjs` (when web admin work begins), `implementer-infra` (Docker/Terraform/CI), `implementer-database` (migration-heavy or schema-design tasks). Each requires a planted task fixture and pressure test before merging.
