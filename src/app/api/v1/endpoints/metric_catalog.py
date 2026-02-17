from uuid import UUID

from fastapi import APIRouter, status

from app.api.v1.dependencies import AdminUserDep, AnyViewUserDep, MetricServiceDep, PaginationDep
from app.core.schemas.metric import MetricCreateBody, MetricCreateResponse
from app.core.utils import Page

router = APIRouter(prefix="/metric-catalog", tags=["Metric Catalog"])


@router.post("", response_model=MetricCreateResponse, status_code=status.HTTP_201_CREATED)
async def create(user_data: AdminUserDep, metric_service: MetricServiceDep,
                 metric_data: MetricCreateBody) -> MetricCreateResponse | None:
    return await metric_service.create(user_data, metric_data)


@router.get("", response_model=Page[MetricCreateResponse], status_code=status.HTTP_200_OK)
async def get_all(_: AnyViewUserDep, metric_service: MetricServiceDep,
                  pagination: PaginationDep) -> Page[MetricCreateResponse]:
    return await metric_service.get_all_catalog_metrics(pagination)


@router.get("/{id}", response_model=MetricCreateResponse, status_code=status.HTTP_200_OK)
async def get_current(_: AnyViewUserDep, id: UUID, metric_service: MetricServiceDep) -> MetricCreateResponse | None:
    return await metric_service.get_by_id(id)
