from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from pydantic import AfterValidator, EmailStr, Field, field_serializer

from app.core.schemas.base import PyModel
from app.core.schemas.enums import Gender, MaritalStatus, UserRole
from app.core.schemas.token import Token
from app.core.utils import check_len_password


class UserCreateBody(PyModel):
    email: Annotated[EmailStr, Field(max_length=254)]
    password: Annotated[str, AfterValidator(check_len_password)]
    fullName: Annotated[str, Field(min_length=2, max_length=200)]


class UserLoginBody(PyModel):
    email: str
    password: str


class UserUpdateBody(PyModel):
    fullName: Annotated[str, Field(min_length=2, max_length=200)]
    role: UserRole | None = None
    isActive: bool | None = None


class UserReadResponse(PyModel):
    id: UUID
    email: EmailStr
    fullName: str
    role: UserRole
    isActive: bool
    createdAt: datetime
    updatedAt: datetime

    # @field_serializer("createdAt", "updatedAt")
    # def serialize_dt(self, dt: datetime, _info) -> str:
    #     utc_dt = dt.astimezone(timezone.utc)
    #     iso_str = utc_dt.isoformat()
    #     if iso_str.endswith("+00:00"):
    #         return iso_str[:-9] + "Z"
    #     return iso_str[:-3] + "Z"


class UserWithTokenResponse(Token):
    user: UserReadResponse


class TokenData(UserReadResponse):
    token_type: str | None
