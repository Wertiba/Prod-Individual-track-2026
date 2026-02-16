import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlmodel import JSON, Column, Field, Relationship, SQLModel

if TYPE_CHECKING:
    from app.infrastructure.models import User
    from app.infrastructure.models.decision import Decision
    from app.infrastructure.models.metric import Metric


class EventCatalog(SQLModel, table=True):
    __tablename__ = 'event_catalog'

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    code: str = Field(unique=True, max_length=255, nullable=False, index=True)
    metricCatalog_code: str = Field(foreign_key="metric_catalog.code", nullable=False)

    name: str = Field(nullable=False, max_length=255)
    description: str = Field(nullable=True, max_length=500)
    requiredParams: dict | None = Field(sa_column=Column(JSON, nullable=True))
    requiresExposure: bool = Field(nullable=False, default=False)
    isSystem: bool = Field(nullable=False, default=False)
    inArchive: bool = Field(nullable=False, default=False)

    createdBy: uuid.UUID = Field(foreign_key="users.id", nullable=False)
    createdAt: datetime = Field(default_factory=datetime.now)

    creator: "User" = Relationship(back_populates="created_catalog_events")
    metric: "Metric" = Relationship(back_populates="event_catalog")

    events: list["Event"] | None = Relationship(back_populates="event_catalog")


class Event(SQLModel, table=True):
    __tablename__ = 'events'

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, unique=True)
    eventKey: str = Field(nullable=False, unique=True, max_length=255)
    decision_id: uuid.UUID = Field(foreign_key="decisions.id", nullable=False)
    eventCatalog_code: str = Field(foreign_key="event_catalog.code", nullable=False)
    data: dict | None = Field(sa_column=Column(JSON, nullable=True))

    createdAt: datetime = Field(default_factory=datetime.now)

    decision: "Decision" = Relationship(back_populates="events")
    event_catalog: "EventCatalog" = Relationship(back_populates="events")
