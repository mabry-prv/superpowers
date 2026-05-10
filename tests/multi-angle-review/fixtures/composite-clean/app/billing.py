import stripe
from fastapi import APIRouter, Request, HTTPException, Depends
from sqlalchemy import select
from .config import settings
from .models import StripeEventSeen

router = APIRouter()

@router.post("/webhooks/stripe")
async def stripe_webhook(request: Request, db=Depends(get_db)):
    payload = await request.body()
    sig = request.headers.get("stripe-signature")
    try:
        event = stripe.Webhook.construct_event(payload, sig, settings.STRIPE_WEBHOOK_SECRET)
    except (ValueError, stripe.error.SignatureVerificationError):
        raise HTTPException(400, "invalid signature")

    seen = await db.get(StripeEventSeen, event.id)
    if seen is not None:
        return {"ok": True, "deduped": True}

    db.add(StripeEventSeen(id=event.id))

    if event.type == "invoice.paid":
        org_id = event.data.object.metadata.get("org_id")
        await mark_org_paid(db, org_id)

    await db.commit()
    return {"ok": True}
