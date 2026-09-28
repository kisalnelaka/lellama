"""SQLAlchemy database model for marine weather forecasts and ocean current caches."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Boolean, DateTime
from app.core.database import Base


class WeatherCache(Base):
    """Hourly ocean forecast records for PFZs and major fishing harbors."""

    __tablename__ = "weather_caches"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    latitude = Column(Float, nullable=False, index=True)
    longitude = Column(Float, nullable=False, index=True)
    location_name = Column(String(128), nullable=True)

    # Time parameters
    forecast_timestamp = Column(DateTime, nullable=False, index=True)
    valid_for_time = Column(DateTime, nullable=False, index=True)

    # Marine dynamics
    wave_height = Column(Float, nullable=False)  # Significant wave height in meters
    wave_direction = Column(Float, nullable=False)  # Dominant wave direction in degrees (0-360)
    wind_wave_height = Column(Float, nullable=False)  # Local wind wave height in meters
    swell_wave_height = Column(Float, nullable=False)  # Swell wave height in meters
    ocean_current_velocity = Column(Float, nullable=False)  # Velocity in m/s (or knots converted)
    ocean_current_direction = Column(Float, nullable=False)  # Direction in degrees (0-360)

    source = Column(
        String(64), default="open-meteo", nullable=False
    )  # 'open-meteo', 'stormglass_fallback'
    is_stale = Column(Boolean, default=False, nullable=False)

    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

    def __repr__(self) -> str:
        return (
            f"<WeatherCache ({self.latitude:.2f}, {self.longitude:.2f}) "
            f"Wave: {self.wave_height}m Current: {self.ocean_current_velocity}m/s "
            f"Valid: {self.valid_for_time}>"
        )
