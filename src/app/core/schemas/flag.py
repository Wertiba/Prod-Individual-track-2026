from datetime import datetime
from enum import Enum
from uuid import UUID

from app.core.schemas.base import PyModel


class FlagType(str, Enum):
    STRING = "STRING"
    BOOL = "BOOL"
    NUMBER = "NUMBER"


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
