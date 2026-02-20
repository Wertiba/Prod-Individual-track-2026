from asyncpg.exceptions import ForeignKeyViolationError, UniqueViolationError
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import and_, select

from app.core.exceptions.base import DuplicateError, RelationNotFoundError, RepositoryError
from app.infrastructure.models import Event, EventCatalog
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

    async def assign_event(self, event: Event) -> Event:
        try:
            self.session.add(event)
            await self.session.flush()
            await self.session.refresh(event)
            return event
        except IntegrityError as e:
            orig = e.orig
            pgcode = getattr(orig, 'pgcode', None)

            if pgcode == ForeignKeyViolationError.sqlstate:
                raise RelationNotFoundError("Referenced entity does not exist") from e
            elif pgcode == UniqueViolationError.sqlstate:
                raise DuplicateError("Unique field already exists") from e
            raise
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e
