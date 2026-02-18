from app.api.v1.exceptions.api_exs import (
    Conflict,
    Forbidden,
    Inactive,
    NotFound,
    Unauthorized,
    ValidationFailed,
)
from app.core.exceptions.base import UnprocessableEntityError
from app.core.exceptions.experiment_exs import ExperimentAlreadyExistsError, ExperimentNotFoundError
from app.core.exceptions.flag_exs import FlagAlreadyExistsError, FlagNotFoundError
from app.core.exceptions.matric_exs import MetricAlreadyExistsError, MetricNotFoundError
from app.core.exceptions.user_exs import (
    ForbiddenError,
    InvalidCredentialsError,
    InvalidFallbackDataError,
    InvalidPasswordError,
    UserAlreadyExistsError,
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
    MetricNotFoundError: lambda path, exc=None: NotFound(
        path=path,
        message="Metric not found",
    ),
    ExperimentNotFoundError: lambda path, exc=None: NotFound(
        path=path,
        message="Experiment not found",
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
    UserAlreadyExistsError: lambda path, exc=None: Conflict(
        path=path,
        message="User already exists",
    ),
    FlagAlreadyExistsError: lambda path, exc=None: Conflict(
        path=path,
        message="Flag already exists",
    ),
    MetricAlreadyExistsError: lambda path, exc=None: Conflict(
        path=path,
        message="Metric already exists",
    ),
    ExperimentAlreadyExistsError: lambda path, exc=None: Conflict(
        path=path,
        message="Experiment already exists",
    ),
    UnprocessableEntityError: lambda path, exc=None: ValidationFailed(
        path=path,
    ),
    InvalidFallbackDataError: lambda path, exc=None: ValidationFailed(
        path=path,
    ),
    UserNotActiveError: lambda path, exc=None: Inactive(
        path=path,
    ),
}
