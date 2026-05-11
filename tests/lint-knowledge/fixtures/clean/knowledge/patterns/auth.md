---
topic: auth
category: patterns
last-updated: 2026-05-11
last-since: HEAD
---

# Auth patterns

## Entries

### 2026-05-11 — Org-scoped session factory (since HEAD)

Use `Depends(get_org_db)` for org-scoped queries. Never raw `get_db`.

**Why:** the auto-filter lives in the factory; bypassing leaks rows across tenants.

**How:** `app/deps.py:14` defines the factory; every org-scoped router imports it.
