from fastapi import APIRouter, status

from app.core.schemas.responses import PingResponse

router = APIRouter(prefix="", tags=["Health"])


@router.get("/ping", response_model=PingResponse, status_code=status.HTTP_200_OK)
async def ping():
    return PingResponse(status="ok")


@router.get("/health", response_model=None, status_code=status.HTTP_200_OK)
async def health():
    return status.HTTP_200_OK


@router.get("/ready", response_model=None, status_code=status.HTTP_200_OK)
async def ready():
    return status.HTTP_200_OK
