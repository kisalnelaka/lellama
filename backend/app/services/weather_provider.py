"""Marine weather data providers implementing the Adapter/Interface design pattern.

Supports Open-Meteo Marine as primary source and Stormglass.io as automated fallback.
"""

from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import logging
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


class WeatherForecastItem:
    """Standardized internal representation of an hourly marine weather forecast."""

    def __init__(
        self,
        latitude: float,
        longitude: float,
        valid_for_time: datetime,
        wave_height: float,
        wave_direction: float,
        wind_wave_height: float,
        swell_wave_height: float,
        ocean_current_velocity: float,
        ocean_current_direction: float,
        source: str,
        location_name: Optional[str] = None,
    ):
        self.latitude = latitude
        self.longitude = longitude
        self.valid_for_time = valid_for_time
        self.wave_height = wave_height
        self.wave_direction = wave_direction
        self.wind_wave_height = wind_wave_height
        self.swell_wave_height = swell_wave_height
        self.ocean_current_velocity = ocean_current_velocity
        self.ocean_current_direction = ocean_current_direction
        self.source = source
        self.location_name = location_name

    def to_dict(self) -> Dict[str, Any]:
        """Convert forecast item to dictionary matching WeatherCache schema."""
        return {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "location_name": self.location_name,
            "forecast_timestamp": datetime.now(timezone.utc),
            "valid_for_time": self.valid_for_time,
            "wave_height": self.wave_height,
            "wave_direction": self.wave_direction,
            "wind_wave_height": self.wind_wave_height,
            "swell_wave_height": self.swell_wave_height,
            "ocean_current_velocity": self.ocean_current_velocity,
            "ocean_current_direction": self.ocean_current_direction,
            "source": self.source,
            "is_stale": False,
        }


class MarineWeatherProvider(ABC):
    """Abstract interface for maritime weather data providers."""

    @abstractmethod
    def fetch_hourly_forecast(
        self,
        latitude: float,
        longitude: float,
        location_name: Optional[str] = None,
    ) -> List[WeatherForecastItem]:
        """Fetch 24-48 hour hourly marine forecast for a coordinate."""
        pass


class OpenMeteoMarineProvider(MarineWeatherProvider):
    """Primary weather provider using the Open-Meteo Marine API (free ocean wave models)."""

    BASE_URL = "https://marine-api.open-meteo.com/v1/marine"

    def fetch_hourly_forecast(
        self,
        latitude: float,
        longitude: float,
        location_name: Optional[str] = None,
    ) -> List[WeatherForecastItem]:
        """Fetch marine forecast from Open-Meteo Marine endpoint."""
        params = {
            "latitude": round(latitude, 4),
            "longitude": round(longitude, 4),
            "hourly": (
                "wave_height,wave_direction,wind_wave_height,"
                "swell_wave_height,ocean_current_velocity,ocean_current_direction"
            ),
            "timezone": "Asia/Colombo",
        }

        try:
            with httpx.Client(timeout=12.0) as client:
                response = client.get(self.BASE_URL, params=params)
                response.raise_for_status()
                data = response.json()

            hourly = data.get("hourly", {})
            times = hourly.get("time", [])
            wave_heights = hourly.get("wave_height", [])
            wave_dirs = hourly.get("wave_direction", [])
            wind_waves = hourly.get("wind_wave_height", [])
            swells = hourly.get("swell_wave_height", [])
            current_vels = hourly.get("ocean_current_velocity", [])
            current_dirs = hourly.get("ocean_current_direction", [])

            results: List[WeatherForecastItem] = []
            for i in range(min(48, len(times))):
                # ISO timestamp string to datetime
                valid_time = datetime.fromisoformat(times[i]).replace(
                    tzinfo=timezone.utc
                )
                results.append(
                    WeatherForecastItem(
                        latitude=latitude,
                        longitude=longitude,
                        valid_for_time=valid_time,
                        wave_height=float(wave_heights[i] or 0.0),
                        wave_direction=float(wave_dirs[i] or 0.0),
                        wind_wave_height=float(wind_waves[i] or 0.0),
                        swell_wave_height=float(swells[i] or 0.0),
                        ocean_current_velocity=float(current_vels[i] or 0.0),
                        ocean_current_direction=float(current_dirs[i] or 0.0),
                        source="open-meteo",
                        location_name=location_name,
                    )
                )
            return results
        except Exception as exc:
            logger.warning(
                "Open-Meteo Marine request failed for (%s, %s): %s",
                latitude,
                longitude,
                exc,
            )
            raise


