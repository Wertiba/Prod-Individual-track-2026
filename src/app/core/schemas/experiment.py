from datetime import datetime
from enum import Enum
from typing import Annotated, Self
from uuid import UUID

from pydantic import Field, model_validator

from app.core.schemas.base import PyModel


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
    weight: int
    isControl: Annotated[bool, Field(default=False)]


class VariantData(VariantCreateBody):
    experiment_code: str
    updatedAt: datetime


class ExperimentUpdateBody(PyModel):
    code: Annotated[str, Field(max_length=255)]
    name: Annotated[str, Field(max_length=255)]
    target: Annotated[str | None, Field(max_length=255)] = None
    description: Annotated[str | None, Field(max_length=500)] = None


class ExperimentCreateData(ExperimentUpdateBody):
    flag_code: Annotated[str, Field(max_length=255)]
    part: Annotated[int, Field(le=100)]
    variants: list[VariantCreateBody]


class ExperimentCreateBody(ExperimentCreateData):
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
            raise ValueError("There must be exactly one control variant. (isControl=True)")
        return self


class ExperimentSetStatusBody(PyModel):
    id: UUID


class ExperimentData(ExperimentCreateData, ExperimentSetStatusBody):
    status: ExperimentStatus
    version: float
    isCurrent: bool
    createdBy: UUID
    createdAt: datetime
    variants: list[VariantData]


class ExperimentReadResponse(ExperimentData):
    pass
