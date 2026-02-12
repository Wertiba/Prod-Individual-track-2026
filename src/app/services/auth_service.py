from typing import TYPE_CHECKING
from uuid import UUID

from app.core.exceptions.entity_exceptions import (
    InvalidCredentialsError,
    InvalidPasswordError,
    UserNotActiveError,
    UserNotFoundError,
)
from app.core.schemas.token import Token
from app.core.schemas.user import TokenData, UserLoginBody, UserWithTokenResponse
from app.infrastructure.models import User
from app.infrastructure.unit_of_work import UnitOfWork

if TYPE_CHECKING:
    from app.services import JWTService


class AuthService:
    def __init__(self, uow: UnitOfWork, jwt_service: "JWTService"):
        self.uow = uow
        self.jwt_service = jwt_service

    def create_tokens_for_user(self, user: User) -> Token:
        data = {"sub": str(user.id)}
        access_token = self.jwt_service.create_access_token(data=data)
        return Token(accessToken=access_token)

    async def verify_token(self, token: str) -> TokenData:
        async with self.uow:
            payload = self.jwt_service.decode_token(token)
            user_id = UUID(payload["sub"])
            user = await self.uow.user_repo.get_by_id(user_id)
            if not user:
                raise InvalidCredentialsError
            return TokenData(
                **user.model_dump(),
                token_type=payload.get("token_type"),
            )

    async def authenticate_user(self, email: str, password: str) -> User:
        async with self.uow:
            user = await self.uow.user_repo.get_by_email(email)
            if user is None:
                raise UserNotFoundError
            if not self.jwt_service.verify_password(password, str(user.password)):
                raise InvalidPasswordError
            if not user.isActive:
                raise UserNotActiveError
            return user

    async def login_user(self, login_body: UserLoginBody) -> UserWithTokenResponse:
        user = await self.authenticate_user(login_body.email, login_body.password)
        tokens = self.create_tokens_for_user(user)
        return UserWithTokenResponse(
            accessToken=tokens.accessToken,
            expiresIn=tokens.expiresIn,
            user=user,
        )
