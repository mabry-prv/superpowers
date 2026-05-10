# Dispatching Domain Agents Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `dispatching-domain-agents` skill that picks a domain-specific implementer prompt template (fastapi, expo, or default) based on the task's primary file paths, integrating with the existing `subagent-driven-development` flow. Each domain template is RED/GREEN-validated against a planted task fixture before commit.

**Architecture:** New skill at `skills/dispatching-domain-agents/` containing `SKILL.md` (routing logic: read task Files section, match priority predicates, return chosen template) and three implementer templates under `templates/`: `implementer-fastapi.md`, `implementer-expo.md`, `implementer-default.md`. The skill is a routing helper — it does NOT dispatch the Task itself; it tells the SDD orchestrator which template to render and use. The default template mirrors the upstream `subagent-driven-development/implementer-prompt.md`. Domain templates extend the default envelope with stack-specific guidance (async SQLAlchemy + Alembic + multi-tenant session factory for FastAPI; expo-router + Hermes + MobileMCP for Expo).

**Tech Stack:** Markdown for skill content. Bash for routing-rule sketches in SKILL.md. Python (FastAPI + SQLAlchemy 2.0) and TypeScript (Expo + expo-router) for planted task fixtures. The `Task` tool with `subagent_type: general-purpose` for pressure-test dispatch.

**Fixtures location:** Planted task fixtures live OUTSIDE the repo at `/tmp/saas-fixtures/dda-*`. They're inputs to pressure tests, not artifacts to ship.

**Phase 1.5 deferred:** Templates ship as files in `templates/`, dispatched inline by the SDD orchestrator. A later refactor (post-validation, before first real product use) moves them to `agents/implementer-{fastapi,expo,default}.md` so the skill becomes a router that dispatches `Task(subagent_type=implementer-fastapi, ...)` directly. Same content, cleaner delivery. Out of scope for this plan.

---

### Task 1: Scaffold the skill directory

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/SKILL.md`
- Create: `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/.gitkeep`

- [ ] **Step 1: Create the directory tree**

```bash
mkdir -p /Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates
```

- [ ] **Step 2: Write a placeholder SKILL.md (frontmatter + heading only)**

Write to `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/SKILL.md`:

```markdown
---
name: dispatching-domain-agents
description: Use when subagent-driven-development is about to dispatch an implementer subagent to pick a domain-specific implementer prompt template (fastapi, expo, default) based on the task's primary file paths
---

# Dispatching Domain Agents

(Body populated in Task 9.)
```

- [ ] **Step 3: .gitkeep so empty templates dir is tracked**

```bash
touch /Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/.gitkeep
```

- [ ] **Step 4: Verify the skill is discoverable**

```bash
cd /Users/marcin/Projects/superpowers && head -5 skills/dispatching-domain-agents/SKILL.md
```

Expected output: the frontmatter block with `name: dispatching-domain-agents`.

- [ ] **Step 5: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/dispatching-domain-agents/ && git commit -m "feat: scaffold dispatching-domain-agents skill directory"
```

---

### Task 2: Write `implementer-default.md` (mirrors upstream)

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-default.md`
- Read for reference: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/implementer-prompt.md`

Default fallback template. Used when the task touches mixed paths or paths outside the recognized layer structure (`apps/api/**`, `apps/mobile/**`). Mirrors the upstream implementer-prompt.md as the canonical baseline.

- [ ] **Step 1: Read the upstream template to understand the structure**

```bash
cat /Users/marcin/Projects/superpowers/skills/subagent-driven-development/implementer-prompt.md
```

Note: ~113 lines. Sections to mirror: Task tool block, Task Description, Context, Before You Begin, Your Job, Code Organization, When You're in Over Your Head, Self-Review, Report Format.

- [ ] **Step 2: Write the default template**

Write to `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-default.md`. The content must:

1. Open with a header section explaining this is the fallback template:

```markdown
# Implementer Template: Default (Fallback)

Use this template when no domain-specific implementer template applies — i.e., the task touches mixed paths or paths outside the recognized layer structure.

**Mirrors:** `skills/subagent-driven-development/implementer-prompt.md` (the upstream canonical implementer prompt). When upstream improves that prompt, propagate the improvement here first, then re-merge into the specialized variants (`implementer-fastapi.md`, `implementer-expo.md`).
```

2. Follow with the Task tool block — copy the structure from upstream verbatim, but use these placeholders so the SDD orchestrator can render:
   - `{TASK_NUMBER}` (e.g., "Task 3")
   - `{TASK_NAME}` (e.g., "Add Notes router")
   - `{TASK_DESCRIPTION}` (full task text from plan)
   - `{CONTEXT}` (scene-setting from SDD orchestrator)
   - `{WORKING_DIRECTORY}` (where the implementer should work from)

3. Reproduce the upstream sections exactly: Task Description, Context, Before You Begin, Your Job (with the 6-step list), Code Organization, When You're in Over Your Head, Before Reporting Back: Self-Review, Report Format.

4. Close with a Placeholders section listing what each substitution slot expects:

```markdown
**Placeholders:**
- `{TASK_NUMBER}` — task number from the plan (e.g., "Task 3")
- `{TASK_NAME}` — short task name from the plan
- `{TASK_DESCRIPTION}` — full text of the task as it appears in the plan
- `{CONTEXT}` — scene-setting (where this fits, dependencies, architectural context)
- `{WORKING_DIRECTORY}` — directory the implementer should work from
```

