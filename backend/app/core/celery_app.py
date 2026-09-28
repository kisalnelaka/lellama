"""Celery task queue configuration for scheduled marine satellite and weather pipelines."""

from celery import Celery
from celery.schedules import crontab
from app.core.config import settings

celery_app = Celery(
    "lellama_tasks",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Colombo",
    enable_utc=True,
    task_track_started=True,
    beat_schedule={
        # Scheduled at 03:00 AM local time (Asia/Colombo) daily
        "daily-marine-pipeline-3am": {
            "task": "tasks.run_daily_marine_pipeline",
            "schedule": crontab(hour=3, minute=0),
            "options": {"queue": "marine_pipelines"},
        },
    },
)
