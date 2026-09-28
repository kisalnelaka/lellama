"""Offline synchronization endpoint designed for early-morning marine bundling."""

from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.limiter import limiter
from app.core.security import get_optional_current_user
from app.models.user import User
from app.models.vessel import Vessel
from app.models.pfz import PFZCoordinate
from app.models.weather import WeatherCache
from app.models.alert import AlertLog
from app.services.weather_provider import MarineWeatherService
from app.schemas.sync import OfflineSyncPackageResponse
from app.schemas.pfz import (
    PFZGeoJSONFeatureCollection,
    PFZGeoJSONFeature,
    PFZGeoJSONProperties,
    GeoJSONGeometryPoint,
)
from app.schemas.weather import WeatherForecastSeries, WeatherResponse
from app.schemas.alert import AlertLogResponse

router = APIRouter(prefix="/sync", tags=["Offline Marine Sync"])


@router.get(
    "/",
    response_model=OfflineSyncPackageResponse,
    summary="Download complete offline package: PFZs, 24h weather, alerts, and tile manifest",
)
@limiter.limit(settings.RATE_LIMIT_SYNC)
def download_offline_sync_bundle(
    request: Request,
    vessel_id: Optional[str] = None,
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: Session = Depends(get_db),
):

    """Serve complete 24-48h offshore operational data package to mobile client.

    Executes when the fisherman has Wi-Fi / 4G onshore prior to early morning departure.
    """
    now = datetime.now(timezone.utc)
    today = date.today()

    # 1. Fetch active PFZs for Sri Lanka EEZ
    pfz_records = (
        db.query(PFZCoordinate)
        .filter(
            PFZCoordinate.status == "active",
            PFZCoordinate.detection_date == today,
        )
        .all()
    )

    # Fallback to latest available if today's run has not finished
    if not pfz_records:
        pfz_records = (
            db.query(PFZCoordinate)
            .filter(PFZCoordinate.status == "active")
            .order_by(PFZCoordinate.detection_date.desc())
            .limit(100)
            .all()
        )

    features = []
    pfz_points = []
    for zone in pfz_records:
        features.append(
            PFZGeoJSONFeature(
                type="Feature",
                geometry=GeoJSONGeometryPoint(
                    type="Point",
                    coordinates=[zone.longitude, zone.latitude],
                ),
                properties=PFZGeoJSONProperties(
                    id=zone.id,
                    detection_date=str(zone.detection_date),
                    sst_celsius=zone.sst_value,
                    sst_gradient_c_per_km=zone.sst_gradient,
                    chlorophyll_mg_m3=zone.chlorophyll_value,
                    confidence=zone.confidence_score,
                    status=zone.status,
                ),
            )
        )
        pfz_points.append((zone.latitude, zone.longitude))

    geojson_collection = PFZGeoJSONFeatureCollection(
        type="FeatureCollection",
        features=features,
        generated_at=now,
        total_zones=len(features),
    )

    # 2. Identify locations needing 24-hour weather forecast series
    weather_series_list: List[WeatherForecastSeries] = []

    # Get target vessel or primary vessel if authenticated
    vessel = None
    if vessel_id:
        vessel = db.query(Vessel).filter(Vessel.id == vessel_id).first()
    elif current_user:
        vessel = (
            db.query(Vessel).filter(Vessel.user_id == current_user.id).first()
        )

    locations_to_query = []
    if vessel:
        locations_to_query.append(
            (
                vessel.harbor_latitude,
                vessel.harbor_longitude,
                f"Home Port: {vessel.home_port}",
            )
        )
        if vessel.last_known_latitude and vessel.last_known_longitude:
            locations_to_query.append(
                (
                    vessel.last_known_latitude,
                    vessel.last_known_longitude,
                    "Last Known Offshore Position",
                )
            )

    # Always ensure primary departure ports exist if none assigned
    if not locations_to_query:
        locations_to_query.extend([
            (5.9482, 80.4578, "Mirissa Fishery Harbour"),
            (6.4789, 79.9827, "Beruwala Fishery Harbour"),
            (6.0329, 80.2168, "Galle Fishery Harbour"),
        ])

    # Also include top 3 PFZ centroid coordinates
    for lat, lon in pfz_points[:3]:
        locations_to_query.append((lat, lon, f"PFZ Hotspot ({lat:.2f}°N, {lon:.2f}°E)"))

    weather_svc = MarineWeatherService()

    for lat, lon, loc_name in locations_to_query:
        records = (
            db.query(WeatherCache)
            .filter(
                WeatherCache.latitude.between(lat - 0.25, lat + 0.25),
                WeatherCache.longitude.between(lon - 0.25, lon + 0.25),
                WeatherCache.valid_for_time >= now,
            )
            .order_by(WeatherCache.valid_for_time.asc())
            .limit(24)
            .all()
        )

        # If cache is not yet seeded, fetch on the fly
        if not records:
            try:
                records = weather_svc.get_marine_forecast(
                    lat, lon, location_name=loc_name, persist_db=db
                )
            except Exception:
                records = []

        items = [WeatherResponse.model_validate(r) for r in records]
        max_wave = max([f.wave_height for f in items]) if items else 1.2
        weather_series_list.append(
            WeatherForecastSeries(
                latitude=lat,
                longitude=lon,
                location_name=loc_name,
                forecasts=items,
                max_wave_height=max_wave,
                warning_active=max_wave >= 2.5,
            )
        )

    # 3. Fetch active alerts
    alert_query = db.query(AlertLog)
    if current_user:
        alert_query = alert_query.filter(
            (AlertLog.user_id == current_user.id) | (AlertLog.user_id == None)
        )
    alert_records = alert_query.order_by(AlertLog.created_at.desc()).limit(10).all()
    active_alerts = [AlertLogResponse.model_validate(a) for a in alert_records]

    # 4. Offline Map Tile Manifest for Sri Lanka Exclusive Economic Zone (EEZ)
    tile_manifest = {
        "region": "Sri Lanka EEZ",
        "bounds": {
            "min_lat": settings.SRI_LANKA_MIN_LAT,
            "max_lat": settings.SRI_LANKA_MAX_LAT,
            "min_lon": settings.SRI_LANKA_MIN_LON,
            "max_lon": settings.SRI_LANKA_MAX_LON,
        },
        "recommended_min_zoom": 6,
        "recommended_max_zoom": 12,
        "style_url": "mapbox://styles/mapbox/navigation-day-v1",
        "tile_cache_expiry_hours": 72,
    }

    return OfflineSyncPackageResponse(
        sync_timestamp=now,
        package_version="v1.0-maritime",
        user_id=current_user.id if current_user else None,
        vessel_id=vessel.id if vessel else None,
        language_preference=current_user.language_preference if current_user else "si",
        pfz_collection=geojson_collection,
        weather_forecasts=weather_series_list,
        active_alerts=active_alerts,
        offline_tile_manifest=tile_manifest,
    )

