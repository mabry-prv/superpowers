# Multi-Angle Review Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `multi-angle-review` skill that dispatches three role-specific reviewer subagents (multitenant-isolation, migration-safety, security) based on diff content, integrating with the existing `requesting-code-review` flow. Each reviewer template is RED/GREEN-validated against a planted-bug fixture before commit.

**Architecture:** New skill at `skills/multi-angle-review/` containing `SKILL.md` (orchestration: read diff, route to reviewers, aggregate findings) and three reviewer-prompt-templates under `templates/`. Each reviewer is dispatched as a `general-purpose` Task with the template body as prompt. The three reviewers run in parallel (parallel-Task pattern). Findings aggregated by severity (Critical / Important / Suggestion). Critical findings block the PR.

**Tech Stack:** Markdown for skill content. Bash for orchestration sketches in SKILL.md. Python (FastAPI + SQLAlchemy 2.0 + Alembic) for planted-bug fixtures. The `Task` tool with `subagent_type: general-purpose` for dispatch.

**Fixtures location:** Planted-bug fixtures live OUTSIDE the repo at `/tmp/saas-fixtures/`. They're inputs to pressure tests, not artifacts to ship.

---

### Task 1: Scaffold the skill directory

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/multi-angle-review/SKILL.md`
- Create: `/Users/marcin/Projects/superpowers/skills/multi-angle-review/templates/.gitkeep`

- [ ] **Step 1: Create the directory tree**

```bash
mkdir -p /Users/marcin/Projects/superpowers/skills/multi-angle-review/templates
```

- [ ] **Step 2: Write a placeholder SKILL.md (frontmatter + heading only)**

Write to `/Users/marcin/Projects/superpowers/skills/multi-angle-review/SKILL.md`:

```markdown
---
name: multi-angle-review
description: Use after standard code review passes to dispatch role-specific reviewer subagents (multitenant-isolation, migration-safety, security) based on diff content. Critical findings block.
---

# Multi-Angle Review

(Body populated in Task 9.)
```

- [ ] **Step 3: .gitkeep so empty templates dir is tracked**

```bash
touch /Users/marcin/Projects/superpowers/skills/multi-angle-review/templates/.gitkeep
```

- [ ] **Step 4: Verify the skill is discoverable**

```bash
cd /Users/marcin/Projects/superpowers && head -5 skills/multi-angle-review/SKILL.md
```

Expected output: the frontmatter block with `name: multi-angle-review`.

- [ ] **Step 5: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/multi-angle-review/ && git commit -m "feat: scaffold multi-angle-review skill directory"
```

---

### Task 2: Build the multitenant-isolation planted-bug fixture

**Files:**
- Create: `/tmp/saas-fixtures/mt-isolation-bug/app/__init__.py`
- Create: `/tmp/saas-fixtures/mt-isolation-bug/app/models.py`
- Create: `/tmp/saas-fixtures/mt-isolation-bug/app/api.py`
- Create: `/tmp/saas-fixtures/mt-isolation-bug/README.md`
- Create: `/tmp/saas-fixtures/mt-isolation-clean/app/api.py` (the GREEN counter-fixture)

The bug fixture is what reviewer must catch. The clean fixture is what reviewer must NOT false-positive on.

- [ ] **Step 1: Create both fixture directories**

```bash
mkdir -p /tmp/saas-fixtures/mt-isolation-bug/app /tmp/saas-fixtures/mt-isolation-clean/app
touch /tmp/saas-fixtures/mt-isolation-bug/app/__init__.py /tmp/saas-fixtures/mt-isolation-clean/app/__init__.py
```

- [ ] **Step 2: Write the org-scoped model (shared shape)**

Write to `/tmp/saas-fixtures/mt-isolation-bug/app/models.py`:

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass

class Note(Base):
    __tablename__ = "notes"
    id: Mapped[int] = mapped_column(primary_key=True)
    org_id: Mapped[int] = mapped_column(index=True)
    title: Mapped[str]
    body: Mapped[str]
