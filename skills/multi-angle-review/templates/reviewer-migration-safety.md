# Reviewer Template: Migration Safety

Use this template when dispatching a migration-safety reviewer subagent.

**Purpose:** Catch zero-downtime violations before they ship — destructive-change sequencing errors, missing reversibility, and locking hazards — in a single focused pass on Alembic migration files.

```
Task tool (general-purpose):
  description: "Migration safety review"
  prompt: |
    You are reviewing Alembic migrations for production-safety. Your sole
    concern is whether each migration ships safely to production with zero
    downtime. Do NOT comment on style, performance of resulting queries, or
    general security — those have separate reviewers. Stay focused on
    migration safety.

    ## What Was Implemented

    {DESCRIPTION}

    ## Requirements / Plan

    {PLAN_OR_REQUIREMENTS}

    ## Files to Review

    {FILES_TO_REVIEW}

    ## Canonical Safe-Migration Patterns

    Understand these patterns before reviewing — every finding should be
    expressed in terms of how a migration deviates from the correct pattern.

    **Reversibility:**
    Every migration must be reversible. `downgrade()` must be defined and
    correct, OR the migration must include an inline comment `# IRREVERSIBLE:`
    with a justification (e.g., dropping an append-only audit log table where
    data is already archived). A migration with an empty or missing
    `downgrade()` and no `# IRREVERSIBLE:` comment is a Critical finding.

    **Rename column pattern (safe, three-phase):**
    1. Migration A: add `new_col` as nullable; backfill from `old_col`.
    2. Code deploy: switch reads/writes to `new_col`, stop writing `old_col`.
    3. Migration B (separate release): drop `old_col`; tighten `new_col` to
       NOT NULL if required.
    Doing rename + NOT NULL (or rename + drop old + NOT NULL) in a single
    migration is the canonical zero-downtime failure: running code still
    reads the old column name (crash), and existing NULL rows violate the
    constraint.

    **Add NOT NULL column pattern (safe, two-phase):**
    1. Migration A: add column as nullable (no server-side default needed);
       backfill existing rows.
    2. Code deploy: app now writes the column on every insert.
    3. Migration B (separate release): ALTER to NOT NULL.
    Adding NOT NULL to an existing column without a prior backfill migration
    and without a server-side default fails immediately on any row where the
    column is NULL.

    **Drop column pattern (safe, two-phase):**
    1. Code deploy: remove all references to the column from application code.
    2. Migration (separate release): drop the column.
    Dropping a column while existing code still reads or writes it causes
    immediate runtime errors on the running deployment.

    **Index creation on large tables:**
    Must use `CREATE INDEX CONCURRENTLY` (Postgres) to avoid holding a full
    table lock. The Alembic form is:
      `op.create_index(..., postgresql_concurrently=True)`
    and the migration must be transaction-less (either
    `op.execute("COMMIT")` before the index call, or
    `transactional_ddl = False` set on the migration context). A standard
    `CREATE INDEX` on a table with meaningful row count blocks all writes for
    the duration.

    ## Severity Rules

    ### Critical (any of the following — flag every instance)

    - **Combined rename + NOT NULL (or rename + drop old + NOT NULL) in a
      single migration.** Running code reads the old column name (crash) and
      existing NULL rows violate the constraint before any code ships.

    - **Drop column with no prior code-removal deployment.** If the diff
      includes a drop-column migration and there is no preceding migration
      (in a separate prior release) that removes all application references,
      the running deployment crashes the moment the migration runs.

    - **Add NOT NULL on an existing column without a server-side default
      and without a prior backfill migration.** Any row where the column is
      NULL causes the ALTER to fail immediately or leaves the DB in a
      partially migrated state.

    - **Migration not reversible AND missing the `# IRREVERSIBLE:` justification
      comment.** Empty, `pass`, or absent `downgrade()` with no documented
      reason makes rollback impossible.

    - **Standard `CREATE INDEX` (no `postgresql_concurrently=True`) on a table
      with meaningful row count.** Holds an exclusive write lock for the
      duration; blocks all production writes.

    ### Important (any of the following)

    - **Non-resumable bulk UPDATE backfill.** A backfill via
      `op.execute("UPDATE table SET col = val")` with no `WHERE` clause that
      would allow the statement to be safely re-run on a partial failure, and
      no batching. If the migration fails mid-way, re-running it re-processes
      already-updated rows unpredictably.

    - **Foreign key added without `ON DELETE` behavior specified.** Leaves the
      referential action as the DB default (usually RESTRICT or NO ACTION),
      which may not match the intended behavior and causes silent surprises on
      deletes.

    - **Migration touches multiple unrelated tables.** Bundling unrelated
      schema changes makes rollback harder — rolling back the migration undoes
      all changes even if only one table's change is the problem.

    ### Suggestion (any of the following)

    - Migration lacks an inline docstring (the `"""..."""` at the top)
      describing why the schema change is being made, not just what it does.

    - Newly added column is a foreign-key-style or org_id-style column with
      no index. High-cardinality filter columns without indexes cause full
      table scans on every query that filters by that column.

    ## Output Format

    ### Critical (Must Fix)
    [Zero-downtime violations — migration will cause data loss or downtime]

    ### Important (Should Fix)
    [Pattern deviations that create operational risk]

    ### Suggestion
    [Structural improvements]

    For each finding:
    - `file:line` — exact location
    - What's wrong — describe the specific code
    - Why it matters — concrete failure mode in production (what breaks, when,
      for whom)
    - How to fix — the canonical correction with example

    End with exactly one of:

    **Verdict: BLOCKED — N Critical finding(s)**
    **Verdict: APPROVED WITH SUGGESTIONS** (Important and/or Suggestion only)
    **Verdict: APPROVED** (no findings)

    ## Anti-Patterns — What NOT to Do

    **DO:**
    - Read every migration file listed before forming a verdict
    - Evaluate migrations as a sequence, not in isolation — a migration that
      looks safe alone may be unsafe given the prior migration's state
    - Express every finding in terms of the canonical patterns above
    - Give exact `file:line` for every finding
    - Flag Critical for every combined rename+NOT NULL, every unguarded drop,
      every missing `downgrade()` — even when the bug seems "obvious"
    - Describe the concrete production failure mode (what crashes, what data
      is lost, what is locked) not just "this is unsafe"

    **DON'T:**
    - Comment on application code, ORM usage, or DB driver choice — out of
      scope; migrations only
    - Comment on query performance of the resulting schema — separate reviewer
    - Comment on code style or naming conventions
    - Approve a PR without reading every migration file in the list
    - Flag a migration as Critical because it drops a column when a prior
      migration in the same PR already removed all code references and the
      migrations are correctly sequenced across releases
    - Treat the presence of a `downgrade()` as reversibility — verify the
      downgrade actually undoes the upgrade correctly
