"""Celery tasks for continuous marine safety threshold evaluation and alerting."""

from typing import Dict, Any, Optional
import logging
from sqlalchemy.orm import Session

from app.core.celery_app import celery_app
from app.core.database import SessionLocal
from app.services.safety_evaluator import SafetyThresholdEvaluator

logger = logging.getLogger(__name__)


@celery_app.task(name="tasks.evaluate_marine_safety_thresholds")
def evaluate_marine_safety_thresholds(db: Optional[Session] = None) -> Dict[str, Any]:
    """Inspect latest marine weather caches against all active vessels and trigger warnings."""
    logger.info("Running marine safety threshold evaluation worker...")
    close_db = False
    if db is None:
        db = SessionLocal()
        close_db = True
    try:
        evaluator = SafetyThresholdEvaluator()
        alerts = evaluator.evaluate_all_active_vessels(db)
        return {
            "status": "success",
            "alerts_dispatched": len(alerts),
            "alert_ids": [a.id for a in alerts],
        }
    except Exception as exc:
        db.rollback()
        logger.error("Safety evaluation worker failed: %s", exc, exc_info=True)
        raise
    finally:
        if close_db:
            db.close()
