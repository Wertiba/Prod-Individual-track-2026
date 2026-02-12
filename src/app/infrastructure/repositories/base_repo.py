from typing import Generic
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.custom_types import T
from app.core.exceptions.repository_exceptions import DuplicateError, RepositoryError


class BaseRepository(Generic[T]):  # noqa
    def __init__(self, session: AsyncSession, model: type[T]) -> None:
        self.session = session
        self.model = model

    async def add(self, obj: T) -> T:
        try:
            self.session.add(obj)
            await self.session.flush()
            await self.session.refresh(obj)
            return obj
        except IntegrityError as e:
            raise DuplicateError("Unique field already exists") from e
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def delete(self, obj: T) -> None:
        try:
            await self.session.delete(obj)
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def get_by_id(self, id_: UUID) -> T | None:
        try:
            stmt = select(self.model).where(self.model.id == id_)  # type: ignore[attr-defined]
            res = await self.session.execute(stmt)
            return res.scalar_one_or_none()
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def get_all(self) -> list[T]:
        try:
            res = await self.session.execute(select(self.model))
            return list(res.scalars().all())
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def get_paginated(self, offset: int, limit: int) -> list[T]:
        try:
            q = select(self.model).offset(offset).limit(limit)
            result = await self.session.execute(q)
            return list(result.scalars().all())
        except SQLAlchemyError as e:
            raise RepositoryError("Database error") from e

    async def count(self) -> int:
        q = select(func.count()).select_from(self.model)
        result = await self.session.execute(q)
        return result.scalar_one()
