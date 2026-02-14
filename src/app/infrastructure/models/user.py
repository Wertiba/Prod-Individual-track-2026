import uuid
from datetime import datetime, timezone

from pydantic import EmailStr
from sqlalchemy import Column, DateTime
from sqlmodel import Field, Relationship, SQLModel


class UserRole(SQLModel, table=True):
    __tablename__ = "user_roles"

    user_id: uuid.UUID = Field(foreign_key="users.id", primary_key=True)
    role_id: uuid.UUID = Field(foreign_key="roles.id", primary_key=True)


class Role(SQLModel, table=True):
    __tablename__ = "roles"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    value: str

    users: list["User"] = Relationship(back_populates="roles", link_model=UserRole)


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True, index=True)
    email: EmailStr = Field(unique=True, nullable=False)
    password: str = Field(nullable=False)
    fullName: str = Field(nullable=False)
    isActive: bool = Field(default=True)

    createdAt: datetime = Field(default_factory=datetime.now)
    updatedAt: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )

    roles: list["Role"] = Relationship(back_populates="users", link_model=UserRole)
