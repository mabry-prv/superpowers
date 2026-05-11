---
topic: dangling-sha
category: gotchas
last-updated: 2026-05-01
last-since: 0000000000000000000000000000000000000000
---

# Dangling SHA gotcha

## Entries

### 2026-05-01 — References a non-existent SHA (since 0000000000000000000000000000000000000000)

The all-zeros SHA cannot exist in any repo — lint should flag it.

**Why:** test fixture.
**How:** ensure lint catches dangling since-SHA.
