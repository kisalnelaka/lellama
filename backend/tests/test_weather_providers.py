"""Unit and integration tests for weather provider adapter pattern and failover."""

from datetime import datetime, timezone
import pytest
from app.services.weather_provider import (
    MarineWeatherProvider,
    MarineWeatherService,
    WeatherForecastItem,
    OpenMeteoMarineProvider,
    StormglassMarineProvider,
)


class MockFailingProvider(MarineWeatherProvider):
    """Mock provider that simulates upstream network or API outage."""

    def fetch_hourly_forecast(self, latitude, longitude, location_name=None):
        raise ConnectionError("Upstream marine API timeout / 503 error")


class MockSuccessfulProvider(MarineWeatherProvider):
    """Mock provider returning valid forecasts."""

    def fetch_hourly_forecast(self, latitude, longitude, location_name=None):
        now = datetime.now(timezone.utc)
        return [
            WeatherForecastItem(
                latitude=latitude,
                longitude=longitude,
                valid_for_time=now,
                wave_height=2.2,
                wave_direction=195.0,
                wind_wave_height=1.1,
                swell_wave_height=1.8,
                ocean_current_velocity=0.55,
                ocean_current_direction=120.0,
                source="mock_fallback",
                location_name=location_name,
            )
        ]


def test_weather_service_automated_failover():
    """Ensure MarineWeatherService seamlessly falls back when primary provider fails."""
    primary = MockFailingProvider()
    fallback = MockSuccessfulProvider()
    service = MarineWeatherService(
        primary_provider=primary, fallback_provider=fallback
    )

    results = service.get_forecast(6.48, 79.98, location_name="Beruwala Harbour")
    assert len(results) == 1
    assert results[0].source == "mock_fallback"
    assert results[0].wave_height == 2.2
    assert results[0].location_name == "Beruwala Harbour"


def test_weather_service_raises_when_all_providers_fail():
    """Ensure an explicit RuntimeError is raised when all configured providers fail."""
    primary = MockFailingProvider()
    fallback = MockFailingProvider()
    service = MarineWeatherService(
        primary_provider=primary, fallback_provider=fallback
    )

    with pytest.raises(RuntimeError) as exc_info:
        service.get_forecast(6.48, 79.98)
    assert "Weather providers unavailable" in str(exc_info.value)
