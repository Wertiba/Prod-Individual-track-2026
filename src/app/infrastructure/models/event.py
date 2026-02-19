import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlmodel import JSON, Column, Field, Relationship, SQLModel

if TYPE_CHECKING:
    from app.infrastructure.models import MetricCatalog, User
    from app.infrastructure.models.decision import Decision


class EventCatalog(SQLModel, table=True):
    __tablename__ = 'event_catalog'

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    metricCatalog_code: str = Field(foreign_key="metric_catalog.code")
    code: str = Field(unique=True, max_length=100, nullable=False, index=True)

    name: str = Field(nullable=False, max_length=255)
    description: str | None = Field(nullable=True, max_length=500)
    requiredParams: dict | None = Field(sa_column=Column(JSON, nullable=True))
    requiresExposure: bool = Field(nullable=False, default=False)
    isSystem: bool = Field(nullable=False, default=False)
    inArchive: bool = Field(nullable=False, default=False)

    createdBy: uuid.UUID = Field(foreign_key="users.id", nullable=False)
    createdAt: datetime = Field(default_factory=datetime.now)

    creator: "User" = Relationship(back_populates="created_catalog_events")
    metrics: list["MetricCatalog"] = Relationship(back_populates="events")

    events: list["Event"] = Relationship(back_populates="event_catalog")


class Event(SQLModel, table=True):
    __tablename__ = 'events'

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    eventKey: str = Field(nullable=False, unique=True, max_length=255)
    decision_id: uuid.UUID = Field(foreign_key="decisions.id", nullable=False)
    eventCatalog_code: str = Field(foreign_key="event_catalog.code", nullable=False)
    data: dict = Field(sa_column=Column(JSON, nullable=True))

    createdAt: datetime = Field(default_factory=datetime.now)

    decision: "Decision" = Relationship(back_populates="events")
    event_catalog: "EventCatalog" = Relationship(back_populates="events")
