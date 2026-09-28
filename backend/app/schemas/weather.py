"""Marine weather cache schemas and hourly forecast series."""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field, ConfigDict


class WeatherResponse(BaseModel):
    """Single marine weather forecast record."""

    id: str
    latitude: float
    longitude: float
    location_name: Optional[str] = None
    forecast_timestamp: datetime
    valid_for_time: datetime
    wave_height: float = Field(..., description="Wave height in meters")
    wave_direction: float = Field(..., description="Wave direction in degrees (0-360)")
    wind_wave_height: float = Field(..., description="Wind wave height in meters")
    swell_wave_height: float = Field(..., description="Swell wave height in meters")
    ocean_current_velocity: float = Field(
        ..., description="Current speed in m/s"
    )
    ocean_current_direction: float = Field(
        ..., description="Current direction in degrees (0-360)"
    )
    source: str
    is_stale: bool

    model_config = ConfigDict(from_attributes=True)


class WeatherForecastSeries(BaseModel):
    """24-48 hour sequence of hourly forecasts for a specific GPS coordinate or harbor."""

    latitude: float
    longitude: float
    location_name: Optional[str] = None
    forecasts: List[WeatherResponse]
    max_wave_height: float
    warning_active: bool
