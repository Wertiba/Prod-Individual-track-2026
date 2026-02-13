from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select, update

from app.core.exceptions.base import RepositoryError
from app.core.schemas.user import UserUpdateBody
from app.infrastructure.models import User
from app.infrastructure.repositories import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=User)

    async def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email)  # noqa
        try:
            result = await self.session.execute(stmt)
            return result.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def deactivate(self, user_id: UUID) -> None:
        now = datetime.now(timezone.utc)
        stmt = update(User).where(User.id == user_id).values(isActive=False, updatedAt=now)  # noqa
        try:
            await self.session.execute(stmt)
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def update(self, user_id: UUID, new_data: UserUpdateBody) -> User | None:
        now = datetime.now(timezone.utc)
        stmt = update(User).where(User.id == user_id).values(**new_data.model_dump(), updatedAt=now).returning(User)  # noqa
        try:
            result = await self.session.execute(stmt)
            return result.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e
