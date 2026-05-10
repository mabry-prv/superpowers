import logging
from passlib.hash import bcrypt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

async def create_user(db: AsyncSession, email: str, password: str):
    password_hash = bcrypt.hash(password)
    user = User(email=email, password_hash=password_hash)
    db.add(user)
    await db.commit()
    logger.info(f"User created", extra={"user_email": email})

async def login(db: AsyncSession, email: str, password: str):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None or not bcrypt.verify(password, user.password_hash):
        return None
    return user
