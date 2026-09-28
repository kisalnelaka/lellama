"""Alert log schemas for warning records and status queries."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class AlertLogResponse(BaseModel):
    """Alert record returned to client applications."""

    id: str
    user_id: str
    vessel_id: Optional[str] = None
    alert_level: str
    channel: str
    target_phone: str
    message_sinhala: str
    message_tamil: str
    message_english: str
    trigger_cause: str
    delivery_status: str
    external_message_id: Optional[str] = None
    created_at: datetime
    delivered_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class AlertTriggerRequest(BaseModel):
    """Administrative or testing trigger payload for an emergency weather broadcast."""

    user_id: str
    alert_level: str = "warning"
    channel: str = "hybrid"
    trigger_cause: str
    wave_height: Optional[float] = None
    wind_speed: Optional[float] = None
