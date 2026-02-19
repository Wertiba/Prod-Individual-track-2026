from fastapi import APIRouter, status

from app.api.v1.dependencies import AnyViewUserDep, MetricServiceDep

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/{code}", response_model=None, status_code=status.HTTP_200_OK)
async def get_metrics(_: AnyViewUserDep, code: str, metric_service: MetricServiceDep) -> None:
    return await metric_service.get_values(code)
