from datetime import datetime
from uuid import UUID

from app.core.schemas.base import PyModel
from app.core.schemas.enums import FlagType


class FlagCreateBody(PyModel):
    key: str
    default: str
    type: FlagType


class FlagReadResponse(FlagCreateBody):
    id: UUID
    enabled: bool
    createdAt: datetime


class FlagUpdateBody(PyModel):
    default: str
    enabled: bool | None = None
