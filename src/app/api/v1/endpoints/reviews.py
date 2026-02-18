from uuid import UUID

from fastapi import APIRouter, status

from app.api.v1.dependencies import AdminUserDep, AnyViewUserDep, ReviewServiceDep
from app.core.schemas.review import ReviewCreateBody, ReviewDataResponse

router = APIRouter(prefix="/reviews", tags=["Reviews"])


@router.post("", response_model=ReviewDataResponse, status_code=status.HTTP_201_CREATED)
async def create(user_data: AdminUserDep, review_service: ReviewServiceDep,
                 review_data: ReviewCreateBody) -> ReviewDataResponse | None:
    return await review_service.create(user_data, review_data)


@router.get("/{id}", response_model=ReviewDataResponse, status_code=status.HTTP_200_OK)
async def get_current(_: AnyViewUserDep, id: UUID, review_service: ReviewServiceDep) -> ReviewDataResponse | None:
    return await review_service.get_by_id(id)
