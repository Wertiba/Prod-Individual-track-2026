from enum import Enum


class Gender(str, Enum):  # noqa: UP042
    MALE = "MALE"
    FEMALE = "FEMALE"


class MaritalStatus(str, Enum):  # noqa: UP042
    SINGLE = "SINGLE"
    MARRIED = "MARRIED"
    DIVORCED = "DIVORCED"
    WIDOWED = "WIDOWED"


class UserRole(str, Enum):  # noqa: UP042
    USER = "USER"
    ADMIN = "ADMIN"
