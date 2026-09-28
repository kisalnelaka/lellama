"""Weather and safety alert log endpoints."""

from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.alert import AlertLog
from app.schemas.alert import AlertLogResponse, AlertTriggerRequest

router = APIRouter(prefix="/alerts", tags=["Marine Safety Alerts"])


@router.get(
    "/",
    response_model=List[AlertLogResponse],
    summary="List active alerts for the current user and their vessels",
)
def get_user_alerts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve all safety alerts issued for the user."""
    return (
        db.query(AlertLog)
        .filter(AlertLog.user_id == current_user.id)
        .order_by(AlertLog.created_at.desc())
        .limit(50)
        .all()
    )


@router.post(
    "/trigger",
    response_model=AlertLogResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a test or manual weather alert",
)
def trigger_alert(
    payload: AlertTriggerRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a high-priority trilingual weather warning."""
    wave_info = (
        f" (රළ උස: {payload.wave_height}m)" if payload.wave_height else ""
    )

    alert = AlertLog(
        user_id=payload.user_id,
        alert_level=payload.alert_level,
        channel=payload.channel,
        target_phone=current_user.phone_number,
        message_sinhala=f"අවවාදයයි: මුහුදේ අනතුරුදායක කාලගුණික තත්වයක් හටගෙන ඇත{wave_info}. ආරක්ෂිත ස්ථානයකට යන්න.",
        message_tamil="எச்சரிக்கை: கடலில் ஆபத்தான வானிலை நிலைமை ஏற்பட்டுள்ளது. பாதுகாப்பான இடத்திற்கு செல்லவும்.",
        message_english=f"WARNING: Dangerous marine weather conditions detected{wave_info}. Return to harbor or proceed to safe zone immediately.",
        trigger_cause=payload.trigger_cause,
        delivery_status="queued",
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert
