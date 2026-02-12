from enum import Enum


class UserRole(str, Enum):  # noqa: UP042
    VIEWER = "VIEWER"
    APPROVER = "APPROVER"
    EXPERIMENTER = "EXPERIMENTER"
    ADMIN = "ADMIN"


class FlagType(str, Enum):  # noqa: UP042
    STRING = "STRING"
    BOOL = "BOOL"
    NUMBER = "NUMBER"
