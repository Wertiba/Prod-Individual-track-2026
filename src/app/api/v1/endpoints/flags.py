from uuid import UUID

from fastapi import APIRouter, status

from app.api.v1.dependencies import AdminUserDep, FlagServiceDep, PaginationDep
from app.core.schemas.flag import FlagCreateBody, FlagReadResponse, FlagUpdateBody
from app.core.utils import Page
from app.infrastructure.models import Flag

router = APIRouter(prefix="/flags", tags=["Flags"])


@router.get("", response_model=Page[FlagReadResponse], status_code=status.HTTP_200_OK)
async def get_all(_: AdminUserDep, flag_service: FlagServiceDep, pagination: PaginationDep) -> Page[Flag]:
    return await flag_service.get_all_flags(pagination)


@router.post("", response_model=FlagReadResponse, status_code=status.HTTP_201_CREATED)
async def create(_: AdminUserDep, flag_service: FlagServiceDep, user_data: FlagCreateBody) -> Flag | None:
    return await flag_service.create(user_data)


@router.get("/{id}", response_model=FlagReadResponse, status_code=status.HTTP_200_OK)
async def get_current(_: AdminUserDep, id: UUID, flag_service: FlagServiceDep) -> Flag | None:
    return await flag_service.get_by_id(id)


@router.patch("/{id}", response_model=FlagReadResponse, status_code=status.HTTP_200_OK)
async def update_current(
    _: AdminUserDep, id: UUID, flag_service: FlagServiceDep, new_data: FlagUpdateBody
) -> Flag | None:
    return await flag_service.update(id, new_data)


@router.delete("/{id}", response_model=None, status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_current(_: AdminUserDep, id: UUID, flag_service: FlagServiceDep) -> None:
    return await flag_service.deactivate(id)
