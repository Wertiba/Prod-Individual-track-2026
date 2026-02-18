from datetime import datetime
from enum import Enum
from typing import Annotated
from uuid import UUID

from pydantic import AfterValidator, EmailStr, Field

from app.core.schemas.base import DatetimeResponse, PyModel
from app.core.schemas.role import RoleCode, RoleRead
from app.core.schemas.token import Token
from app.core.utils import check_len_password


class NoFallbackStrategy(str, Enum):
    ANY = "ANY"
    ZERO = "ZERO"


class UserUpdateBody(PyModel):
    fullName: Annotated[str, Field(min_length=2, max_length=200)]
    roles: list[RoleCode] | None = None
    isActive: bool | None = None

    required: Annotated[int | None, Field(ge=0)] = None
    useFallback: bool | None = None
    strategy: Annotated[NoFallbackStrategy | None, Field(max_length=255)] = None


class UserCreateBody(UserUpdateBody):
    email: Annotated[EmailStr, Field(max_length=254)]
    password: Annotated[str, AfterValidator(check_len_password)]
    isActive: bool = True


class UserLoginBody(PyModel):
    email: str
    password: str


class UserData(PyModel):
    id: UUID
    email: EmailStr
    fullName: str
    roles: list[RoleCode] | None
    isActive: bool

    required: int | None
    useFallback: bool | None
    strategy: NoFallbackStrategy | None

    createdAt: datetime
    updatedAt: datetime


class UserReadResponse(UserData, DatetimeResponse):
    roles: list[RoleRead] | None


class UserWithTokenResponse(Token, DatetimeResponse):
    user: UserReadResponse


class TokenData(UserData):
    token_type: str | None


class ApproverAssignBody(PyModel):
    experimenter_id: UUID
    approver_id: UUID


class ApproverReadResponse(ApproverAssignBody, DatetimeResponse):
    id: UUID
    isActive: bool
    addedAt: datetime
    addedBy: UUID
