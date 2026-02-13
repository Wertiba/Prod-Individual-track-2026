import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel

from app.core.schemas.flag import FlagType


class Flag(SQLModel, table=True):
    __tablename__ = "flags"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, index=True)
    key: str = Field(unique=True, nullable=False)
    default: str = Field(nullable=False)
    type: FlagType = Field(nullable=False)
    enabled: bool = Field(default=True)
    createdAt: datetime = Field(default_factory=datetime.now)
    updatedAt: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
