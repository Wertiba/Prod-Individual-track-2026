from datetime import datetime
from enum import Enum
from typing import Annotated
from uuid import UUID

from pydantic import Field

from app.core.schemas.base import DatetimeResponse, PyModel


class ReviewResult(str, Enum):
    APPROVED = 'APPROVED'
    IMPROVEMENT = 'IMPROVEMENT'
    REJECTED = 'REJECTED'


class ReviewCreateBody(PyModel):
    experiment_id: UUID
    result: ReviewResult
    comment: Annotated[str | None, Field(max_length=500)]


class ReviewDataResponse(ReviewCreateBody, DatetimeResponse):
    id: UUID
    createdAt: datetime
    approvedBy: UUID
