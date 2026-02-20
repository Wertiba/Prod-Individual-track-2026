from uuid import UUID

from asyncpg import ForeignKeyViolationError, UniqueViolationError
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import and_, select

from app.core.exceptions.base import DuplicateError, RelationNotFoundError, RepositoryError
from app.core.schemas.experiment import MetricRole
from app.infrastructure.models import Metric, MetricCatalog
from app.infrastructure.models.event import EventMetricLink
from app.infrastructure.repositories import BaseRepository


class MetricRepository(BaseRepository[MetricCatalog]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=MetricCatalog)

    async def get_by_code(self, code: str) -> MetricCatalog:
        try:
            stmt = select(MetricCatalog).where(MetricCatalog.code == code)  # noqa
            res = await self.session.execute(stmt)
            return res.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def get_by_codes(self, codes: list[str]) -> list[MetricCatalog]:
        stmt = select(MetricCatalog).where(MetricCatalog.code.in_(codes))   # noqa
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_guardrails(self, exp_id: UUID, code: str) -> list[Metric]:
        stmt = select(Metric).where(and_(
            Metric.exp_id == exp_id,    # noqa
            Metric.role == MetricRole.GUARDRAIL,    # noqa
            Metric.metricCatalog_code == code    # noqa
        ))
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def assign(self, data: EventMetricLink) -> EventMetricLink:
        try:
            self.session.add(data)
            await self.session.flush()
            await self.session.refresh(data)
            return data

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
