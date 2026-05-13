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

**Source:** https://example.com/auth-canonical

### 2026-05-11 — Token refresh window observed in staging (since HEAD)

Refresh tokens are honored up to 30 days post-issue in our staging traffic.

**Why:** matches the JWT `exp` + grace period we configured; no canonical doc exists.

**How:** instrument `/auth/refresh` and inspect the `iat` skew.

**Source:** observed_locally_unvetted (sample parenthetical hint)
