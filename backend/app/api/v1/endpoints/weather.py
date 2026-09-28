"""Marine weather endpoints: Point query, harbor forecasts, and cache ingestion."""

from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.weather import WeatherCache
from app.schemas.weather import WeatherResponse, WeatherForecastSeries

router = APIRouter(prefix="/weather", tags=["Marine Weather"])


@router.get(
    "/point",
    response_model=WeatherForecastSeries,
    summary="Get 24-48 hour hourly marine weather forecast for a GPS point",
)
def get_point_weather_series(
    latitude: float = Query(..., ge=-90.0, le=90.0),
    longitude: float = Query(..., ge=-180.0, le=180.0),
    location_name: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve cached hourly forecast for the requested coordinate."""
    # Find forecasts within ~0.2 degrees (~22km)
    lat_min, lat_max = latitude - 0.2, latitude + 0.2
    lon_min, lon_max = longitude - 0.2, longitude + 0.2

    from datetime import timedelta
    query_window = datetime.now(timezone.utc) - timedelta(hours=1)
    records = (
        db.query(WeatherCache)
        .filter(
            WeatherCache.latitude.between(lat_min, lat_max),
            WeatherCache.longitude.between(lon_min, lon_max),
            WeatherCache.valid_for_time >= query_window,
        )
        .order_by(WeatherCache.valid_for_time.asc())
        .limit(48)
        .all()
    )

    forecast_items = [WeatherResponse.model_validate(r) for r in records]
    max_wave = (
        max([f.wave_height for f in forecast_items]) if forecast_items else 0.0
    )
    warning_active = max_wave >= 2.5

    return WeatherForecastSeries(
        latitude=latitude,
        longitude=longitude,
        location_name=location_name or f"Point ({latitude:.2f}, {longitude:.2f})",
        forecasts=forecast_items,
        max_wave_height=max_wave,
        warning_active=warning_active,
    )


@router.post(
    "/cache",
    response_model=WeatherResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Ingest a weather cache entry (Ingestion Pipeline)",
)
def create_weather_cache_entry(
    latitude: float,
    longitude: float,
    forecast_timestamp: datetime,
    valid_for_time: datetime,
    wave_height: float,
    wave_direction: float,
    wind_wave_height: float,
    swell_wave_height: float,
    ocean_current_velocity: float,
    ocean_current_direction: float,
    source: str = "open-meteo",
    location_name: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Record an hourly marine forecast point in the database cache."""
    entry = WeatherCache(
        latitude=latitude,
        longitude=longitude,
        location_name=location_name,
        forecast_timestamp=forecast_timestamp,
        valid_for_time=valid_for_time,
        wave_height=wave_height,
        wave_direction=wave_direction,
        wind_wave_height=wind_wave_height,
        swell_wave_height=swell_wave_height,
        ocean_current_velocity=ocean_current_velocity,
        ocean_current_direction=ocean_current_direction,
        source=source,
        is_stale=False,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry
