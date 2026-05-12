# Fixture: sample curator input — multi-tenant isolation bug fix

## TASK_DESCRIPTION

Fixed an IDOR vulnerability where the `/orders/:id` endpoint fetched orders by PK without verifying `org_id == user.org_id`, allowing any authenticated user to read any tenant's order by guessing IDs.

## PLAN_OR_SPEC

docs/superpowers/specs/2026-04-12-fix-orders-idor.md

## BASE_SHA / HEAD_SHA

BASE_SHA: 3a1b2c4
HEAD_SHA: 8d2e0a1

## IMPLEMENTER_REPORT

Status: DONE
- Added explicit org-id check after `db.get(Order, id)` at `apps/api/app/routers/orders.py:34`
- Added integration test asserting cross-tenant fetch returns 404
- All tests pass

## REVIEWER_REPORTS

reviewer-spec: APPROVED — endpoint behavior matches spec
reviewer-multitenant-isolation: APPROVED WITH SUGGESTIONS — suggestion to add a runtime assertion in a future helper

## EXISTING_INDEX

```
# Knowledge Index

## Patterns

(none yet)

## Gotchas

(none yet)
```

## EXPECTED CURATOR BEHAVIOR (not asserted by structural test)

Two entries:

1. **patterns/multitenancy.md** (new topic) — "Always verify org_id post-fetch on PK lookups" with `since: 8d2e0a1`
2. **gotchas/orm.md** (new topic) — "db.get() bypasses the org-scoped session factory's auto-filter" with `since: 8d2e0a1`

INDEX.md gains two bullets.

Verdict: DONE — 2 entries across 2 topic files
