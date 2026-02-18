from datetime import UTC, datetime, timezone
from uuid import UUID

from app.core.exceptions.base import DuplicateError
from app.core.exceptions.flag_exs import (
    FlagAlreadyExistsError,
    FlagNotFoundError,
)
from app.core.schemas.flag import FlagCreateBody, FlagReadResponse, FlagUpdateBody
from app.core.schemas.user import TokenData
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import Flag
from app.infrastructure.unit_of_work import UnitOfWork


class FlagService:
    def __init__(self, uow: UnitOfWork):
        self.uow = uow

    async def create(self, user_data: TokenData, flag_data: FlagCreateBody) -> FlagReadResponse:
        async with self.uow:
            try:
                flag = await self.uow.flag_repo.add(Flag(**flag_data.model_dump(), createdBy=user_data.id))
                return FlagReadResponse(**flag.model_dump())
            except DuplicateError:
                raise FlagAlreadyExistsError from DuplicateError

    async def get_all_flags(self, pagination: PaginationParams) -> Page[FlagReadResponse]:
        async with self.uow:
            flags = await self.uow.flag_repo.get_paginated(offset=pagination.offset, limit=pagination.limit)
            valid = [FlagReadResponse(**u.model_dump()) for u in flags]
            total = await self.uow.flag_repo.count()
            return Page.build(items=valid, total=total, pagination=pagination)

    async def get_by_id(self, flag_id: UUID) -> FlagReadResponse | None:
        async with self.uow:
            flag_exists = await self.uow.flag_repo.get_by_id(flag_id)
            if not flag_exists:
                raise FlagNotFoundError

            return FlagReadResponse(**flag_exists.model_dump())

    async def deactivate(self, flag_id: UUID) -> None:
        async with self.uow:
            if await self.get_by_id(flag_id):
                return await self.uow.flag_repo.deactivate(flag_id, enabled=False, updatedAt=datetime.now(tz=UTC))

    async def update(self, flag_id: UUID, new_data: FlagUpdateBody) -> FlagReadResponse | None:
        current = await self.get_by_id(flag_id)
        async with self.uow:
            if current:
                now = datetime.now(timezone.utc)
                enabled = new_data.enabled if new_data.enabled is not None else current.enabled
                updated = await self.uow.flag_repo.update(
                    flag_id, FlagUpdateBody(**new_data.model_dump(exclude={"enabled", "updatedAt"}),
                                            enabled=enabled, updatedAt=now))
                return FlagReadResponse(**updated.model_dump())
