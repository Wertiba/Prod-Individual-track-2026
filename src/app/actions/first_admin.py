import asyncio

from passlib.hash import argon2
from sqlmodel import select

from app.core.config import settings
from app.core.logger import Logger
from app.infrastructure.database.db_helper import db_helper
from app.infrastructure.models.user import User


async def create_admin():
    email = settings.ADMIN_EMAIL
    logger = Logger().get_logger()

    async with db_helper.session_factory() as session:
        stmt = select(User).where(User.email == email)  # noqa
        result = await session.execute(stmt)
        admin = result.scalar_one_or_none()

        if admin:
            logger.warning(f"User {email} already exists!")
            return

        new_admin = User(
            email=email,
            password=argon2.hash(settings.ADMIN_PASSWORD),
            fullName=settings.ADMIN_FULLNAME,
            role="ADMIN",
        )
        session.add(new_admin)
        await session.commit()
        await session.refresh(new_admin)  # опционально

        logger.info(f"Admin {email} successfully created!")


if __name__ == "__main__":
    asyncio.run(create_admin())