- [ ] **Step 3: Verify line count and section structure**

```bash
wc -l /Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-default.md
grep -n '^##' /Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-default.md
```

Expected: ~120-150 lines. Section list matches upstream's section list.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/dispatching-domain-agents/templates/implementer-default.md && git commit -m "feat(dispatching-domain-agents): add implementer-default template"
```

---

### Task 3: Build the FastAPI planted task fixture

**Files:**
- Create: `/tmp/saas-fixtures/dda-fastapi-task/README.md`
- Create: `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/__init__.py`
- Create: `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/db.py`
- Create: `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/main.py`
- Create: `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/models/__init__.py`
- Create: `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/alembic/env.py`
- Create: `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/alembic/versions/.gitkeep`

Minimal FastAPI scaffold with the canonical patterns already in place. The task description is: "Add an org-scoped Notes resource."

- [ ] **Step 1: Create directories**

```bash
mkdir -p /tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/models
mkdir -p /tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/alembic/versions
touch /tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/__init__.py
touch /tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/models/__init__.py
touch /tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/alembic/versions/.gitkeep
```

- [ ] **Step 2: Write `scaffold/apps/api/app/db.py` (canonical session factory)**

Write to `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/db.py`:

```python
"""Database session factory.

The org-scoped session factory is the canonical pattern for tenant isolation.
Every endpoint that touches org-scoped data must use `get_org_db` (NOT `get_db`)
to inherit automatic org_id filtering. The current org_id comes from the
verified session (request.state.org_id), never from request input.
"""
from contextlib import asynccontextmanager
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import with_loader_criteria
from .config import settings

engine = create_async_engine(settings.DATABASE_URL, echo=False)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def get_db() -> AsyncSession:
    """Raw session — use only for endpoints that don't touch org-scoped data."""
    async with SessionLocal() as session:
        yield session


async def get_org_db(request) -> AsyncSession:
    """Org-scoped session — auto-filters every query against org-scoped models
    using request.state.org_id from auth middleware."""
    org_id = request.state.org_id
    async with SessionLocal() as session:
        # Apply with_loader_criteria for every org-scoped model registered.
        # The actual implementation registers each model on import.
        yield session
```

- [ ] **Step 3: Write `scaffold/apps/api/app/main.py`**

Write to `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/app/main.py`:

```python
from fastapi import FastAPI

app = FastAPI(title="dda-fastapi-fixture")


@app.get("/health")
async def health():
    return {"ok": True}
```

- [ ] **Step 4: Write `scaffold/apps/api/alembic/env.py`**

Write to `/tmp/saas-fixtures/dda-fastapi-task/scaffold/apps/api/alembic/env.py`:

```python
"""Alembic env (truncated for fixture)."""
from alembic import context
from sqlalchemy import engine_from_config, pool
from app.db import engine
from app.models import Base

target_metadata = Base.metadata


def run_migrations_online() -> None:
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


run_migrations_online()
```

- [ ] **Step 5: Write the task description README**

Write to `/tmp/saas-fixtures/dda-fastapi-task/README.md`:

````markdown
# DDA FastAPI Task Fixture

This fixture is used to pressure-test domain-specific implementer templates.
The scaffold contains the canonical session-factory pattern in `scaffold/apps/api/app/db.py`.

## The Task (paste this as the implementer's task)

**Task 4: Add org-scoped Notes resource**

**Files:**
- Create: `apps/api/app/models/note.py`
- Create: `apps/api/app/routers/notes.py`
- Create: `apps/api/alembic/versions/0001_add_notes.py`
- Modify: `apps/api/app/main.py` (mount the router)

**Step 1: Define the Note model**

Org-scoped: every note belongs to an org via `org_id`. Fields: `id`, `org_id`,
`title` (required, str), `body` (optional, str), `created_at`, `updated_at`.

**Step 2: Define the router**

Endpoints:
- `POST /notes` — create a note (org-scoped to current user's org)
- `GET /notes` — list notes for current org
- `GET /notes/{note_id}` — get a single note (404 if cross-org access attempted)
- `PATCH /notes/{note_id}` — update a note (404 if cross-org)
- `DELETE /notes/{note_id}` — delete a note (404 if cross-org)

Use the org-scoped session factory (`get_org_db` from `app/db.py`). Source
`org_id` from the verified session, never from request input.

**Step 3: Add the Alembic migration**

Reversible. `notes` table with foreign key to `orgs.id` (assume orgs table exists).
Index on `(org_id, id)` for org-scoped lookups.

**Step 4: Mount the router in main.py**

**Step 5: Commit each piece**
````

- [ ] **Step 6: No commit (fixtures live outside repo)**

---

### Task 4: RED baseline — dispatch `implementer-default` against FastAPI task

Establish what the default template produces when given a stack-specific task. The gap between this baseline and what `implementer-fastapi` produces in Task 5 proves the specialized template is doing real work.

**Files:** none (research)

- [ ] **Step 1: Read the default template**

```bash
cat /Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-default.md
```

- [ ] **Step 2: Render the default template against the FastAPI task**

Render `implementer-default.md` substituting placeholders:
- `{TASK_NUMBER}` → "Task 4"
- `{TASK_NAME}` → "Add org-scoped Notes resource"
- `{TASK_DESCRIPTION}` → contents of `/tmp/saas-fixtures/dda-fastapi-task/README.md` "## The Task" section
- `{CONTEXT}` → "This is a multi-tenant B2B SaaS API. The scaffold contains an org-scoped session factory pattern at apps/api/app/db.py. All org-scoped data flows through it. There is no UI for this — backend only."
- `{WORKING_DIRECTORY}` → `/tmp/saas-fixtures/dda-fastapi-task/scaffold`

- [ ] **Step 3: Dispatch a Task with the rendered prompt**

```
Task tool:
  description: "RED baseline: implementer-default on FastAPI Notes task"
  subagent_type: general-purpose
  prompt: <rendered implementer-default.md contents>
