class EntityError(Exception):
    pass


class UserNotFoundError(EntityError):
    pass


class FlagNotFoundError(EntityError):
    pass


class ForbiddenError(EntityError):
    pass


class InvalidPasswordError(EntityError):
    pass


class EmailAlreadyExistsError(EntityError):
    pass


class FlagAlreadyExistsError(EntityError):
    pass


class InvalidCredentialsError(EntityError):
    pass


class RuleAlreadyExistsError(EntityError):
    pass


class UnprocessableEntityError(EntityError):
    pass


class UserNotActiveError(EntityError):
    pass