class StormglassMarineProvider(MarineWeatherProvider):
    """Fallback weather provider using the Stormglass.io API."""

    BASE_URL = "https://api.stormglass.io/v2/weather/point"

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or settings.STORMGLASS_API_KEY

    def fetch_hourly_forecast(
        self,
        latitude: float,
        longitude: float,
        location_name: Optional[str] = None,
    ) -> List[WeatherForecastItem]:
        """Fetch marine forecast from Stormglass.io point endpoint."""
        if not self.api_key:
            raise ValueError("Stormglass API key is not configured.")

        params = {
            "lat": round(latitude, 4),
            "lng": round(longitude, 4),
            "params": (
                "waveHeight,waveDirection,windWaveHeight,"
                "swellHeight,currentSpeed,currentDirection"
            ),
        }
        headers = {"Authorization": self.api_key}

        try:
            with httpx.Client(timeout=12.0) as client:
                response = client.get(
                    self.BASE_URL, params=params, headers=headers
                )
                response.raise_for_status()
                data = response.json()

            hours = data.get("hours", [])
            results: List[WeatherForecastItem] = []

            for h in hours[:48]:
                time_str = h.get("time")
                valid_time = datetime.fromisoformat(
                    time_str.replace("Z", "+00:00")
                )

                def extract_val(entry: Any, fallback: float = 0.0) -> float:
                    if isinstance(entry, dict):
                        # Stormglass returns dict of sources (e.g. {'sg': 1.8, 'noaa': 1.7})
                        return float(next(iter(entry.values()), fallback))
                    return float(entry or fallback)

                results.append(
                    WeatherForecastItem(
                        latitude=latitude,
                        longitude=longitude,
                        valid_for_time=valid_time,
                        wave_height=extract_val(h.get("waveHeight")),
                        wave_direction=extract_val(h.get("waveDirection")),
                        wind_wave_height=extract_val(h.get("windWaveHeight")),
                        swell_wave_height=extract_val(h.get("swellHeight")),
                        ocean_current_velocity=extract_val(h.get("currentSpeed")),
                        ocean_current_direction=extract_val(
                            h.get("currentDirection")
                        ),
                        source="stormglass_fallback",
                        location_name=location_name,
                    )
                )
            return results
        except Exception as exc:
            logger.warning(
                "Stormglass fallback request failed for (%s, %s): %s",
                latitude,
                longitude,
                exc,
            )
            raise


class MarineWeatherService:
    """Unified maritime weather service orchestrating provider failover."""

    def __init__(
        self,
        primary_provider: Optional[MarineWeatherProvider] = None,
        fallback_provider: Optional[MarineWeatherProvider] = None,
    ):
        self.primary = primary_provider or OpenMeteoMarineProvider()
        self.fallback = fallback_provider or StormglassMarineProvider()

    def get_forecast(
        self,
        latitude: float,
        longitude: float,
        location_name: Optional[str] = None,
    ) -> List[WeatherForecastItem]:
        """Query primary provider with automated failover to fallback."""
        try:
            return self.primary.fetch_hourly_forecast(
                latitude, longitude, location_name
            )
        except Exception as primary_error:
            logger.warning(
                "Primary weather provider failed (%s). Triggering Stormglass fallback.",
                primary_error,
            )
            try:
                return self.fallback.fetch_hourly_forecast(
                    latitude, longitude, location_name
                )
            except Exception as fallback_error:
                logger.error(
                    "All marine weather providers failed for (%s, %s). Primary: %s, Fallback: %s",
                    latitude,
                    longitude,
                    primary_error,
                    fallback_error,
                )
                raise RuntimeError(
                    f"Weather providers unavailable: {primary_error} | {fallback_error}"
                )
