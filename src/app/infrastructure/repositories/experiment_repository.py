from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions.base import RepositoryError
from app.infrastructure.models import Experiment, Variant
from app.infrastructure.repositories import BaseRepository


class ExperimentRepository(BaseRepository[Experiment]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(session, model=Experiment)

    async def add_variant(self, variant_data: Variant) -> Variant:
        try:
            self.session.add(variant_data)
            await self.session.flush()
            await self.session.refresh(variant_data)
            return variant_data
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e
