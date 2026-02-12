import json
from collections.abc import Awaitable, Callable
from typing import Any

from redis.asyncio import Redis
from sqlmodel import SQLModel

from app.core.custom_types import T


class CacheService:
    def __init__(self, redis: Redis):
        self._redis = redis

    async def get_model(self, key: str, model: type[T]) -> T | None:
        data = await self.get(key)
        if data is None:
            return None
        return model.model_validate(data)

    async def set_model(self, key: str, value: SQLModel, ttl: int):
        await self.set(key, value.model_dump(mode="json"), ttl)

    async def get(self, key: str) -> Any | None:
        value = await self._redis.get(key)
        return json.loads(value) if value else None

    async def set(self, key: str, value: Any, ttl: int = 60):
        await self._redis.set(key, json.dumps(value), ex=ttl)

    async def delete(self, *keys: str):
        if keys:
            await self._redis.delete(*keys)

    async def delete_pattern(self, pattern: str):
        keys = await self._redis.keys(pattern)
        if keys:
            await self._redis.delete(*keys)

    async def aside(
        self,
        key: str,
        ttl: int,
        loader: Callable[[], Awaitable[T]],
        model: type[T] | None = None,
    ) -> T:
        cached = await self.get(key)
        if cached is not None:
            return model.model_validate(cached) if model else cached

        value = await loader()
        if value is not None:  # Not caching None values
            if model:
                await self.set_model(key, value, ttl)
            else:
                await self.set(key, value, ttl)
        return value
