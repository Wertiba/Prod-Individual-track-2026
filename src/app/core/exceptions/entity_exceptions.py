class EntityError(Exception):
    pass


class UserNotFoundForTransactionError(EntityError):
    def __init__(self, user_id: str):
        self.user_id = user_id
        super().__init__(f"User {user_id} not found")


class UserNotFoundError(EntityError):
    pass


class ForbiddenError(EntityError):
    pass


class InvalidPasswordError(EntityError):
    pass


class EmailAlreadyExistsError(EntityError):
    pass


class InvalidCredentialsError(EntityError):
    pass


class RuleAlreadyExistsError(EntityError):
    pass


class UnprocessableEntityError(EntityError):
    pass


class UserNotActiveError(EntityError):
    pass
