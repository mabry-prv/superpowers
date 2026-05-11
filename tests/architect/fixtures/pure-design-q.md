# Fixture: pure design question — column vs JSON

## QUESTION

We're adding a `metadata` field to the `Order` model that holds 5-10 user-supplied key/value pairs. Should it be a `JSONB` column on `orders`, or a separate `OrderMetadata` table with `(order_id, key, value)` rows?

## CODE_CONTEXT

```python
# apps/api/app/models/order.py
class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True)
    org_id: Mapped[int] = mapped_column(ForeignKey("orgs.id"), nullable=False)
    total_cents: Mapped[int] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
```

## CONSTRAINTS

- Postgres 15+
- We rarely query metadata (read-mostly during order display, never indexed)
- We never aggregate across orders' metadata
- Schema is in Alembic — adding a JSONB column is a single migration; adding a table is two migrations (add table, then start writing)

## PRIOR_ATTEMPTS

None — this is greenfield.

## DECISION_OWNER

implementer for Task 3
