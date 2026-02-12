from uuid import UUID

from app.core.config import settings
from app.core.exceptions.entity_exceptions import (
    EmailAlreadyExistsError,
    ForbiddenError,
    UserNotFoundError,
)
from app.core.exceptions.repository_exceptions import DuplicateError
from app.core.schemas.enums import UserRole
from app.core.schemas.user import TokenData, UserCreateBody, UserReadResponse, UserUpdateBody
from app.core.utils.paginated import Page, PaginationParams
from app.infrastructure.models import User
from app.infrastructure.unit_of_work import UnitOfWork
from app.services.jwt_service import JWTService


class UserService:
    USER_BY_LOGIN_TTL = settings.cache.entity_cache.ttl.USER_BY_LOGIN
    ALL_USERS_ENDPOINT_NAMESPACE = settings.cache.response_cache.namespace.ALL_USERS
    ALL_USERS_ENDPOINT_TTL = settings.cache.response_cache.ttl.ALL_USERS

    def __init__(self, uow: UnitOfWork, jwt_service: JWTService):
        self.uow = uow
        self.jwt_service = jwt_service

    async def register(self, user_data: UserCreateBody) -> UserReadResponse:
        async with self.uow:
            user_data.password = self.jwt_service.get_password_hash(user_data.password)
            try:
                user = await self.uow.user_repo.add(User(**user_data.model_dump()))
                return UserReadResponse(**user.model_dump())
            except DuplicateError:
                raise EmailAlreadyExistsError from DuplicateError

    async def get_all_users(self, pagination: PaginationParams) -> Page[UserReadResponse]:
        async with self.uow:
            users = await self.uow.user_repo.get_paginated(offset=pagination.offset, limit=pagination.limit)
            valid = [UserReadResponse(**u.model_dump()) for u in users]
            total = await self.uow.user_repo.count()
            return Page.build(items=valid, total=total, pagination=pagination)

    async def get_by_id(self, user_id: UUID) -> UserReadResponse | None:
        async with self.uow:
            user_exists = await self.uow.user_repo.get_by_id(user_id)
            if not user_exists:
                raise UserNotFoundError

            return UserReadResponse(**user_exists.model_dump())

    async def get_current_by_id(self, user_data: TokenData, user_id: UUID) -> UserReadResponse | None:
        user = await self.get_by_id(user_id)
        if user_data.role != "ADMIN":
            if user_data.id != user_id:
                raise ForbiddenError
        return user

    async def deactivate(self, user_id: UUID) -> None:
        async with self.uow:
            if await self.get_by_id(user_id):
                return await self.uow.user_repo.deactivate(user_id)
            raise UserNotFoundError

    async def update(self, user_id: UUID, user_role: UserRole, new_data: UserUpdateBody) -> UserReadResponse | None:
        async with self.uow:
            user = await self.uow.user_repo.get_by_id(user_id)
            if not user:
                raise UserNotFoundError

            if user_role != UserRole.ADMIN:
                if new_data.role is not None or new_data.isActive is not None:
                    raise ForbiddenError

                role = user.role
                active = user.isActive

            else:
                role = user.role if new_data.role is None else new_data.role
                active = user.isActive if new_data.isActive is None else new_data.isActive

            updated = await self.uow.user_repo.update(
                user_id,
                UserUpdateBody(
                    fullName=new_data.fullName,
                    role=role,
                    isActive=active,
                ),
            )

            return UserReadResponse(**updated.model_dump())

    async def update_me(self, user_data: TokenData, new_data: UserUpdateBody) -> UserReadResponse | None:
        return await self.update(user_data.id, user_data.role, new_data)

    async def update_current(
        self, user_id: UUID, user_data: TokenData, new_data: UserUpdateBody
    ) -> UserReadResponse | None:
        if user_data.role != "ADMIN" and user_id != user_data.id:
            raise ForbiddenError
        if not await self.get_by_id(user_id):
            raise UserNotFoundError
        return await self.update(user_id, user_data.role, new_data)
