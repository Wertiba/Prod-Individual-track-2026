from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import Field

from app.core.schemas.base import PyModel


class MetricCreateBody(PyModel):
    code: Annotated[str, Field(max_length=100)]
    name: Annotated[str, Field(max_length=255)]
    description: Annotated[str | None, Field(max_length=500)] = None
    calculationConfig: dict | None = None


class MetricData(MetricCreateBody):
    id: UUID
    isSystem: bool
    createdBy: UUID
    createdAt: datetime


class MetricCreateResponse(MetricData):
    pass
