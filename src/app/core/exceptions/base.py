class EntityError(Exception):
    pass


class UnprocessableEntityError(EntityError):
    pass


class RepositoryError(Exception):
    pass


class DuplicateError(RepositoryError):
    """Violation of uniqueness"""
    pass

