"""Background marine safety evaluator comparing vessel locations against ocean hazard thresholds."""

from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
import logging
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.models.user import User
from app.models.vessel import Vessel
from app.models.weather import WeatherCache
from app.models.alert import AlertLog
from app.services.alert_dispatcher import AlertDispatcher

logger = logging.getLogger(__name__)

# Marine Safety Thresholds for Sri Lankan Artisanal / Multi-day Fisheries
WAVE_HEIGHT_WARNING_METERS = 2.5
WAVE_HEIGHT_DANGER_METERS = 3.5
OCEAN_CURRENT_WARNING_MS = 1.2
ALERT_DEDUPLICATION_WINDOW_HOURS = 6


class SafetyThresholdEvaluator:
    """Evaluates active weather conditions against vessel positions and triggers alerts."""

    def __init__(self, dispatcher: Optional[AlertDispatcher] = None):
        self.dispatcher = dispatcher or AlertDispatcher()

    def evaluate_all_active_vessels(self, db: Session) -> List[AlertLog]:
        """Scan all vessels and departure harbors against recent weather forecasts."""
        now = datetime.now(timezone.utc)
        triggered_alerts: List[AlertLog] = []

        # 1. Fetch recent forecast caches valid within the next 12 hours
        horizon_end = now + timedelta(hours=12)
        hazardous_caches = (
            db.query(WeatherCache)
            .filter(
                WeatherCache.valid_for_time.between(now, horizon_end),
                or_(
                    WeatherCache.wave_height >= WAVE_HEIGHT_WARNING_METERS,
                    WeatherCache.ocean_current_velocity >= OCEAN_CURRENT_WARNING_MS,
                ),
            )
            .all()
        )

        if not hazardous_caches:
            logger.info("Marine safety check complete: sea conditions within safe limits.")
            return triggered_alerts

        # 2. Iterate through registered vessels
        vessels = db.query(Vessel).all()
        for vessel in vessels:
            owner = db.query(User).filter(User.id == vessel.user_id).first()
            if not owner or not owner.is_active:
                continue

            # Check both offshore location (if at sea) and home harbor
            eval_points = []
            if vessel.is_currently_at_sea and vessel.last_known_latitude and vessel.last_known_longitude:
                eval_points.append(
                    (vessel.last_known_latitude, vessel.last_known_longitude, "Offshore Fishing Zone")
                )
            eval_points.append(
                (vessel.harbor_latitude, vessel.harbor_longitude, f"Harbor of {vessel.home_port}")
            )

            for target_lat, target_lon, label in eval_points:
                # Find if any hazardous weather cell is within ~35km (0.3 degrees)
                matched_hazard = None
                for cache in hazardous_caches:
                    d_lat = abs(cache.latitude - target_lat)
                    d_lon = abs(cache.longitude - target_lon)
                    if d_lat <= 0.3 and d_lon <= 0.3:
                        matched_hazard = cache
                        break

                if matched_hazard:
                    # Determine severity
                    if matched_hazard.wave_height >= WAVE_HEIGHT_DANGER_METERS:
                        alert_level = "danger"
                        cause = f"severe_squall_wave_height_{matched_hazard.wave_height:.1f}m"
                    else:
                        alert_level = "warning"
                        cause = f"hazardous_sea_wave_height_{matched_hazard.wave_height:.1f}m"

                    # Deduplication check: check if an alert was already issued within the last 6 hours
                    recent_alert = (
                        db.query(AlertLog)
                        .filter(
                            AlertLog.user_id == owner.id,
                            AlertLog.vessel_id == vessel.id,
                            AlertLog.created_at >= now - timedelta(hours=ALERT_DEDUPLICATION_WINDOW_HOURS),
                        )
                        .first()
                    )

                    if recent_alert and recent_alert.alert_level == alert_level:
                        logger.debug("Suppressing duplicate alert for User %s / Vessel %s", owner.id, vessel.id)
                        continue

                    # Dispatch alert
                    alert_log = self.dispatcher.dispatch_marine_alert(
                        db=db,
                        user=owner,
                        vessel=vessel,
                        alert_level=alert_level,
                        trigger_cause=cause,
                        wave_height=matched_hazard.wave_height,
                        location_label=label,
                    )
                    triggered_alerts.append(alert_log)
                    break  # Alert dispatched for this vessel; break to next vessel

        logger.info("Safety evaluation complete: triggered %d emergency alerts.", len(triggered_alerts))
        return triggered_alerts
