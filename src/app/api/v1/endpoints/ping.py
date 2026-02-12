from fastapi import APIRouter, status

from app.core.schemas.responses import PingResponse

router = APIRouter(prefix="/ping", tags=["Auth"])


@router.get("", response_model=PingResponse, status_code=status.HTTP_200_OK, tags=["Auth"])
async def ping():
    return PingResponse(status="ok")
