from app.core.exceptions.base import EntityError


class ExperimentNotFoundError(EntityError):
    pass


class ExperimentAlreadyExistsError(EntityError):
    pass


class ExperimentInvalidStatusError(EntityError):
    pass
