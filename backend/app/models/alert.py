"""SQLAlchemy database model for critical weather and safety alert logs."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class AlertLog(Base):
    """Audit log of weather alerts generated and delivered via Push/SMS."""

    __tablename__ = "alert_logs"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    user_id = Column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    vessel_id = Column(
        String(36), ForeignKey("vessels.id", ondelete="SET NULL"), nullable=True, index=True
    )

    alert_level = Column(
        String(32), default="advisory", nullable=False
    )  # 'advisory', 'warning', 'danger', 'squall_emergency'
    channel = Column(
        String(32), default="push", nullable=False
    )  # 'push', 'sms', 'hybrid_fallback'
    target_phone = Column(String(32), nullable=False)

    # Multi-lingual alert messages rendered for Sri Lankan fishermen
    message_sinhala = Column(Text, nullable=False)
    message_tamil = Column(Text, nullable=False)
    message_english = Column(Text, nullable=False)

    trigger_cause = Column(
        String(255), nullable=False
    )  # e.g., 'wave_height_exceeded_2.8m', 'sudden_squall_gust'
    delivery_status = Column(
        String(32), default="queued", nullable=False
    )  # 'queued', 'push_delivered', 'sms_fallback_sent', 'failed'
    external_message_id = Column(
        String(128), nullable=True
    )  # Twilio SID or FCM message ID

    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    delivered_at = Column(DateTime, nullable=True)

    # Relationships
    user = relationship("User", back_populates="alerts")
    vessel = relationship("Vessel", back_populates="alerts")

    def __repr__(self) -> str:
        return f"<AlertLog [{self.alert_level.upper()}] To: {self.target_phone} Status: {self.delivery_status}>"
