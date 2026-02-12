from app.api.v1.exceptions.user import (
    Conflict,
    Forbidden,
    Inactive,
    NotFound,
    Unauthorized,
    ValidationFailed,
)
from app.core.exceptions.entity_exceptions import (
    EmailAlreadyExistsError,
    FlagAlreadyExistsError,
    FlagNotFoundError,
    ForbiddenError,
    InvalidCredentialsError,
    InvalidPasswordError,
    RuleAlreadyExistsError,
    UnprocessableEntityError,
    UserNotActiveError,
    UserNotFoundError,
)

DOMAIN_TO_API: dict[type, callable] = {
    UserNotFoundError: lambda path, exc=None: NotFound(
        path=path,
        message="User not found",
    ),
    FlagNotFoundError: lambda path, exc=None: NotFound(
        path=path,
        message="Flag not found",
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
    EmailAlreadyExistsError: lambda path, exc=None: Conflict(
        path=path,
        message="Email already exists",
    ),
    FlagAlreadyExistsError: lambda path, exc=None: Conflict(
        path=path,
        message="Flag already exists",
    ),
    UnprocessableEntityError: lambda path, exc=None: ValidationFailed(
        path=path,
    ),
    UserNotActiveError: lambda path, exc=None: Inactive(
        path=path,
    ),
}
