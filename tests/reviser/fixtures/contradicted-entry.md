# Fixture: contradicted entry to revise

A reviser per-call context with one contradicted entry. The reviser fetches the
canonical URL, confirms the contradiction, and rewrites the entry in place.

## ENTRY_PATH

knowledge/patterns/fastapi.md

## ENTRY_TITLE

### 2026-04-12 — Pass shared services via app.state instead of Depends (since a1b2c3d)

## CURRENT_ENTRY_TEXT

```markdown
### 2026-04-12 — Pass shared services via app.state instead of Depends (since a1b2c3d)

Attach shared service singletons to `app.state` and read them from request handlers via
`request.app.state.<name>`. Avoid `Depends(...)` for these — it adds boilerplate and
makes the dependency graph harder to follow.

**Why:** Local observation — `app.state` worked fine on this branch and we didn't
need the override hook in tests.

**Avoid:** `Depends(get_service)` for app-lifetime singletons; reach for `app.state`
directly.

`apps/api/app/routers/orders.py:14`

**Source:** observed_locally_unvetted
```

## CANONICAL_URL

https://fastapi.tiangolo.com/tutorial/dependencies/

## CANONICAL_SUMMARY

FastAPI's official tutorial recommends `Depends(...)` as the canonical way to wire
shared services into route handlers, including app-lifetime singletons. `Depends`
integrates with the override mechanism for testing (`app.dependency_overrides`),
which `app.state` lookups bypass entirely. The tutorial does not recommend
`request.app.state` for service wiring.

## EXPECTED REVISER BEHAVIOR (not asserted by structural test)

1. Invoke `Skill('superpowers:using-project-knowledge')` (Step 0).
2. `WebFetch(CANONICAL_URL)` — confirm the page actually recommends `Depends`
   and the entry is contradicted.
3. Read `ENTRY_PATH`, locate the H3 matching `ENTRY_TITLE` exactly.
4. Rewrite the entry body so the recommendation flips to "prefer `Depends`",
   preserving:
   - The H3 line verbatim (date + title + `(since a1b2c3d)`)
   - The `**Source:**` line, now equal to `**Source:** https://fastapi.tiangolo.com/tutorial/dependencies/`
5. Replace the entry in place. Other entries in the file untouched. `INDEX.md`
   untouched.

Verdict: DONE — entry revised in place at `knowledge/patterns/fastapi.md`
