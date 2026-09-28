"""Unit and integration tests for the marine safety alerting engine and SMS fallback."""

from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.vessel import Vessel
from app.models.weather import WeatherCache
from app.models.alert import AlertLog
from app.services.alert_dispatcher import AlertDispatcher, PushNotificationClient, SMSFallbackClient
from app.services.safety_evaluator import SafetyThresholdEvaluator
from app.tasks.alerting import evaluate_marine_safety_thresholds


def test_onshore_vessel_receives_push_notification(db_session: Session, test_user: User, test_vessel: Vessel):
    """Ensure vessel with recent ping receives push notification."""
    now = datetime.now(timezone.utc)
    test_vessel.last_ping_time = now - timedelta(minutes=15)
    test_vessel.is_currently_at_sea = True
    db_session.commit()

    dispatcher = AlertDispatcher()
    alert = dispatcher.dispatch_marine_alert(
        db=db_session,
        user=test_user,
        vessel=test_vessel,
        alert_level="warning",
        trigger_cause="wave_height_2.8m",
        wave_height=2.8,
        location_label="Beruwala Offshore",
    )

    assert alert.delivery_status == "push_delivered"
    assert alert.channel == "push"
    assert "අවවාදයයි" in alert.message_sinhala
    assert "எச்சரிக்கை" in alert.message_tamil
    assert "WARNING" in alert.message_english


def test_offshore_offline_vessel_escalates_to_sms_fallback(db_session: Session, test_user: User, test_vessel: Vessel):
    """Ensure vessel without ping in > 2 hours automatically escalates to emergency 2G SMS."""
    now = datetime.now(timezone.utc)
    # Stale telemetry ping: 3.5 hours ago
    test_vessel.last_ping_time = now - timedelta(hours=3, minutes=30)
    test_vessel.is_currently_at_sea = True
    db_session.commit()

    dispatcher = AlertDispatcher()
    alert = dispatcher.dispatch_marine_alert(
        db=db_session,
        user=test_user,
        vessel=test_vessel,
        alert_level="danger",
        trigger_cause="squall_wave_height_3.8m",
        wave_height=3.8,
        location_label="Southern Deep Sea Zone",
    )

    assert alert.delivery_status == "sms_fallback_sent"
    assert alert.channel == "sms_fallback"
    assert alert.target_phone == test_user.phone_number
    assert "3.8" in alert.message_sinhala


def test_safety_evaluator_triggers_and_deduplicates_alerts(db_session: Session, test_user: User, test_vessel: Vessel):
    """Ensure safety evaluator identifies hazardous waves and deduplicates repeated alerts."""
    now = datetime.now(timezone.utc)

    # Place vessel at Beruwala Harbor
    test_vessel.harbor_latitude = 6.48
    test_vessel.harbor_longitude = 79.98
    test_vessel.is_currently_at_sea = False
    db_session.commit()

    # Seed hazardous weather cell (> 2.5m) near Beruwala
    hazardous_weather = WeatherCache(
        latitude=6.48,
        longitude=79.98,
        location_name="Beruwala Outer Sea",
        forecast_timestamp=now,
        valid_for_time=now + timedelta(hours=2),
        wave_height=3.2,
        wave_direction=220.0,
        wind_wave_height=1.8,
        swell_wave_height=2.4,
        ocean_current_velocity=0.8,
        ocean_current_direction=180.0,
        source="open-meteo",
        is_stale=False,
    )
    db_session.add(hazardous_weather)
    db_session.commit()

    evaluator = SafetyThresholdEvaluator()

    # First evaluation run: should dispatch alert
    alerts_run1 = evaluator.evaluate_all_active_vessels(db_session)
    assert len(alerts_run1) == 1
    assert alerts_run1[0].user_id == test_user.id
    assert alerts_run1[0].alert_level == "warning"

    # Second evaluation run immediately after: must be deduplicated
    alerts_run2 = evaluator.evaluate_all_active_vessels(db_session)
    assert len(alerts_run2) == 0


def test_celery_safety_evaluation_task(db_session: Session):
    """Ensure evaluate_marine_safety_thresholds Celery task executes without error."""
    result = evaluate_marine_safety_thresholds(db=db_session)
    assert result["status"] == "success"
    assert "alerts_dispatched" in result