```

```bash
cp /tmp/saas-fixtures/mt-isolation-bug/app/models.py /tmp/saas-fixtures/mt-isolation-clean/app/
```

- [ ] **Step 3: Write the BUG version of the API**

Write to `/tmp/saas-fixtures/mt-isolation-bug/app/api.py`:

```python
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from .models import Note

# Imagine `get_db` and `get_current_user` are defined elsewhere.
# Current user has user.org_id

router = APIRouter()

@router.get("/notes")
async def list_notes(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    # BUG #1: missing org_id filter — returns notes from EVERY org.
    result = await db.execute(select(Note))
    return result.scalars().all()

@router.get("/notes/{note_id}")
async def get_note(note_id: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    # BUG #2: org_id filter present but no user.org_id check — IDOR risk
    note = await db.get(Note, note_id)
    return note

@router.post("/notes")
async def create_note(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    # BUG #3: takes org_id from request body instead of session
    note = Note(org_id=payload["org_id"], title=payload["title"], body=payload["body"])
    db.add(note)
    await db.commit()
    return note
```

- [ ] **Step 4: Write the CLEAN version of the API**

Write to `/tmp/saas-fixtures/mt-isolation-clean/app/api.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from .models import Note

router = APIRouter()

@router.get("/notes")
async def list_notes(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    result = await db.execute(select(Note).where(Note.org_id == user.org_id))
    return result.scalars().all()

@router.get("/notes/{note_id}")
async def get_note(note_id: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    note = await db.get(Note, note_id)
    if note is None or note.org_id != user.org_id:
        raise HTTPException(404)
    return note

@router.post("/notes")
async def create_note(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    note = Note(org_id=user.org_id, title=payload["title"], body=payload["body"])
    db.add(note)
    await db.commit()
    return note
```

- [ ] **Step 5: Write README for both**

Write to `/tmp/saas-fixtures/mt-isolation-bug/README.md`:

```markdown
# Multitenant Isolation BUG Fixture

Three planted bugs in `app/api.py`:
1. `list_notes` — missing org_id filter
2. `get_note` — IDOR; no org_id check after fetch
3. `create_note` — accepts org_id from request body

Reviewer must flag #1 and #2 at Critical, #3 at Critical.
```

- [ ] **Step 6: No commit (fixtures live outside the repo)**

---

### Task 3: Establish RED baseline for multitenant-isolation

Verify the upstream code-reviewer template (without our specialized template) does NOT reliably catch all three bugs. Establishes the value our template adds.

**Files:** none

- [ ] **Step 1: Read the existing reviewer template**

```bash
wc -l /Users/marcin/Projects/superpowers/skills/requesting-code-review/code-reviewer.md
```

Note the line count and skim the body.

- [ ] **Step 2: Dispatch a baseline reviewer**

Use the `Task` tool:

```
description: "Baseline review (no specialized template)"
subagent_type: general-purpose
prompt: |
  Use the template at /Users/marcin/Projects/superpowers/skills/requesting-code-review/code-reviewer.md.

  DESCRIPTION: List/get/create endpoints for org-scoped Notes resource.
  PLAN_OR_REQUIREMENTS: Notes are org-scoped via Note.org_id. Each endpoint must enforce that the current user only sees/modifies notes belonging to user.org_id.
  BASE_SHA: (none — fresh fixture)
  HEAD_SHA: (none)

  Files to review:
  - /tmp/saas-fixtures/mt-isolation-bug/app/models.py
  - /tmp/saas-fixtures/mt-isolation-bug/app/api.py
```

- [ ] **Step 3: Record findings**

Capture in scratch notes (no file commit needed):
- Did baseline catch BUG #1 (missing filter)?
- Did baseline catch BUG #2 (IDOR)?
- Did baseline catch BUG #3 (org_id from body)?
- At what severity?

Expected: baseline catches #1 (obvious), inconsistent on #2, may miss #3 entirely. The next task's template strengthens these.

- [ ] **Step 4: No commit (research)**

---

### Task 4: Write the multitenant-isolation reviewer template

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/multi-angle-review/templates/reviewer-multitenant-isolation.md`

- [ ] **Step 1: Draft the template body**

The template MUST contain these sections (write them in order):

1. **Frontmatter-style heading**: `# Reviewer Template: Multi-Tenant Isolation`
2. **Role statement**: "You are reviewing code in a multi-tenant B2B SaaS. Your sole concern is whether tenant boundaries are correctly enforced. Do NOT comment on style, performance, or other concerns — those have separate reviewers."
3. **The canonical pattern** (~30 lines): describes the SQLAlchemy session-factory + FastAPI middleware approach. State explicitly: every query against an org-scoped model goes through the org-scoped session factory; no endpoint accepts `org_id` as input from the client; the `org_id` always comes from the verified session/JWT.
4. **Severity rules** (concrete examples):
   - **Critical**: query against an org-scoped model with no `org_id` filter; endpoint accepts `org_id` from request body/query; endpoint returns a row without verifying `row.org_id == user.org_id`.
   - **Important**: tests bypass the session factory without an explicit isolation-test marker; manual cross-tenant check ("if note.org_id != ...") that should have been enforced by the session factory.
   - **Suggestion**: org-scoped model that doesn't have `org_id` indexed.
5. **Output format**: severity-grouped Markdown findings. Refuse to approve if any Critical. End with one of: `APPROVED`, `BLOCKED — N Critical findings`, or `APPROVED WITH SUGGESTIONS`.
6. **Anti-patterns the reviewer should NOT do**: don't flag style; don't flag perf; don't suggest refactoring; don't approve a PR you haven't actually read every diff in.

Write the actual file with these sections. Aim for ~120-180 lines. Mirror the prose style of `skills/requesting-code-review/code-reviewer.md`.

- [ ] **Step 2: Pressure-test against the BUG fixture**

Dispatch a Task with the new template:

```
description: "Multitenant-isolation reviewer (with template)"
subagent_type: general-purpose
prompt: |
  [paste the contents of skills/multi-angle-review/templates/reviewer-multitenant-isolation.md]

  DESCRIPTION: List/get/create endpoints for org-scoped Notes resource.
  PLAN_OR_REQUIREMENTS: Notes are org-scoped via Note.org_id.
  BASE_SHA: (none — fresh fixture)
  HEAD_SHA: (none)

  Files to review:
  - /tmp/saas-fixtures/mt-isolation-bug/app/models.py
  - /tmp/saas-fixtures/mt-isolation-bug/app/api.py
```

- [ ] **Step 3: Verify GREEN — three Critical flags + BLOCKED verdict**

Expected:
- Reviewer flags BUG #1 (missing filter) at Critical
- Reviewer flags BUG #2 (IDOR) at Critical
- Reviewer flags BUG #3 (org_id from body) at Critical
- Final verdict: `BLOCKED — 3 Critical findings`

If reviewer misses any: revise template (likely needs more directive language about "EVERY query MUST pass through ..."). Re-run. Iterate to GREEN.

- [ ] **Step 4: Pressure-test against the CLEAN fixture (no false positive)**

Dispatch the same Task but pointing at `/tmp/saas-fixtures/mt-isolation-clean/app/`. Expected: APPROVED or APPROVED WITH SUGGESTIONS. NO Critical findings.

If reviewer flags Critical on clean: template is too aggressive. Soften the predicate or add "exception when ..." rules. Iterate.

- [ ] **Step 5: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/multi-angle-review/templates/reviewer-multitenant-isolation.md && git commit -m "feat(multi-angle-review): add multitenant-isolation reviewer template"
```

---

### Task 5: Build the migration-safety planted-bug fixture

**Files:**
- Create: `/tmp/saas-fixtures/migration-bug/alembic/versions/0001_initial.py`
- Create: `/tmp/saas-fixtures/migration-bug/alembic/versions/0002_destructive.py`
- Create: `/tmp/saas-fixtures/migration-clean/alembic/versions/0001_initial.py`
- Create: `/tmp/saas-fixtures/migration-clean/alembic/versions/0002_safe.py`
- Create: `/tmp/saas-fixtures/migration-clean/alembic/versions/0003_finalize.py`

The bug fixture has a destructive migration in one shot. The clean fixture splits the same change across two migrations with a backward-compat window.

- [ ] **Step 1: Create directories**

```bash
mkdir -p /tmp/saas-fixtures/migration-bug/alembic/versions /tmp/saas-fixtures/migration-clean/alembic/versions
```

- [ ] **Step 2: Write the BUG migration (initial + destructive)**

Write to `/tmp/saas-fixtures/migration-bug/alembic/versions/0001_initial.py`:

```python
"""initial users table"""
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None

def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("display_name", sa.String(255), nullable=True),
    )

def downgrade() -> None:
    op.drop_table("users")
```

Write to `/tmp/saas-fixtures/migration-bug/alembic/versions/0002_destructive.py`:

```python
"""rename display_name -> full_name and make NOT NULL"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"

def upgrade() -> None:
    # BUG: combines rename + NOT NULL in one shot
    # Old code reading users.display_name will crash; rows with NULL violate constraint
    op.alter_column("users", "display_name", new_column_name="full_name", nullable=False)

def downgrade() -> None:
    op.alter_column("users", "full_name", new_column_name="display_name", nullable=True)
```

- [ ] **Step 3: Write the CLEAN migrations (split into safe steps)**

Write to `/tmp/saas-fixtures/migration-clean/alembic/versions/0001_initial.py` (same as bug fixture's 0001).

Write to `/tmp/saas-fixtures/migration-clean/alembic/versions/0002_safe.py`:

```python
"""add full_name column (nullable for backward-compat); backfill"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"

def upgrade() -> None:
    op.add_column("users", sa.Column("full_name", sa.String(255), nullable=True))
    op.execute("UPDATE users SET full_name = display_name WHERE full_name IS NULL")

def downgrade() -> None:
    op.drop_column("users", "full_name")
```

Write to `/tmp/saas-fixtures/migration-clean/alembic/versions/0003_finalize.py`:

```python
"""drop display_name; make full_name NOT NULL (after code stops reading display_name)"""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"

def upgrade() -> None:
    op.alter_column("users", "full_name", nullable=False)
    op.drop_column("users", "display_name")

def downgrade() -> None:
    op.add_column("users", sa.Column("display_name", sa.String(255), nullable=True))
    op.alter_column("users", "full_name", nullable=True)
    op.execute("UPDATE users SET display_name = full_name WHERE display_name IS NULL")
```

- [ ] **Step 4: Write README**

Write to `/tmp/saas-fixtures/migration-bug/README.md`:

```markdown
# Migration Safety BUG Fixture

`alembic/versions/0002_destructive.py` combines column rename + NOT NULL constraint in a single migration with no backward-compat window. Reviewer must flag at Critical and refuse to approve.
```

- [ ] **Step 5: No commit (fixtures outside repo)**

---

### Task 6: Write the migration-safety reviewer template

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/multi-angle-review/templates/reviewer-migration-safety.md`

- [ ] **Step 1: Draft the template**

Required sections:

1. **Heading + role**: `# Reviewer Template: Migration Safety` + "You are reviewing Alembic migrations for production-safety. Concern: zero-downtime correctness."
2. **The canonical rules**:
   - Every migration must be reversible (`downgrade()` non-empty and correct).
   - Destructive changes (drop column, rename column, change type, add NOT NULL without default) cannot ship in the same migration as code that depends on the new shape.
   - Rename = add new column + backfill (one migration) → switch code to use new (deploy) → drop old (next migration).
   - Add NOT NULL = add nullable + backfill → switch code (deploy) → make NOT NULL (next migration).
   - Index creation on large tables uses `CREATE INDEX CONCURRENTLY` (Postgres) — wrapped in a transaction-less migration.
3. **Severity**:
   - Critical: combined rename+NOT NULL; drop column with no preceding deprecation migration; non-reversible without explicit "irreversible" comment justifying it.
   - Important: missing index on a foreign key; backfill without WHERE clause for resumability.
   - Suggestion: lack of inline comment explaining the migration's intent.
4. **Output format**: same as Task 4 (severity groups + verdict).

Mirror reviewer-multitenant-isolation.md's structure. ~100-150 lines.

- [ ] **Step 2: Pressure-test against the BUG fixture**

Dispatch:

```
description: "Migration-safety reviewer"
subagent_type: general-purpose
prompt: |
  [paste templates/reviewer-migration-safety.md]

  DESCRIPTION: Rename users.display_name to users.full_name and make it NOT NULL.
  PLAN_OR_REQUIREMENTS: Existing rows have nullable display_name; new code requires full_name.

  Files to review: /tmp/saas-fixtures/migration-bug/alembic/versions/*.py
```

- [ ] **Step 3: Verify GREEN**

Expected: Critical flag on `0002_destructive.py` (rename + NOT NULL combined), BLOCKED verdict.

- [ ] **Step 4: Pressure-test against the CLEAN fixture**

Same dispatch but pointing at `/tmp/saas-fixtures/migration-clean/alembic/versions/`. Expected: APPROVED. The clean fixture splits the change correctly.

- [ ] **Step 5: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/multi-angle-review/templates/reviewer-migration-safety.md && git commit -m "feat(multi-angle-review): add migration-safety reviewer template"
```

---

### Task 7: Build the security planted-bug fixture

**Files:**
- Create: `/tmp/saas-fixtures/security-bug/app/auth.py`
- Create: `/tmp/saas-fixtures/security-bug/app/billing.py`
- Create: `/tmp/saas-fixtures/security-clean/app/auth.py`
- Create: `/tmp/saas-fixtures/security-clean/app/billing.py`

- [ ] **Step 1: Create directories**

```bash
mkdir -p /tmp/saas-fixtures/security-bug/app /tmp/saas-fixtures/security-clean/app
```

- [ ] **Step 2: Write BUG auth.py**

Write to `/tmp/saas-fixtures/security-bug/app/auth.py`:

```python
import logging

logger = logging.getLogger(__name__)

def create_user(email: str, password: str):
    # BUG: plaintext password storage
    user = {"email": email, "password": password}
    # BUG: logging credentials
    logger.info(f"Creating user {email} with password {password}")
    db.users.insert(user)

def login(email: str, password: str):
    # BUG: SQL injection (string concat)
    query = f"SELECT * FROM users WHERE email = '{email}' AND password = '{password}'"
    return db.execute(query).fetchone()
```

- [ ] **Step 3: Write BUG billing.py**

Write to `/tmp/saas-fixtures/security-bug/app/billing.py`:

```python
from fastapi import APIRouter, Request

router = APIRouter()

@router.post("/webhooks/stripe")
async def stripe_webhook(request: Request):
    # BUG: no signature verification — anyone can post fake events
    payload = await request.json()
    event_type = payload["type"]
    if event_type == "invoice.paid":
        org_id = payload["data"]["object"]["metadata"]["org_id"]
        # BUG: not idempotent — replayed events double-charge
        await mark_org_paid(org_id)
    return {"ok": True}
```

- [ ] **Step 4: Write CLEAN auth.py**

Write to `/tmp/saas-fixtures/security-clean/app/auth.py`:

```python
import logging
from passlib.hash import bcrypt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

async def create_user(db: AsyncSession, email: str, password: str):
    password_hash = bcrypt.hash(password)
    user = User(email=email, password_hash=password_hash)
    db.add(user)
    await db.commit()
    logger.info(f"User created", extra={"user_email": email})

async def login(db: AsyncSession, email: str, password: str):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None or not bcrypt.verify(password, user.password_hash):
        return None
    return user
```

- [ ] **Step 5: Write CLEAN billing.py**

Write to `/tmp/saas-fixtures/security-clean/app/billing.py`:

```python
import stripe
from fastapi import APIRouter, Request, HTTPException
from sqlalchemy import select
from .config import settings
from .models import StripeEventSeen

router = APIRouter()

@router.post("/webhooks/stripe")
async def stripe_webhook(request: Request, db=Depends(get_db)):
    payload = await request.body()
    sig = request.headers.get("stripe-signature")
    try:
        event = stripe.Webhook.construct_event(payload, sig, settings.STRIPE_WEBHOOK_SECRET)
    except (ValueError, stripe.error.SignatureVerificationError):
        raise HTTPException(400, "invalid signature")

    seen = await db.get(StripeEventSeen, event.id)
    if seen is not None:
        return {"ok": True, "deduped": True}

    db.add(StripeEventSeen(id=event.id))

    if event.type == "invoice.paid":
        org_id = event.data.object.metadata.get("org_id")
        await mark_org_paid(db, org_id)

    await db.commit()
    return {"ok": True}
```

- [ ] **Step 6: No commit (fixtures outside repo)**

---

### Task 8: Write the security reviewer template

**Files:**
- Create: `/Users/marcin/Projects/superpowers/skills/multi-angle-review/templates/reviewer-security.md`

- [ ] **Step 1: Draft the template**

Required sections:

1. **Heading + role**: `# Reviewer Template: Security` + "You are reviewing code for security defects. Concerns: secret handling, input validation, injection, auth, webhook integrity."
2. **OWASP-aligned checklist (FastAPI-flavored)**:
   - Injection (SQL via string concat or unsafe `text()`)
   - Broken Auth (plaintext passwords, weak hashing, session fixation)
   - Sensitive Data Exposure (password in logs, secrets in code, secrets via env BUT printed in tracebacks)
   - Broken Access Control (missing auth dep on endpoints; missing org-scope checks — defer to multitenant-isolation reviewer for that)
   - Security Misconfig (debug=True in prod, CORS too permissive, unverified webhooks)
   - Webhook integrity (no signature verification; no idempotency on stateful handlers)
3. **Severity**:
   - Critical: SQL injection; plaintext password storage; webhook with no signature verification; secret committed to code; auth bypass.
   - Important: log statement that includes credentials/PII; missing idempotency on stateful webhook; CSRF if cookie auth without samesite.
   - Suggestion: rate limiting opportunity; security header missing.
4. **Output format**: same as Task 4 (severity + verdict).

~150-200 lines. Mirror style of the other two reviewers.

- [ ] **Step 2: Pressure-test against BUG fixture**

```
description: "Security reviewer"
subagent_type: general-purpose
prompt: |
  [paste templates/reviewer-security.md]

  DESCRIPTION: Auth and Stripe webhook implementation.
  PLAN_OR_REQUIREMENTS: Standard B2B SaaS auth + Stripe billing.

  Files to review: /tmp/saas-fixtures/security-bug/app/*.py
```

- [ ] **Step 3: Verify GREEN**

Expected Critical flags (at minimum):
- `auth.py:create_user` — plaintext password
- `auth.py:create_user` — credentials in log
- `auth.py:login` — SQL injection
- `billing.py:stripe_webhook` — no signature verification
- `billing.py:stripe_webhook` — not idempotent

Verdict: BLOCKED — N Critical findings.

- [ ] **Step 4: Pressure-test against CLEAN fixture**

```
Files to review: /tmp/saas-fixtures/security-clean/app/*.py
```

Expected: APPROVED or APPROVED WITH SUGGESTIONS. No Critical.

- [ ] **Step 5: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/multi-angle-review/templates/reviewer-security.md && git commit -m "feat(multi-angle-review): add security reviewer template"
```

---

### Task 9: Write multi-angle-review/SKILL.md (the orchestrator)

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/multi-angle-review/SKILL.md`

- [ ] **Step 1: Draft the SKILL.md body**

Required sections:

1. **Frontmatter** (already there from Task 1): `name: multi-angle-review`, description.
2. **Overview**: when to use (after standard code-review passes; before declaring a feature shippable).
3. **Announce at start**: "I'm using the multi-angle-review skill to dispatch role-specific reviewers."
4. **Routing rules** — a literal table mapping diff predicates to templates:

   ```markdown
   | Trigger | Template |
   |---|---|
   | Diff touches `apps/api/**/*.py` AND introduces or changes a `select()`/`update()`/`delete()`/`db.get()` against an org-scoped model OR a route accessing org-scoped data | reviewer-multitenant-isolation.md |
   | Diff touches `**/alembic/versions/*.py` (new file or modified) | reviewer-migration-safety.md |
   | Diff touches `apps/api/**/auth/**`, `apps/api/**/billing/**`, any new HTTP/webhook handler, any code introducing secret handling, password hashing, SQL composition | reviewer-security.md |
   ```

5. **Process**:
   - Step 1: Read the diff (use `git diff <base>..HEAD`).
   - Step 2: For each routing rule, evaluate the predicate against the diff. List which templates fire.
   - Step 3: Dispatch all matched reviewers as parallel `Task(subagent_type=general-purpose)` calls — single message with multiple Task blocks.
   - Step 4: Aggregate results. Group findings by severity. Print summary table: reviewer / verdict / Critical count / Important count.
   - Step 5: If any reviewer returned Critical: print BLOCKED verdict and the Critical findings inline. Stop.
   - Step 6: If only Important + Suggestions: print APPROVED WITH SUGGESTIONS.
   - Step 7: If all reviewers returned APPROVED: print APPROVED.

6. **Integration with `requesting-code-review`**: this skill runs as a follow-up to it. After RCR's general code-reviewer returns APPROVED, run multi-angle-review.

7. **Adding a new reviewer template**: drop a new `reviewer-<name>.md` under `templates/`; add a row to the routing table; pressure-test it via planted bug + clean counter-fixture.

8. **Anti-patterns**: don't run multi-angle-review BEFORE the general code-reviewer; don't skip reviewers because "the diff is small"; don't treat Important as Critical to inflate severity.

Aim for ~150-200 lines of SKILL.md.

- [ ] **Step 2: End-to-end pressure test — diff with multiple bug classes**

Construct a fake diff that spans bugs in all three categories:

```bash
mkdir -p /tmp/saas-fixtures/multi-angle-end-to-end/{app,alembic/versions}
cp /tmp/saas-fixtures/mt-isolation-bug/app/*.py /tmp/saas-fixtures/multi-angle-end-to-end/app/
cp /tmp/saas-fixtures/migration-bug/alembic/versions/0002_destructive.py /tmp/saas-fixtures/multi-angle-end-to-end/alembic/versions/
cp /tmp/saas-fixtures/security-bug/app/auth.py /tmp/saas-fixtures/multi-angle-end-to-end/app/
```

Manually run the SKILL.md routing logic against this fixture: predict which reviewers should fire (all three).

- [ ] **Step 3: Dispatch all three in parallel**

In a single message, dispatch three Task calls (multitenant-isolation, migration-safety, security) against the multi-bug fixture. Confirm each returns BLOCKED with the expected Critical findings.

- [ ] **Step 4: Verify aggregation**

Manually walk through the SKILL.md aggregation step: combine the three results, confirm the verdict is BLOCKED with N Critical findings (from all three reviewers). Confirm the summary table format renders correctly.

- [ ] **Step 5: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/multi-angle-review/SKILL.md && git commit -m "feat(multi-angle-review): add SKILL.md with routing logic and three-reviewer orchestration"
```

---

### Task 10: Add integration note to requesting-code-review/SKILL.md

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/skills/requesting-code-review/SKILL.md`

- [ ] **Step 1: Read the current SKILL.md**

```bash
cat /Users/marcin/Projects/superpowers/skills/requesting-code-review/SKILL.md
```

Identify a natural insertion point (likely near the end, after the main flow).

- [ ] **Step 2: Append integration note**

Add this section at an appropriate point:

```markdown
## Follow-up: Multi-Angle Review

If this project has the multi-angle-review skill conventions (typically: a multi-tenant SaaS with FastAPI + Postgres + Alembic), after the general code-reviewer returns APPROVED, run `superpowers:multi-angle-review` as a follow-up. It dispatches role-specific reviewers (multitenant-isolation, migration-safety, security) based on what the diff touches. Critical findings from multi-angle-review block the same way the general code-reviewer's Critical findings do.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add skills/requesting-code-review/SKILL.md && git commit -m "docs(requesting-code-review): mention multi-angle-review as follow-up"
```

---

### Task 11: Verify skill loads in a fresh Claude session

**Files:** none (verification only)

- [ ] **Step 1: Reload the plugin in Claude Code**

In a fresh Claude Code session in this repo, run `/plugin reload superpowers`. Or restart Claude Code.

- [ ] **Step 2: Confirm the skill appears**

Ask Claude: "What skills are available?" Confirm `multi-angle-review` is in the list.

- [ ] **Step 3: Trigger the skill explicitly**

Ask Claude: "Use the multi-angle-review skill on the diff in /tmp/saas-fixtures/multi-angle-end-to-end/." Confirm Claude announces "I'm using the multi-angle-review skill" and dispatches the three reviewers.

- [ ] **Step 4: No commit (verification)**

---

### Task 12: Update RELEASE-NOTES.md

**Files:**
- Modify: `/Users/marcin/Projects/superpowers/RELEASE-NOTES.md`

- [ ] **Step 1: Add to Unreleased section**

Add this bullet under `## Unreleased`:

```markdown
- Added `multi-angle-review` skill: dispatches role-specific reviewer subagents (multitenant-isolation, migration-safety, security) based on diff content. Three reviewer templates ship initially. Integration note added to `requesting-code-review/SKILL.md`. Validated against planted-bug fixtures.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/marcin/Projects/superpowers && git add RELEASE-NOTES.md && git commit -m "docs: note multi-angle-review skill in release notes"
```

---

## Self-review

**Spec coverage:** Plan covers all of Phase 1 step 2 from the meta-plan: SKILL.md (Task 9) + 3 reviewer templates (Tasks 4, 6, 8) + each pressure-tested with planted-bug + clean counter-fixture (Tasks 2, 5, 7) + integration note (Task 10) + release notes (Task 12). Verification gate (Task 11) confirms skill is discoverable.

**Placeholder scan:** No "TBD", "implement later", "similar to Task N" patterns. Code blocks present where code is required. Template body outlines (Tasks 4, 6, 8, 9) describe required sections concretely; the implementer writes the prose, but every section's purpose, severity rules, and verdict format are specified.

**Type/name consistency:** `reviewer-multitenant-isolation.md`, `reviewer-migration-safety.md`, `reviewer-security.md` used consistently. Fixture paths use the same root `/tmp/saas-fixtures/`. The end-to-end fixture composes the three bug fixtures by file copy.

**Known deviation from strict writing-plans:** Template *bodies* (the actual ~150-line markdown of each reviewer-prompt) are described by required-sections outline rather than written inline in the plan. Justification: the body is implementation work tested via the pressure-test loop in the same task. Writing the full ~600-line body inline in the plan would be writing the skill via plan, an anti-pattern.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-10-multi-angle-review-skill.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
