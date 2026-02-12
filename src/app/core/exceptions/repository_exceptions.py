class RepositoryError(Exception):
    pass


class DuplicateError(RepositoryError):
    """Violation of uniqueness"""
