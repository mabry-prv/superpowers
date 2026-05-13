---
topic: missing-source
category: gotchas
last-updated: 2026-05-12
last-since: HEAD
---

# Missing source line

## Entries

### 2026-05-12 — This entry has no Source line and should trip Check 4b (since HEAD)

The body deliberately omits the `**Source:**` line so the lint flags it.

**Why:** demonstrating Check 4b's hard-error behavior.

**Avoid:** writing entries without a Source line — pick one of the three
valid forms (URL, observed_locally_unvetted, or observed_locally_unvetted
with parenthetical hint).
