from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.models import MetricCatalog
from app.infrastructure.repositories import BaseRepository


class MetricRepository(BaseRepository[MetricCatalog]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=MetricCatalog)
