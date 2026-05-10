from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from .models import Note

router = APIRouter()

@router.get("/notes")
async def list_notes(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    result = await db.execute(select(Note).where(Note.org_id == user.org_id))
    return result.scalars().all()

@router.get("/notes/{note_id}")
async def get_note(note_id: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    note = await db.get(Note, note_id)
    if note is None or note.org_id != user.org_id:
        raise HTTPException(404)
    return note

@router.post("/notes")
async def create_note(payload: dict, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    note = Note(org_id=user.org_id, title=payload["title"], body=payload["body"])
    db.add(note)
    await db.commit()
    return note
