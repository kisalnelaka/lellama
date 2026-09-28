"""Integration tests for Celery pipeline tasks."""

from sqlalchemy.orm import Session
from app.models.pfz import PFZCoordinate
from app.models.weather import WeatherCache
from app.tasks.pipeline import (
    run_copernicus_pfz_pipeline,
    run_marine_weather_ingestion,
)
from app.services.weather_provider import (
    MarineWeatherService,
    MarineWeatherProvider,
    WeatherForecastItem,
)
from datetime import datetime, timezone


class MockWeatherProvider(MarineWeatherProvider):
    """Deterministic mock provider for pipeline testing."""

    def fetch_hourly_forecast(self, latitude, longitude, location_name=None):
        now = datetime.now(timezone.utc)
        return [
            WeatherForecastItem(
                latitude=latitude,
                longitude=longitude,
                valid_for_time=now,
                wave_height=1.75,
                wave_direction=200.0,
                wind_wave_height=0.8,
                swell_wave_height=1.5,
                ocean_current_velocity=0.4,
                ocean_current_direction=150.0,
                source="test_pipeline_mock",
                location_name=location_name,
            )
        ]


def test_copernicus_pfz_pipeline_execution(db_session: Session):
    """Ensure run_copernicus_pfz_pipeline executes end-to-end and populates the database."""
    result = run_copernicus_pfz_pipeline(db=db_session)
    assert result["status"] == "success"
    assert result["zones_created"] >= 1

    # Verify records were inserted into PFZCoordinate
    count = (
        db_session.query(PFZCoordinate)
        .filter(PFZCoordinate.status == "active")
        .count()
    )
    assert count == result["zones_created"]


def test_marine_weather_ingestion_pipeline_execution(db_session: Session):
    """Ensure run_marine_weather_ingestion queries locations and caches weather records."""
    mock_service = MarineWeatherService(
        primary_provider=MockWeatherProvider(),
        fallback_provider=MockWeatherProvider(),
    )
    result = run_marine_weather_ingestion(
        db=db_session, weather_service=mock_service
    )
    assert result["status"] == "success"
    assert result["records_cached"] >= 8  # At least 8 key harbors

    # Verify records were inserted into WeatherCache
    count = db_session.query(WeatherCache).count()
    assert count == result["records_cached"]
