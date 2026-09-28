"""Celery task queue configuration for scheduled marine satellite and weather pipelines."""

from celery import Celery
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
)
