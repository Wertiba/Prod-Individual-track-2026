from datetime import datetime
from enum import Enum
from typing import Annotated, Self
from uuid import UUID

from pydantic import Field, model_validator

from app.core.schemas.base import DatetimeResponse, PyModel


class ExperimentStatus(str, Enum):
    DRAFT = "DRAFT"
    IN_REVIEW = "IN_REVIEW"
    APPROVED = "APPROVED"
    RUNNING = "RUNNING"
    PAUSED = "PAUSED"
    COMPLETED = "COMPLETED"
    ARCHIVED = "ARCHIVED"
    REJECTED = "REJECTED"


class VariantCreateBody(PyModel):
    name: Annotated[str, Field(max_length=255)]
    value: Annotated[str, Field(max_length=255)]
    weight: Annotated[int, Field(ge=0)]
    isControl: Annotated[bool, Field(default=False)]


class VariantData(VariantCreateBody):
    experiment_id: UUID


class ValidateVariants(PyModel):
    part: Annotated[int, Field(le=100, ge=0)]
    variants: list[VariantCreateBody]

    @model_validator(mode="after")
    def validate_weights(self) -> Self:
        if not self.variants:
            raise ValueError("The list of options cannot be empty")

        total_weight = sum(v.weight for v in self.variants)
        if total_weight != self.part:
            raise ValueError(
                f"Sum of the weights of the variants ({total_weight}) "
                f"should be equal part ({self.part})"
            )

        control_variants = [v for v in self.variants if v.isControl]
        if len(control_variants) != 1:
            raise ValueError("There must be exactly one control variant (isControl=True)")

        return self


class ExperimentUpdateBody(ValidateVariants):
    name: Annotated[str, Field(max_length=255)]
    target: Annotated[str | None, Field(max_length=255)] = None
    description: Annotated[str | None, Field(max_length=500)] = None
    version: Annotated[float, Field(ge=0)]
    part: Annotated[int, Field(ge=0, le=100)]
    variants: list[VariantCreateBody]


class ExperimentUpdate(PyModel):
    isCurrent: bool | None = None


class ExperimentCreateData(ExperimentUpdateBody):
    code: Annotated[str, Field(max_length=100)]
    flag_code: Annotated[str, Field(max_length=255)]
    version: Annotated[float | None, Field(ge=0)] = None


class ExperimentCreateBody(ExperimentCreateData, ValidateVariants):
    pass


class ExperimentSetStatusBody(PyModel):
    code: Annotated[str, Field(max_length=100)]


class ExperimentData(ExperimentCreateData, ExperimentSetStatusBody):
    id: UUID
    status: ExperimentStatus
    version: float
    isCurrent: bool
    createdBy: UUID
    createdAt: datetime
    variants: list[VariantData]


class ExperimentReadResponse(ExperimentData, DatetimeResponse):
    pass


class ExperimentHistoryResponse(DatetimeResponse):
    versions: list[ExperimentData]
