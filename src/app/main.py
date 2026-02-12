from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend

from app.api import v1_router
from app.api.v1.exceptions.handlers import register_exception_handlers
from app.core.config import settings
from app.core.logger import Logger
from app.infrastructure.cache.redis_client import redis_client


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:  # noqa: RUF029
    FastAPICache.init(RedisBackend(redis_client), prefix=settings.cache.response_cache.PREFIX)
    yield


logger = Logger()
app = FastAPI(lifespan=lifespan)
register_exception_handlers(app)

origins = [
    "http://localhost",
    "http://localhost:8080",
]

app.add_middleware(
    CORSMiddleware,  # noqa
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(v1_router, prefix="/api")