```

- [ ] **Step 4: Capture findings (scratch notes — no file commit)**

Record what the implementer actually produced:
- Did it use `AsyncSession` / `async def` / `await`? (Or sync `Session.query()`?)
- Did it source `org_id` from the verified session (e.g., `request.state.org_id` or `current_user.org_id`)? (Or from request body / path / header?)
- Did it use `get_org_db` (the org-scoped factory) for org-scoped queries? (Or raw `get_db`?)
- Did it write a Note model with `org_id` column?
- Did it filter the GET list endpoint by org? Did it 404 on cross-org PK access?
- Did it write a reversible Alembic migration with `downgrade()` populated?
- Did it use Pydantic v2 `BaseModel` for request/response schemas?
- Did it set `response_model=` on each endpoint for OpenAPI completeness?

Any "no" answer is a domain-specific gap the specialized template should close.

- [ ] **Step 5: No commit (research)**

---

### Task 5: Write `implementer-fastapi.md` and pressure-test (GREEN)

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-fastapi.md`

- [ ] **Step 1: Draft the template body**

The template MUST contain these sections (write them in order):

1. **Heading + role**: `# Implementer Template: FastAPI` + "Use when the task touches `apps/api/**` only. Extends the default implementer envelope with FastAPI / SQLAlchemy 2.0 / Alembic / Pydantic v2 / multi-tenant SaaS guidance."

