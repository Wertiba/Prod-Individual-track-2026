from uuid import UUID

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import and_, select

from app.core.exceptions.base import RepositoryError
from app.core.schemas.experiment import MetricRole
from app.infrastructure.models import Metric, MetricCatalog
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
