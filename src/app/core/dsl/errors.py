from dataclasses import dataclass


@dataclass
class ValidationError:
    code: str
    message: str
    position: int | None = None
    near: str | None = None

    def to_dict(self):
        result = {"code": self.code, "message": self.message}
        if self.position is not None:
            result["position"] = str(self.position)
        if self.near is not None:
            result["near"] = self.near
        return result


@dataclass
class ValidationResult:
    is_valid: bool
    normalized_expression: str | None = None
    errors: list[ValidationError] = None

    def __post_init__(self):
        if self.errors is None:
            self.errors = []

    def to_dict(self):
        return {
            "isValid": self.is_valid,
            "normalizedExpression": self.normalized_expression,
            "errors": [e.to_dict() for e in self.errors],
        }
