"""Celery pipelines for daily satellite remote sensing and marine weather ingestion."""

from datetime import date, datetime, timezone
from typing import List, Tuple, Dict, Any, Optional
import logging
from sqlalchemy.orm import Session

from app.core.celery_app import celery_app
from app.core.database import SessionLocal
from app.models.pfz import PFZCoordinate
from app.models.weather import WeatherCache
from app.services.copernicus_service import CopernicusMarineService
from app.services.pfz_algorithm import PFZDetector
from app.services.weather_provider import MarineWeatherService

logger = logging.getLogger(__name__)

# Key Sri Lankan fishery departure harbors
SRI_LANKA_KEY_HARBORS: List[Tuple[str, float, float]] = [
    ("Beruwala Fishery Harbour", 6.4789, 79.9827),
    ("Mirissa Fishery Harbour", 5.9482, 80.4578),
    ("Galle Fishery Harbour", 6.0329, 80.2168),
    ("Tangalle Fishery Harbour", 6.0244, 80.7941),
    ("Dondra Fishery Point", 5.9234, 80.5894),
    ("Negombo Lagoon & Harbour", 7.2008, 79.8736),
    ("Trincomalee Cod Bay Harbour", 8.5874, 81.2152),
    ("Kalpitiya Landing Site", 8.2285, 79.7656),
]


@celery_app.task(name="tasks.run_copernicus_pfz_pipeline")
def run_copernicus_pfz_pipeline(db: Optional[Session] = None) -> Dict[str, Any]:
    """Pull daily Copernicus SST & Chlorophyll, run PFZ algorithm, and persist coordinates."""
    logger.info("Executing Copernicus PFZ remote sensing pipeline...")
    close_db = False
    if db is None:
        db = SessionLocal()
        close_db = True
    try:
        cmems = CopernicusMarineService()
        sst_da, chl_da = cmems.fetch_daily_rasters()

        detector = PFZDetector()
        today = date.today()
        detected_zones = detector.detect_potential_fishing_zones(
            sst_da, chl_da, detection_date=today
        )

        # Mark outdated active PFZs as expired
        db.query(PFZCoordinate).filter(
            PFZCoordinate.detection_date < today,
            PFZCoordinate.status == "active",
        ).update({"status": "expired"})

        created_count = 0
        for zone in detected_zones:
            pfz_obj = PFZCoordinate(
                detection_date=zone["detection_date"],
                source_satellite=zone["source_satellite"],
                latitude=zone["latitude"],
                longitude=zone["longitude"],
                sst_value=zone["sst_value"],
                sst_gradient=zone["sst_gradient"],
                chlorophyll_value=zone["chlorophyll_value"],
                confidence_score=zone["confidence_score"],
                status=zone["status"],
                metadata_json=zone.get("metadata_json"),
            )
            db.add(pfz_obj)
            created_count += 1

        db.commit()
        logger.info(
            "Copernicus PFZ pipeline complete: %d zones recorded in database.",
            created_count,
        )
        return {
            "status": "success",
            "detection_date": str(today),
            "zones_created": created_count,
        }
    except Exception as exc:
        db.rollback()
        logger.error("PFZ pipeline encountered fatal error: %s", exc, exc_info=True)
        raise
    finally:
        if close_db:
            db.close()


@celery_app.task(name="tasks.run_marine_weather_ingestion")
def run_marine_weather_ingestion(
    db: Optional[Session] = None,
    weather_service: Optional[MarineWeatherService] = None,
) -> Dict[str, Any]:
    """Ingest 24-48 hour hourly forecasts for departure harbors and active PFZs."""
    logger.info("Executing marine weather ingestion pipeline...")
    close_db = False
    if db is None:
        db = SessionLocal()
        close_db = True
    try:
        service = weather_service or MarineWeatherService()
        locations_to_poll: List[Tuple[float, float, str]] = [
            (lat, lon, name) for name, lat, lon in SRI_LANKA_KEY_HARBORS
        ]

        # Also poll top 10 active PFZs
        active_pfzs = (
            db.query(PFZCoordinate)
            .filter(PFZCoordinate.status == "active")
            .order_by(PFZCoordinate.confidence_score.desc())
            .limit(10)
            .all()
        )
        for pfz in active_pfzs:
            locations_to_poll.append(
                (
                    pfz.latitude,
                    pfz.longitude,
                    f"PFZ Zone ({pfz.latitude:.2f}N, {pfz.longitude:.2f}E)",
                )
            )

        total_inserted = 0
        for lat, lon, loc_name in locations_to_poll:
            try:
                forecast_items = service.get_forecast(
                    lat, lon, location_name=loc_name
                )
                for item in forecast_items:
                    record_dict = item.to_dict()
                    db_entry = WeatherCache(
                        latitude=record_dict["latitude"],
                        longitude=record_dict["longitude"],
                        location_name=record_dict["location_name"],
                        forecast_timestamp=record_dict["forecast_timestamp"],
                        valid_for_time=record_dict["valid_for_time"],
                        wave_height=record_dict["wave_height"],
                        wave_direction=record_dict["wave_direction"],
                        wind_wave_height=record_dict["wind_wave_height"],
                        swell_wave_height=record_dict["swell_wave_height"],
                        ocean_current_velocity=record_dict[
                            "ocean_current_velocity"
                        ],
                        ocean_current_direction=record_dict[
                            "ocean_current_direction"
                        ],
                        source=record_dict["source"],
                        is_stale=False,
                    )
                    db.add(db_entry)
                    total_inserted += 1
            except Exception as loc_err:
                logger.warning(
                    "Skipping weather point %s (%s, %s): %s",
                    loc_name,
                    lat,
                    lon,
                    loc_err,
                )

        db.commit()
        logger.info(
            "Marine weather ingestion complete: %d hourly forecasts cached.",
            total_inserted,
        )
        return {"status": "success", "records_cached": total_inserted}
    except Exception as exc:
        db.rollback()
        logger.error(
            "Weather ingestion pipeline failed: %s", exc, exc_info=True
        )
        raise
    finally:
        if close_db:
            db.close()


@celery_app.task(name="tasks.run_daily_marine_pipeline")
def run_daily_marine_pipeline() -> Dict[str, Any]:
    """Master cron task scheduled daily at 03:00 AM local time.

    Executes PFZ satellite extraction first, followed by weather caching for updated zones,
    and runs the marine safety threshold alert evaluation.
    """
    logger.info("Starting Master 03:00 AM Sri Lanka Marine Pipeline...")
    pfz_result = run_copernicus_pfz_pipeline()
    weather_result = run_marine_weather_ingestion()

    from app.tasks.alerting import evaluate_marine_safety_thresholds
    alert_result = evaluate_marine_safety_thresholds()

    return {
        "status": "completed",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "pfz_result": pfz_result,
        "weather_result": weather_result,
        "alert_result": alert_result,
    }