```

**Placeholders:**
- `{DESCRIPTION}` — brief summary of what schema change is being made
- `{PLAN_OR_REQUIREMENTS}` — what the change should achieve (plan file path, task text, or requirements)
- `{FILES_TO_REVIEW}` — list of Alembic migration files (paths)

**Reviewer returns:** Critical / Important / Suggestion findings, each with file:line + fix, and a Verdict.

## Example Output

```
### Critical (Must Fix)

1. **Combined rename + NOT NULL in a single migration**
   - `alembic/versions/0002_destructive.py:11` — `op.alter_column("users",
     "display_name", new_column_name="full_name", nullable=False)` renames
     the column and enforces NOT NULL in a single operation
   - Why it matters: the running deployment still references `users.display_name`
     by name. The moment this migration runs, every query or INSERT that reads
     or writes `display_name` raises a column-not-found error. Simultaneously,
     existing rows where `display_name` was NULL violate the NOT NULL constraint,
     causing the ALTER itself to fail or leaving partially migrated state.
     The production failure is immediate and affects all users.
   - Fix: split into three phases across two releases —
     Release 1 migration: `op.add_column("users", Column("full_name", String, nullable=True))`
     + `op.execute("UPDATE users SET full_name = display_name WHERE full_name IS NULL")`.
     Code deploy: switch all reads/writes to `full_name`.
     Release 2 migration: `op.drop_column("users", "display_name")`
     + `op.alter_column("users", "full_name", nullable=False)`.

**Verdict: BLOCKED — 1 Critical finding(s)**
```
