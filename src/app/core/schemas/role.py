from enum import Enum
from typing import Annotated
from uuid import UUID

from pydantic import Field

from app.core.schemas.base import PyModel


class RoleCode(str, Enum):
    VIEW = "VIEW"
    APPR = "APPR"
    EXPR = "EXPR"
    ADMN = "ADMN"


class RoleCreate(PyModel):
    code: RoleCode
    value: Annotated[str, Field(min_length=2, max_length=50)]
    description: str | None = None


class RoleRead(PyModel):
    id: UUID
    code: RoleCode
    value: str
    description: str | None = None
