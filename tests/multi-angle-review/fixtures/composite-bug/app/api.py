from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from .models import Note

# Imagine `get_db` and `get_current_user` are defined elsewhere.
# Current user has user.org_id

router = APIRouter()

@router.get("/notes")
async def list_notes(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    # BUG #1: missing org_id filter — returns notes from EVERY org.
    result = await db.execute(select(Note))
    return result.scalars().all()

@router.get("/notes/{note_id}")
async def get_note(note_id: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    # BUG #2: org_id filter present but no user.org_id check — IDOR risk
    note = await db.get(Note, note_id)
    return note

@router.post("/notes")
async def create_note(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    # BUG #3: takes org_id from request body instead of session
    note = Note(org_id=payload["org_id"], title=payload["title"], body=payload["body"])
    db.add(note)
    await db.commit()
    return note
