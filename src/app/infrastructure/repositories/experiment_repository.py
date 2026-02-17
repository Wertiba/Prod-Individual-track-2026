from uuid import UUID

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlmodel import select

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

    async def get_by_id_with_variants(self, experiment_id: UUID) -> Experiment | None:
        try:
            result = await self.session.execute(
                select(Experiment)
                .options(selectinload(Experiment.variants)) # noqa
                .where(Experiment.id == experiment_id)  # noqa
            )
            return result.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def get_paginated_with_variants(self, offset: int, limit: int) -> list[Experiment]:
        try:
            result = await self.session.execute(
                select(Experiment)
                .options(selectinload(Experiment.variants)) # noqa
                .offset(offset)
                .limit(limit)
            )
            return list(result.scalars().all())
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e
