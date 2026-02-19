from sqlalchemy import and_
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select

from app.core.exceptions.base import RepositoryError
from app.infrastructure.models import EventCatalog
from app.infrastructure.repositories import BaseRepository


class EventRepository(BaseRepository[EventCatalog]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=EventCatalog)

    async def get_by_code(self, code: str) -> EventCatalog:
        try:
            stmt = select(EventCatalog).where(and_(EventCatalog.code == code, EventCatalog.inArchive == False))  # noqa
            res = await self.session.execute(stmt)
            return res.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e
