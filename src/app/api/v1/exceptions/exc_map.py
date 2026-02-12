from app.api.v1.exceptions import Forbidden, Inactive, NotFound, Unauthorized, ValidationFailed
from app.api.v1.exceptions.user import EmailConflict, NotFoundForTransaction, RuleConflict
from app.core.exceptions.entity_exceptions import (
    EmailAlreadyExistsError,
    ForbiddenError,
    InvalidCredentialsError,
    InvalidPasswordError,
    RuleAlreadyExistsError,
    UnprocessableEntityError,
    UserNotActiveError,
    UserNotFoundError,
    UserNotFoundForTransactionError,
)

DOMAIN_TO_API: dict[type, callable] = {
    UserNotFoundError: lambda path, exc=None: NotFound(
        path=path,
        message="Пользователь не найден",
    ),
    UserNotFoundForTransactionError: lambda path, exc=None: NotFoundForTransaction(
        path=path, details={"userId": getattr(exc, "user_id", None)}
    ),
    ForbiddenError: lambda path, exc=None: Forbidden(
        path=path,
    ),
    InvalidCredentialsError: lambda path, exc=None: Unauthorized(
        path=path,
    ),
    InvalidPasswordError: lambda path, exc=None: Unauthorized(
        path=path,
    ),
    EmailAlreadyExistsError: lambda path, exc=None: EmailConflict(
        path=path,
    ),
    RuleAlreadyExistsError: lambda path, exc=None: RuleConflict(
        path=path,
    ),
    UnprocessableEntityError: lambda path, exc=None: ValidationFailed(
        path=path,
    ),
    UserNotActiveError: lambda path, exc=None: Inactive(
        path=path,
    ),
}
