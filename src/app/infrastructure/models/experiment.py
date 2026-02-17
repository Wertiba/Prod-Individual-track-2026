import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlmodel import Column, DateTime, Field, Relationship, SQLModel

from app.core.schemas.experiment import ExperimentStatus

if TYPE_CHECKING:
    from app.infrastructure.models import Flag, Metric, User
    from app.infrastructure.models.decision import Decision
    from app.infrastructure.models.review import Review


class Experiment(SQLModel, table=True):
    __tablename__ = "experiments"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    code: str = Field(unique=True, nullable=False, index=True, max_length=100)
    flag_code: str = Field(foreign_key="flags.code", nullable=False)

    name: str = Field(nullable=False, max_length=255)
    status: ExperimentStatus = Field(nullable=False, max_length=255)
    version: float = Field(nullable=False, default=1.0)
    part: int = Field(nullable=False, default=0)
    target: str | None = Field(nullable=True, max_length=500)
    isCurrent: bool = Field(nullable=False, default=True)
    description: str = Field(nullable=False, max_length=255)

    createdBy: uuid.UUID = Field(foreign_key="users.id", nullable=False)
    createdAt: datetime = Field(default_factory=datetime.now)

    creator: "User" = Relationship(back_populates="created_experiments")
    flag: "Flag" = Relationship(back_populates="flag_experiments")

    metrics: list["Metric"] = Relationship(back_populates="experiment")
    variants: list["Variant"] = Relationship(back_populates="experiment")
    reviews: list["Review"] = Relationship(back_populates="experiment")


class Variant(SQLModel, table=True):
    __tablename__ = "variants"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, index=True, unique=True)
    experiment_code: str = Field(foreign_key="experiments.code", nullable=False)
    name: str = Field(nullable=False, max_length=255)
    value: str = Field(nullable=False, max_length=255)
    weight: float = Field(nullable=False, default=0.0)
    isControl: bool = Field(nullable=False, default=True)

    createdAt: datetime = Field(default_factory=datetime.now)
    updatedAt: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )

    experiment: "Experiment" = Relationship(back_populates="variants")

    decisions: list["Decision"] = Relationship(back_populates="variant")
