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
