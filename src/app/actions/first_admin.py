import asyncio

from passlib.hash import argon2
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlmodel import select

from app.core.config import settings
from app.core.logger import Logger
from app.infrastructure.models.user import User


async def create_admin():
    email = settings.ADMIN_EMAIL
    engine = create_async_engine(settings.POSTGRES_URL, echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    logger = Logger().get_logger()

    async with async_session() as session:
        stmt = select(User).where(User.email == email)  # noqa
        result = await session.execute(stmt)
        admin = result.scalar_one_or_none()

        if admin:
            logger.warning(f"Admin {email} уже существует!")
            return

        new_admin = User(
            email=email,
            password=argon2.hash(settings.ADMIN_PASSWORD),
            full_name=settings.ADMIN_FULLNAME,
            role="ADMIN",
        )
        session.add(new_admin)
        await session.commit()
        await session.refresh(new_admin)  # опционально

        logger.info(f"Admin {email} успешно создан!")


if __name__ == "__main__":
    asyncio.run(create_admin())
