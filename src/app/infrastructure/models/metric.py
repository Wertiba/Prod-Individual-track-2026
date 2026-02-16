import uuid
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING

from sqlmodel import JSON, Column, Field, Relationship, SQLModel

if TYPE_CHECKING:
    from app.infrastructure.models import User
    from app.infrastructure.models.event import EventCatalog
    from app.infrastructure.models.experiment import Experiment


class MetricCatalog(SQLModel, table=True):
    __tablename__ = "metric_catalog"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    code: str = Field(unique=True, nullable=False, index=True, max_length=255)
    name: str = Field(nullable=False, max_length=255)
    isSystem: bool = Field(nullable=False, default=False)
    description: str = Field(nullable=True, max_length=500)
    calculationConfig: dict | None = Field(sa_column=Column(JSON, nullable=True))

    createdBy: uuid.UUID = Field(foreign_key="users.id", nullable=False)
    createdAt: datetime = Field(default_factory=datetime.now)

    creator: "User | None" = Relationship(back_populates="created_catalog_metrics")

    metrics: list["Metric"] | None = Relationship(back_populates="metric_catalog")


class Metric(SQLModel, table=True):
    __tablename__ = "metrics"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    experiment_id: uuid.UUID = Field(foreign_key="experiments.id", nullable=False)
    metricCatalog_code: str = Field(foreign_key="metric_catalog.code", nullable=False)

    role: str = Field(nullable=False, default="DEF", max_length=255)
    time_from: datetime = Field(
        nullable=True,
        default_factory=lambda: datetime.now(tz=UTC) - timedelta(days=10)
    )
    time_to: datetime = Field(nullable=True, default_factory=datetime.now)

    window: int = Field(nullable=True, default=864000)
    threshold: int = Field(nullable=True)
    action_code: str = Field(nullable=True, foreign_key="guardrail_actions.code")

    addedBy: uuid.UUID = Field(foreign_key="users.id", nullable=False)
    createdAt: datetime = Field(default_factory=datetime.now)

    experiment: "Experiment" = Relationship(back_populates="metrics")
    metric_catalog: "MetricCatalog" = Relationship(back_populates="metrics")
    creator: "User" = Relationship(back_populates="added_metrics")
    guardrail_action: "GuardrailAction | None" = Relationship(back_populates="guardrails")

    history: list["MetricHistory"] | None = Relationship(back_populates="metric")
    event_catalog: list["EventCatalog"] | None = Relationship(back_populates="metrics")


class GuardrailAction(SQLModel, table=True):
    __tablename__ = "guardrail_actions"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    code: str = Field(unique=True, nullable=False, max_length=255, index=True)
    name: str = Field(nullable=False, max_length=255)
    description: str = Field(nullable=True, max_length=500)

    guardrails: list["Metric"] | None = Relationship(back_populates="guardrail_action")


class MetricHistory(SQLModel, table=True):
    __tablename__ = "metric_history"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    metric_id: uuid.UUID = Field(foreign_key="metrics.id", nullable=False)
    history: dict | None = Field(sa_column=Column(JSON, nullable=True))
    workedAt: datetime = Field(default_factory=datetime.now)

    metric: "Metric" = Relationship(back_populates="history")
