---
topic: testing
category: gotchas
last-updated: 2026-05-11
last-since: HEAD
---

# Testing gotchas

## Entries

### 2026-05-11 — async fixtures need session_loop (since HEAD)

pytest-asyncio fixtures must declare `loop_scope="session"` when shared.

**Why:** event-loop binding mismatch causes "Future attached to a different loop" flakes.

**How:** add `@pytest_asyncio.fixture(loop_scope="session")` to shared async fixtures.
