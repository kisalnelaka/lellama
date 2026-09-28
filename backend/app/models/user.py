"""SQLAlchemy database model for system users and fishermen."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base


class User(Base):
    """User account entity representing fishermen, vessel captains, and maritime authorities."""

    __tablename__ = "users"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    email = Column(String(255), unique=True, index=True, nullable=False)
    phone_number = Column(
        String(32), unique=True, index=True, nullable=False
    )  # E.164 formatted for SMS emergency fallback
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    language_preference = Column(
        String(10), default="si", nullable=False
    )  # 'si' (Sinhala), 'ta' (Tamil), 'en' (English)
    role = Column(
        String(32), default="fisher", nullable=False
    )  # 'fisher', 'captain', 'coastguard', 'admin'
    is_active = Column(Boolean, default=True, nullable=False)

    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    vessels = relationship(
        "Vessel", back_populates="owner", cascade="all, delete-orphan"
    )
    alerts = relationship(
        "AlertLog", back_populates="user", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<User {self.full_name} ({self.phone_number}) - Role: {self.role}>"
