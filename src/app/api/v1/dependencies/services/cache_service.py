from typing import Annotated

from fastapi import Depends

from app.infrastructure.cache.redis_client import redis_client
from app.services.cache_service import CacheService


def get_cache_service() -> CacheService:
    return CacheService(redis_client)


CacheServiceDep = Annotated[CacheService, Depends(get_cache_service)]
