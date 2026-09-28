"""Offline sync payload schemas designed for early-morning marine data bundling."""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel
from app.schemas.pfz import PFZGeoJSONFeatureCollection
from app.schemas.weather import WeatherForecastSeries
from app.schemas.alert import AlertLogResponse


class OfflineSyncPackageResponse(BaseModel):
    """Unified data bundle transferred to the mobile app for 24-48 hours offline survival.

    Contains all active PFZs in Sri Lankan waters, 24-hour hourly marine forecasts
    for departure harbors and active PFZs, and active severe weather alerts.
    """

    sync_timestamp: datetime
    package_version: str
    user_id: str
    vessel_id: Optional[str] = None
    language_preference: str

    # GeoJSON of today's Potential Fishing Zones
    pfz_collection: PFZGeoJSONFeatureCollection

    # Harbor and offshore weather forecast series (hourly for 24-48 hours)
    weather_forecasts: List[WeatherForecastSeries]

    # Active marine weather warnings / alerts
    active_alerts: List[AlertLogResponse]

    # Offline map tile guidance metadata
    offline_tile_manifest: dict
