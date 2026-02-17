from uuid import UUID

from fastapi import APIRouter, status

from app.api.v1.dependencies import AnyViewUserDep, ExperimenterUserDep, ExperimentServiceDep, PaginationDep
from app.core.schemas.experiment import (
    ExperimentCreateBody,
    ExperimentReadResponse,
    ExperimentSetStatusBody,
)
from app.core.utils import Page

router = APIRouter(prefix="/experiments", tags=["Experiments"])


@router.post("", response_model=ExperimentReadResponse, status_code=status.HTTP_201_CREATED)
async def create(user_data: ExperimenterUserDep, experiment_service: ExperimentServiceDep,
                 experiment_data: ExperimentCreateBody) -> ExperimentReadResponse | None:
    return await experiment_service.create(user_data, experiment_data)


@router.get("", response_model=Page[ExperimentReadResponse], status_code=status.HTTP_200_OK)
async def get_all(_: AnyViewUserDep, experiment_service: ExperimentServiceDep,
                  pagination: PaginationDep) -> Page[ExperimentReadResponse]:
    return await experiment_service.get_all_experiments(pagination)


@router.get("/{id}", response_model=ExperimentReadResponse, status_code=status.HTTP_200_OK)
async def get_current(_: AnyViewUserDep, id: UUID,
                      experiment_service: ExperimentServiceDep) -> ExperimentReadResponse | None:
    return await experiment_service.get_by_id(id)


@router.post("/status/review", response_model=ExperimentReadResponse, status_code=status.HTTP_200_OK)
async def to_review(_: ExperimenterUserDep, experiment_service: ExperimentServiceDep,
                    data: ExperimentSetStatusBody) -> ExperimentReadResponse | None:
    return await experiment_service.set_status_review(data.id)
