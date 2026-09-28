"""SQLAlchemy database model for registered fishing vessels."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class Vessel(Base):
    """Fishing vessel entity tracking registration, home port, and latest offshore telemetry."""

    __tablename__ = "vessels"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    user_id = Column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    registration_number = Column(
        String(64), unique=True, index=True, nullable=False
    )  # e.g., 'IMUL-A-0982-KLT' (Sri Lanka Department of Fisheries registration format)
    vessel_name = Column(String(255), nullable=False)
    vessel_type = Column(
        String(64), default="multiday", nullable=False
    )  # 'multiday', 'dayboat', 'traditional_oru', 'inboard'
    home_port = Column(
        String(128), nullable=False
    )  # e.g., 'Beruwala', 'Mirissa', 'Tangalle', 'Trincomalee', 'Negombo'

    # Departure harbor geographical coordinates
    harbor_latitude = Column(Float, nullable=False)
    harbor_longitude = Column(Float, nullable=False)

    length_meters = Column(Float, nullable=False, default=12.5)

    # Offshore tracking & telemetry pings
    last_known_latitude = Column(Float, nullable=True)
    last_known_longitude = Column(Float, nullable=True)
    last_ping_time = Column(DateTime, nullable=True)
    is_currently_at_sea = Column(Boolean, default=False, nullable=False)

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
    owner = relationship("User", back_populates="vessels")
    alerts = relationship("AlertLog", back_populates="vessel")

    def __repr__(self) -> str:
        return f"<Vessel {self.vessel_name} [{self.registration_number}] Home: {self.home_port}>"
