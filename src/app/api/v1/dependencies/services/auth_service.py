from typing import TYPE_CHECKING, Annotated

from fastapi import Depends

from app.api.v1.dependencies.session import SessionDep
from app.infrastructure.unit_of_work import UnitOfWork

if TYPE_CHECKING:
    from app.services.auth_service import AuthService


def get_auth_service(session: SessionDep) -> "AuthService":
    from app.services.auth_service import AuthService
    from app.services.jwt_service import JWTService

    uow = UnitOfWork(session)
    jwt_service = JWTService()
    return AuthService(uow, jwt_service)


AuthServiceDep = Annotated["AuthService", Depends(get_auth_service)]