2. **Same Task tool envelope** as `implementer-default.md` (so the SDD orchestrator's rendering logic is identical) — Task Description, Context, Before You Begin, Your Job, Code Organization, When You're in Over Your Head, Self-Review, Report Format. Use the same placeholders (`{TASK_NUMBER}`, `{TASK_NAME}`, `{TASK_DESCRIPTION}`, `{CONTEXT}`, `{WORKING_DIRECTORY}`).

3. **A "Stack-Specific Guidance" section inside the prompt body**, inserted between the existing "Your Job" and "Code Organization" sections. This section is what differentiates this template from default. It must include:

   - **SQLAlchemy 2.0 async patterns**:
     - All sessions are `AsyncSession`. All DB calls are `await`-ed.
     - Use `select(Model).where(...)` — NOT the legacy `Query` API.
     - `db.execute(select(...))` then `.scalars().all()` / `.scalar_one_or_none()`.
     - For PK fetch: `await db.get(Model, id)` — but always check `row.org_id == current_org_id` after fetch (404 if mismatch).

   - **Multi-tenant session factory rule** (canonical pattern):
     - Every query against an org-scoped model uses `get_org_db` (not `get_db`).
     - `org_id` comes from the verified session — `request.state.org_id` or `user.org_id`. NEVER from request body, query params, headers, or path parameters.
     - On PK fetch (`db.get`), the auto-filter does NOT apply — explicit `if row.org_id != user.org_id: raise HTTPException(404)` is required.
     - Cross-org access returns 404, never 403 (don't leak existence).

   - **Pydantic v2 schemas**:
     - Request/response schemas in `app/schemas/<resource>.py` using `BaseModel`.
     - Use `Field(...)` for required fields with constraints; `Field(default=...)` for defaults.
     - Each endpoint sets `response_model=` for OpenAPI completeness — the mobile client codegen depends on it.

   - **FastAPI dependency injection**:
     - Inject `db: AsyncSession = Depends(get_org_db)` for org-scoped endpoints.
     - Inject `user = Depends(get_current_user)` for endpoints that need current user identity.

   - **Alembic migration etiquette** (the migration-safety reviewer enforces these):
     - Every migration has a populated `downgrade()`. No empty downgrades unless the migration is genuinely irreversible AND a comment explains why.
     - Destructive changes split across migrations: add new (nullable, with backfill) → switch code → drop old (next migration).
     - Adding NOT NULL on an existing column: add nullable + backfill (one migration) → switch code (deploy) → make NOT NULL (next migration).
     - Index creation on large tables: `CREATE INDEX CONCURRENTLY` (Postgres). Wrap in a transaction-less migration.

   - **OpenAPI completeness**:
     - Every endpoint has request/response schemas (Pydantic models).
     - `response_model=` is set on every route decorator.
     - Use tags grouping related endpoints (`tags=["notes"]`).

4. **A "FastAPI Anti-Patterns" section after Self-Review**:

   - DON'T use sync `Session.query()` — this is a SQLAlchemy 1.x pattern; we're on 2.0 async.
   - DON'T accept `org_id` in request body, path, or query params.
   - DON'T fetch by PK without an org-id post-check.
   - DON'T write a migration without a working `downgrade()`.
   - DON'T combine destructive changes (drop column / rename / add NOT NULL) with code that depends on the new shape in the same release.
   - DON'T skip `response_model=` — the mobile client codegen breaks on incomplete OpenAPI.
   - DON'T use raw SQL string concat for any query — use SQLAlchemy expressions or parameterized `text(...)`.
   - DON'T introduce a Postgres-specific feature without flagging it (the framework targets Postgres but be explicit when relying on it).

5. **Placeholders** section (same as default — list each substitution slot).

Aim for ~180-240 lines. Mirror the prose style of `templates/implementer-default.md`.

- [ ] **Step 2: Pressure-test against the FastAPI fixture**

Render `implementer-fastapi.md` against the same FastAPI fixture used in Task 4 (Notes resource task in `/tmp/saas-fixtures/dda-fastapi-task/`).

Dispatch:

```
Task tool:
  description: "GREEN: implementer-fastapi on FastAPI Notes task"
  subagent_type: general-purpose
  prompt: <rendered implementer-fastapi.md contents>
```

- [ ] **Step 3: Verify GREEN against the same checklist used in Task 4**

Expected (every item YES):
- Used `AsyncSession`, `async def`, `await`
- Sourced `org_id` from `request.state.org_id` or `user.org_id` (NOT from request input)
- Used `get_org_db` for org-scoped queries (or explicit `.where(Model.org_id == user.org_id)`)
- Note model includes `org_id` column with index
- GET list endpoint filters by org_id
- GET-by-PK endpoint raises 404 (not 403) on cross-org access
- Alembic migration has populated `downgrade()`
- Used Pydantic v2 schemas
- Set `response_model=` on each endpoint

If any miss: revise the template (likely needs stronger directive language for the missing item, or moving the rule earlier in the prompt). Re-run. Iterate to GREEN.

- [ ] **Step 4: Commit (with a brief notes file in the plan dir if findings are non-obvious)**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/dispatching-domain-agents/templates/implementer-fastapi.md && git commit -m "feat(dispatching-domain-agents): add implementer-fastapi template"
```

---

### Task 6: Build the Expo planted task fixture

**Files:**
- Create: `/tmp/saas-fixtures/dda-expo-task/README.md`
- Create: `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/package.json`
- Create: `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app.json`
- Create: `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app/_layout.tsx`
- Create: `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app/index.tsx`
- Create: `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/lib/api.ts`
- Create: `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/tsconfig.json`

Minimal Expo scaffold using expo-router. Task description: "Add a Notes screen that lists notes from the API."

- [ ] **Step 1: Create directories**

```bash
mkdir -p /tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app
mkdir -p /tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/lib
```

- [ ] **Step 2: Write `package.json`**

Write to `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/package.json`:

```json
{
  "name": "dda-expo-fixture",
  "version": "0.0.0",
  "main": "expo-router/entry",
  "scripts": {
    "start": "expo start"
  },
  "dependencies": {
    "expo": "~54.0.0",
    "expo-router": "~5.0.0",
    "react": "19.0.0",
    "react-native": "0.78.0",
    "@hey-api/openapi-ts": "^0.65.0"
  },
  "devDependencies": {
    "typescript": "~5.6.0",
    "@types/react": "~19.0.0"
  }
}
```

- [ ] **Step 3: Write `app.json`**

Write to `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app.json`:

```json
{
  "expo": {
    "name": "dda-expo-fixture",
    "slug": "dda-expo-fixture",
    "scheme": "ddaexpo",
    "newArchEnabled": true,
    "plugins": ["expo-router"]
  }
}
```

- [ ] **Step 4: Write `tsconfig.json`**

Write to `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/tsconfig.json`:

```json
{
  "extends": "expo/tsconfig.base",
  "compilerOptions": {
    "strict": true,
    "paths": { "@/*": ["./*"] }
  },
  "include": ["**/*.ts", "**/*.tsx"]
}
```

- [ ] **Step 5: Write `app/_layout.tsx` (root layout via expo-router)**

Write to `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app/_layout.tsx`:

```tsx
import { Stack } from "expo-router";

export default function RootLayout() {
  return <Stack />;
}
```

- [ ] **Step 6: Write `app/index.tsx` (placeholder home)**

Write to `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/app/index.tsx`:

```tsx
import { Text, View } from "react-native";
import { Link } from "expo-router";

export default function Home() {
  return (
    <View>
      <Text>dda-expo-fixture</Text>
      <Link href="/notes">Open notes</Link>
    </View>
  );
}
```

- [ ] **Step 7: Write `lib/api.ts` (existing API client to reuse)**

Write to `/tmp/saas-fixtures/dda-expo-task/scaffold/apps/mobile/lib/api.ts`:

```ts
// Generated client (placeholder — represents what @hey-api/openapi-ts produces).
// New screens MUST consume this client; do not write a parallel fetch layer.

const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? "http://localhost:8000";

export type Note = {
  id: number;
  org_id: number;
  title: string;
  body: string | null;
  created_at: string;
  updated_at: string;
};

export const api = {
  notes: {
    list: async (): Promise<Note[]> => {
      const res = await fetch(`${BASE_URL}/notes`, {
        headers: { authorization: `Bearer ${await getToken()}` },
      });
      if (!res.ok) throw new Error(`list notes: ${res.status}`);
      return res.json();
    },
  },
};

async function getToken(): Promise<string> {
  return "dev-token";
}
```

- [ ] **Step 8: Write the task description README**

Write to `/tmp/saas-fixtures/dda-expo-task/README.md`:

````markdown
# DDA Expo Task Fixture

This fixture is used to pressure-test the Expo implementer template.
The scaffold uses expo-router (not React Navigation) and has an existing
generated API client at `lib/api.ts` that new screens must consume.

## The Task (paste this as the implementer's task)

**Task 4: Add Notes screen**

**Files:**
- Create: `apps/mobile/app/notes/index.tsx`

**Step 1: Build a list screen at `/notes`**

Show all notes for the current org. Use the existing API client at `lib/api.ts`
(`api.notes.list()`). Render each note's `title` and `body`. Show a loading
state while fetching and an error state if the request fails.

**Step 2: Use expo-router**

The screen lives at `app/notes/index.tsx` so it routes to `/notes`. Use Link
from expo-router for any navigation. Do NOT install or import React Navigation.

**Step 3: TypeScript-first**

Use the `Note` type exported from `lib/api.ts`. Add no untyped state.

**Step 4: Commit**
````

- [ ] **Step 9: No commit (fixtures outside repo)**

---

### Task 7: RED baseline — dispatch `implementer-default` against Expo task

Establish what the default template produces for an Expo task. The gap proves the specialized template is doing work.

**Files:** none (research)

- [ ] **Step 1: Render `implementer-default.md` against the Expo task**

Substitute placeholders:
- `{TASK_NUMBER}` → "Task 4"
- `{TASK_NAME}` → "Add Notes screen"
- `{TASK_DESCRIPTION}` → contents of `/tmp/saas-fixtures/dda-expo-task/README.md` "## The Task" section
- `{CONTEXT}` → "This is the mobile app for a multi-tenant B2B SaaS. The app uses expo-router (file-based routing), Hermes runtime, and consumes an API client generated by @hey-api/openapi-ts at lib/api.ts. There is no React Navigation in this project."
- `{WORKING_DIRECTORY}` → `/tmp/saas-fixtures/dda-expo-task/scaffold`

- [ ] **Step 2: Dispatch the Task**

```
Task tool:
  description: "RED baseline: implementer-default on Expo Notes screen"
  subagent_type: general-purpose
  prompt: <rendered implementer-default.md contents>
```

- [ ] **Step 3: Capture findings (scratch notes)**

Record what the implementer produced:
- Did it use expo-router (`Link` from `expo-router`, file-based route)? Or reach for React Navigation (`@react-navigation/native`, `createStackNavigator`)?
- Did it consume the existing `lib/api.ts` client? Or write a parallel `fetch()` directly?
- Did it use the `Note` type from `lib/api.ts`? Or define a local untyped/duplicate?
- Did it handle loading + error states explicitly?
- Did it install any new packages without flagging the native-rebuild requirement?
- Did it use any iOS-only or Android-only API without explicit platform branching?

Any "yes" to a wrong-pattern question (or "no" to a right-pattern question) is a gap the specialized template should close.

- [ ] **Step 4: No commit (research)**

---

### Task 8: Write `implementer-expo.md` and pressure-test (GREEN)

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/templates/implementer-expo.md`

- [ ] **Step 1: Draft the template body**

Required sections:

1. **Heading + role**: `# Implementer Template: Expo` + "Use when the task touches `apps/mobile/**` only. Extends the default implementer envelope with Expo / expo-router / TypeScript / Hermes / MobileMCP guidance."

2. **Same Task tool envelope** as `implementer-default.md` — Task Description, Context, Before You Begin, Your Job, Code Organization, When You're in Over Your Head, Self-Review, Report Format. Same placeholders (`{TASK_NUMBER}`, `{TASK_NAME}`, `{TASK_DESCRIPTION}`, `{CONTEXT}`, `{WORKING_DIRECTORY}`).

3. **A "Stack-Specific Guidance" section** between "Your Job" and "Code Organization":

   - **expo-router (file-based routing)**:
     - Routes are files under `app/`. `app/notes/index.tsx` → `/notes`. Dynamic routes use `[param]` (e.g., `app/notes/[id].tsx` → `/notes/:id`).
     - Navigation uses `Link` and `router` from `expo-router`. NEVER use React Navigation (`@react-navigation/*`). The framework standardizes on expo-router; mixing creates inconsistent navigation behavior and bundle bloat.
     - Layouts wrap a directory of routes via `_layout.tsx` files.

   - **TypeScript-first**:
     - Always import generated types from the API client (e.g., `import type { Note } from "@/lib/api"`). Don't define parallel local types for API responses.
     - `tsconfig` has `strict: true`. No `any`. Use generic `Result<T, E>` patterns or discriminated unions for error handling.
     - State management: prefer React state hooks for screen-local state, Zustand for shared/global state. Avoid Redux unless explicitly justified.

   - **API client consumption**:
     - The project has an existing API client at `lib/api.ts` generated by `@hey-api/openapi-ts`. ALWAYS consume it. Don't write a parallel `fetch()` layer.
     - When the API contract changes (FastAPI side), regenerate the client via `scripts/codegen-api-client.sh`. New API endpoints don't appear in the mobile app until codegen runs.

   - **Native module / native rebuild constraints**:
     - Adding any package that includes native code (anything depending on `react-native` natively) requires a new native build. Flag this in the implementer's report — don't silently add it.
     - Pure JS packages are OTA-safe and can ship via Expo Updates without a new build.
     - When in doubt, check the package's README for "requires native build" language or consult `npx expo install` (which warns).

   - **iOS / Android divergence**:
     - Use `Platform.OS` for genuinely platform-specific behavior; document why.
     - Test both iOS and Android — never assume parity. Common divergence: status bar height, keyboard avoidance, file system paths, push notification flow.

   - **Hermes vs JSC**:
     - The default runtime is Hermes (`newArchEnabled: true` in `app.json`). Some libraries are Hermes-incompatible (rare; check the library's docs).
     - Don't introduce dynamic `eval()` or `Function()` constructor — Hermes runs ahead-of-time bytecode and these patterns trigger interpreter fallback or fail.

   - **MobileMCP for verification**:
     - When a feature is implementable end-to-end (i.e., the API endpoint already exists), use the MobileMCP server to drive the simulator and verify the screen actually loads, fetches data, and renders correctly. Don't ask the user to "test it on your phone" if MobileMCP can do it.
     - For UI-only changes (e.g., layout tweaks), MobileMCP screenshot comparison is the verification.

4. **An "Expo Anti-Patterns" section after Self-Review**:

   - DON'T install or import `@react-navigation/*` — the project uses expo-router exclusively.
   - DON'T write a parallel `fetch()` layer — consume `lib/api.ts`.
   - DON'T define local types that duplicate API client types — import them.
   - DON'T add a package with native code without flagging it as a "requires native rebuild" change.
   - DON'T introduce iOS-only or Android-only code paths without `Platform.OS` branching AND a comment explaining why.
   - DON'T skip MobileMCP verification when the feature is end-to-end testable.
   - DON'T use class components — function components only.
   - DON'T introduce Redux / MobX / Recoil unless explicitly justified — Zustand or hooks are the project default.

5. **Placeholders** section (same as default).

Aim for ~200-260 lines. Mirror the prose style of `implementer-fastapi.md`.

- [ ] **Step 2: Pressure-test against the Expo fixture**

Render `implementer-expo.md` against the same Expo fixture from Task 7. Dispatch:

```
Task tool:
  description: "GREEN: implementer-expo on Expo Notes screen"
  subagent_type: general-purpose
  prompt: <rendered implementer-expo.md contents>
```

- [ ] **Step 3: Verify GREEN against the Task 7 checklist**

Expected (every item YES, every wrong-pattern absent):
- Used `Link` / `router` from `expo-router` (NOT React Navigation)
- Consumed `lib/api.ts` (`api.notes.list()`) — no parallel fetch
- Imported `Note` type from `lib/api.ts`
- Handled loading and error states explicitly
- Did NOT install any new packages (or flagged them with a "requires native rebuild" note if it did)
- Used function components, no class components
- No Redux / MobX
- If MobileMCP is mentioned in context, planned to use it for verification (or noted "would use MobileMCP if available")

If any miss: revise the template. Iterate to GREEN.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/dispatching-domain-agents/templates/implementer-expo.md && git commit -m "feat(dispatching-domain-agents): add implementer-expo template"
```

---

### Task 9: Write `dispatching-domain-agents/SKILL.md` (orchestrator + routing predicate validation)

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/dispatching-domain-agents/SKILL.md`

- [ ] **Step 1: Draft the SKILL.md body**

Required sections:

1. **Frontmatter** (already there from Task 1) — keep as-is.

2. **Overview** (~3 sentences):

   ```markdown
   Layer on top of subagent-driven-development (SDD). When SDD's orchestrator is about to dispatch an implementer subagent for a task, this skill picks a domain-specific implementer prompt template based on the task's primary file paths. Domain-aware prompts produce stack-correct code (async SQLAlchemy for FastAPI tasks, expo-router for Expo tasks) that the generic upstream prompt would miss.
   ```

3. **Core principle**: `Route by file path. One template per task. Default to fallback.`

4. **Announce at start**: `"I'm using the dispatching-domain-agents skill to pick the {fastapi|expo|default} implementer template."`

5. **When to Use**:

   - Run whenever SDD is about to dispatch an implementer subagent.
   - It's a routing helper that runs once per task — not a replacement for SDD's flow. After dispatch, return to SDD's normal review loop.
   - Do NOT use this skill when the project lacks the framework's `apps/api/` and `apps/mobile/` layout (it assumes the convention from `scaffolding-saas-project`).
   - Do NOT use this skill for non-implementation tasks (docs, planning, research) — SDD doesn't dispatch implementers for those.

6. **The Routing Table** — literal table mapping diff predicates to templates with priority:

   ```markdown
   | Priority | Predicate | Template |
   |---|---|---|
   | 1 | All file paths in the task's "Files:" section match `apps/api/**` (no exceptions) | `templates/implementer-fastapi.md` |
   | 2 | All file paths match `apps/mobile/**` (no exceptions) | `templates/implementer-expo.md` |
   | 3 | Anything else (mixed paths, paths outside `apps/`, no recognizable layer) | `templates/implementer-default.md` |
   ```

   Mixed-path tasks (e.g., one task touching both API and mobile) fall through to default — the implementer needs cross-layer awareness, which the specialized templates don't provide.

7. **Process**:

   - **Step 1: Read the task's Files section.** Extract all paths under "Create:", "Modify:", "Test:".
   - **Step 2: Apply the routing predicate in priority order.** First match wins.
   - **Step 3: Render the chosen template.** Substitute placeholders with task-specific context (`{TASK_NUMBER}`, `{TASK_NAME}`, `{TASK_DESCRIPTION}`, `{CONTEXT}`, `{WORKING_DIRECTORY}`).
   - **Step 4: Dispatch the Task.** `Task(subagent_type=general-purpose, description=..., prompt=<rendered template>)`.
   - **Step 5: Return to SDD's normal flow.** Wait for implementer report, run spec compliance review, run code quality review.

8. **Flow** (graphviz `dot` block, mirroring MAR's style):

   ```dot
   digraph flow {
       rankdir=TB;
       "Read task Files section" [shape=box];
       "All paths in apps/api/**?" [shape=diamond];
       "All paths in apps/mobile/**?" [shape=diamond];
       "Render implementer-fastapi" [shape=box style=filled fillcolor=lightblue];
       "Render implementer-expo" [shape=box style=filled fillcolor=lightblue];
       "Render implementer-default" [shape=box style=filled fillcolor=lightyellow];
       "Dispatch Task" [shape=box];
       "Return to SDD review loop" [shape=box style=filled fillcolor=lightgreen];

       "Read task Files section" -> "All paths in apps/api/**?";
       "All paths in apps/api/**?" -> "Render implementer-fastapi" [label="yes"];
       "All paths in apps/api/**?" -> "All paths in apps/mobile/**?" [label="no"];
       "All paths in apps/mobile/**?" -> "Render implementer-expo" [label="yes"];
       "All paths in apps/mobile/**?" -> "Render implementer-default" [label="no"];
       "Render implementer-fastapi" -> "Dispatch Task";
       "Render implementer-expo" -> "Dispatch Task";
       "Render implementer-default" -> "Dispatch Task";
       "Dispatch Task" -> "Return to SDD review loop";
   }
   ```

9. **Integration with subagent-driven-development**:

   ```markdown
   This skill runs at SDD's "Dispatch implementer subagent" step. Instead of using the default `subagent-driven-development/implementer-prompt.md`, the SDD orchestrator consults this skill to pick a domain-aware template. After dispatch, SDD's review loop (spec compliance → code quality) proceeds unchanged.
   ```

10. **Adding a New Template** — when a fourth domain emerges (Next.js admin, infra, database, etc.):

    1. Drop a new `implementer-<name>.md` under `templates/` with the same envelope as existing templates (header + Task tool block + placeholders + stack-specific guidance + anti-patterns).
    2. Add a row to the routing table at the appropriate priority. Choose the predicate carefully — overlap with existing predicates breaks the "first match wins" rule.
    3. Build a planted task fixture and validate via the existing pressure-test loop (RED with default template + GREEN with new template).
    4. Commit fixture and template together.

11. **Anti-Patterns**:

    - DON'T dispatch multiple templates for one task (exactly one fires per task).
    - DON'T use a specialized template for a mixed-path task — fall back to default. Cross-layer awareness matters.
    - DON'T skip the announce step — the user/orchestrator needs to know which template was chosen.
    - DON'T fork upstream's `subagent-driven-development/implementer-prompt.md` content into specialized templates without keeping `implementer-default.md` in sync. When upstream improves the prompt, propagate to default first, then re-merge into specialized variants.
    - DON'T add a new template without a planted fixture and pressure-test — untested templates are worse than no template (they give false confidence).

12. **Future Templates** — added per real-world need: `implementer-nextjs.md` (when web admin work begins), `implementer-infra.md` (Docker/Terraform/CI), `implementer-database.md` (migration-heavy or schema-design tasks).

Aim for ~200-260 lines of SKILL.md.

- [ ] **Step 2: Routing predicate validation — walk through edge cases**

For each test task below, manually evaluate the routing rule and confirm the expected template:

| Test task — Files: section | Expected template |
|---|---|
| `apps/api/app/routers/notes.py` only | implementer-fastapi |
| `apps/api/app/models/note.py` AND `apps/api/alembic/versions/0001_notes.py` | implementer-fastapi |
| `apps/mobile/app/notes/index.tsx` only | implementer-expo |
| `apps/mobile/app/notes/index.tsx` AND `apps/mobile/lib/store.ts` | implementer-expo |
| `apps/api/app/routers/notes.py` AND `apps/mobile/app/notes/index.tsx` | implementer-default (mixed) |
| `scripts/seed.py` only | implementer-default (outside apps/) |
| `infra/docker-compose.yml` only | implementer-default |
| `apps/api/alembic/versions/0042_add_orgs.py` only | implementer-fastapi |
| `apps/api/tests/test_notes.py` AND `apps/api/app/routers/notes.py` | implementer-fastapi |
| `README.md` only | implementer-default |

If any predicate misroutes, fix the SKILL.md predicate definition and re-validate.

- [ ] **Step 3: End-to-end smoke test — render via the skill, dispatch a real implementer**

Pick the FastAPI fixture (`/tmp/saas-fixtures/dda-fastapi-task/`). Walk through the full flow:

1. Read the task description from `/tmp/saas-fixtures/dda-fastapi-task/README.md`.
2. Apply the routing rule against the task's Files section. Confirm `implementer-fastapi.md` is chosen.
3. Render `implementer-fastapi.md` with the task context.
4. Dispatch the Task. Confirm the implementer produces a report with status DONE and code that passes the GREEN checklist from Task 5.

Same for Expo fixture: confirm `implementer-expo.md` is chosen, dispatched, and produces a passing report.

- [ ] **Step 4: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/dispatching-domain-agents/SKILL.md && git commit -m "feat(dispatching-domain-agents): add SKILL.md with routing logic and three-template orchestration"
```

---

### Task 10: Add integration note to `subagent-driven-development/SKILL.md`

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/subagent-driven-development/SKILL.md`

- [ ] **Step 1: Read the current SKILL.md to find the insertion point**

```bash
grep -n '^##' /Users/marcin/Projects/superpowers/skills/subagent-driven-development/SKILL.md
```

The "Prompt Templates" section (currently lists `./implementer-prompt.md`, `./spec-reviewer-prompt.md`, `./code-quality-reviewer-prompt.md`) is the natural insertion point. Add the new section just before "Example Workflow".

- [ ] **Step 2: Append the integration section**

Insert this section between "Prompt Templates" and "Example Workflow":

```markdown
## Domain-Aware Dispatch (optional)

If the project has the framework's `apps/api/` and `apps/mobile/` layout (typically: a SaaS scaffolded by `superpowers:scaffolding-saas-project`), use `superpowers:dispatching-domain-agents` to pick a domain-specific implementer template before dispatching the Task. It routes the task to `implementer-fastapi` (for `apps/api/**` tasks), `implementer-expo` (for `apps/mobile/**` tasks), or `implementer-default` (for mixed/other paths). Domain templates encode stack-specific patterns the default prompt doesn't (async SQLAlchemy, multi-tenant session factory, expo-router, MobileMCP verification).

When `dispatching-domain-agents` is not active, the default `implementer-prompt.md` above is used directly.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/subagent-driven-development/SKILL.md && git commit -m "docs(subagent-driven-development): mention dispatching-domain-agents as optional dispatch helper"
```

---

### Task 11: Verify skill loads in a fresh Claude session

**Files:** none (verification only)

- [ ] **Step 1: Reload the plugin in Claude Code**

In a fresh Claude Code session in this repo, run `/plugin reload superpowers`. Or restart Claude Code.

- [ ] **Step 2: Confirm the skill appears in the available skills list**

Trigger the listing mechanism (e.g., type `/` and check the skills list, or ask Claude "what skills are available?"). Confirm `dispatching-domain-agents` appears.

- [ ] **Step 3: Trigger the skill explicitly**

Ask Claude: "Use the dispatching-domain-agents skill to pick the right implementer template for a task that touches `apps/api/app/routers/notes.py` only."

Expected: Claude announces "I'm using the dispatching-domain-agents skill to pick the fastapi implementer template" and explains the routing reasoning.

- [ ] **Step 4: No commit (verification)**

---

### Task 12: Update `RELEASE-NOTES.md`

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/RELEASE-NOTES.md`

- [ ] **Step 1: Add to Unreleased section**

Read the current `RELEASE-NOTES.md` to find the `## Unreleased` section. Add this bullet after the existing `multi-angle-review` bullet:

```markdown
- Added `dispatching-domain-agents` skill: routes SDD's implementer dispatch to a domain-specific template (`implementer-fastapi`, `implementer-expo`, or `implementer-default`) based on the task's primary file paths. Two domain templates ship initially, each pressure-tested against a planted task fixture (RED with default + GREEN with specialized). Integration note added to `subagent-driven-development/SKILL.md`. Phase 1.5 will refactor templates into proper Claude Code agent definitions; for now they're dispatched inline by the SDD orchestrator.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add RELEASE-NOTES.md && git commit -m "docs: note dispatching-domain-agents skill in release notes"
```

---

## Self-review

**Spec coverage:** Plan covers all of Phase 1 step 3 from the meta-plan: SKILL.md (Task 9) + 3 implementer templates (Tasks 2, 5, 8) + each pressure-tested with planted fixture (Tasks 3+4 for FastAPI; Tasks 6+7 for Expo) — except `implementer-default.md` doesn't get a separate pressure test because it IS the baseline used to establish RED for the specialized templates. SDD integration note (Task 10). Verification gate (Task 11). Release notes (Task 12). The deferred Phase 1.5 refactor (templates → agent definitions) is documented in the architecture preamble and the RELEASE-NOTES bullet, not implemented here.

**Placeholder scan:** No "TBD", "implement later", "similar to Task N" patterns. Code blocks present where code is required. Template body outlines (Tasks 2, 5, 8, 9) describe required sections concretely; the implementer writes the prose, but every section's purpose, the placeholders, the stack-specific guidance bullets, and the anti-patterns are specified.

**Type/name consistency:** `implementer-fastapi.md`, `implementer-expo.md`, `implementer-default.md` used consistently. Placeholders (`{TASK_NUMBER}`, `{TASK_NAME}`, `{TASK_DESCRIPTION}`, `{CONTEXT}`, `{WORKING_DIRECTORY}`) defined in Task 2 and reused identically in Tasks 5, 8, 9. Fixture paths use the same root `/tmp/saas-fixtures/dda-*`. The end-to-end smoke test in Task 9 reuses the same fixtures from Tasks 3 and 6.

**Known deviation from strict writing-plans:** Template *bodies* (the actual ~150-250-line markdown of each implementer prompt) are described by required-sections outline rather than written inline in the plan. Same justification as MAR's plan: writing the full body inline would be writing the skill via plan, an anti-pattern. Each template is RED/GREEN-validated in the same task that creates it.

**Validation methodology note:** This plan uses comparative RED/GREEN (default template vs. specialized template against the same fixture) rather than the buggy/clean-fixture pattern MAR used. Reasoning: domain-specific implementer prompts aren't catching bugs — they're producing better stack-correct code. The right comparison is "what does the default produce here?" vs. "what does the specialized produce here?". The clean-vs-buggy pattern doesn't map.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-10-dispatching-domain-agents.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
