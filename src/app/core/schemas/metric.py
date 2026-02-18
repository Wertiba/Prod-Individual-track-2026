from datetime import datetime
from enum import Enum
from typing import Annotated
from uuid import UUID

from pydantic import Field

from app.core.schemas.base import DatetimeResponse, PyModel


class AggregationUnit(str, Enum):
    USER = "USER"
    EVENT = "EVENT"


class MetricType(str, Enum):
    SUM = "SUM"
    AVG = "AVG"
    MIN = "MIN"
    MAX = "MAX"
    COUNT = "COUNT"
    RATIO = "RATIO"


class MetricCreateBody(PyModel):
    code: Annotated[str, Field(max_length=100)]
    name: Annotated[str, Field(max_length=255)]
    type: MetricType
    aggregationUnit: AggregationUnit | None = AggregationUnit.EVENT
    description: Annotated[str | None, Field(max_length=500)] = None
    calculationConfig: dict | None = None


class MetricData(MetricCreateBody):
    id: UUID
    isSystem: bool
    createdBy: UUID | None = None
    createdAt: datetime


class MetricReadResponse(MetricData, DatetimeResponse):
    pass
