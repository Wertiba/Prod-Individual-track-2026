from fastapi import status

from app.api.v1.exceptions.base import APIException


class Unauthorized(APIException):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "UNAUTHORIZED"
    message = "Токен отсутствует или невалиден"


class Forbidden(APIException):
    status_code = status.HTTP_403_FORBIDDEN
    code = "FORBIDDEN"
    message = "Недостаточно прав для выполнения операции"


class NotFound(APIException):
    status_code = status.HTTP_404_NOT_FOUND
    code = "NOT_FOUND"
    message = "Ресурс не найден"


class NotFoundForTransaction(NotFound):
    details = ""


class Conflict(APIException):
    status_code = status.HTTP_409_CONFLICT
    code = "CONFLICT"
    message = "Конфликт данных"


class EmailConflict(Conflict):
    code = "EMAIL_ALREADY_EXISTS"


class RuleConflict(Conflict):
    code = "RULE_NAME_ALREADY_EXISTS"


class BadRequest(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    code = "BAD_REQUEST"
    message = "Неверный запрос"


class ValidationFailed(APIException):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    code = "VALIDATION_FAILED"
    message = "Некоторые поля не прошли валидацию"


class Inactive(APIException):
    status_code = status.HTTP_423_LOCKED
    code = "USER_INACTIVE"
    message = "Пользователь деактивирован"
