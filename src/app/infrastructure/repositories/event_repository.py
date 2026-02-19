from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlmodel import select

from app.core.exceptions.base import RepositoryError
from app.infrastructure.models import EventCatalog
from app.infrastructure.repositories import BaseRepository


class EventRepository(BaseRepository[EventCatalog]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=EventCatalog)

    async def get_by_code(self, code: str) -> EventCatalog:
        try:
            stmt = select(EventCatalog).where(EventCatalog.code == code)  # noqa
            res = await self.session.execute(stmt)
            return res.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def get_by_code_with_metrics(self, code: str) -> EventCatalog | None:
        stmt = (
            select(EventCatalog)
            .where(EventCatalog.code == code)   # noqa
            .options(selectinload(EventCatalog.metrics))    # noqa
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
