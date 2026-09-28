"""API v1 router registry assembling all endpoint sub-routers."""

from fastapi import APIRouter
from app.api.v1.endpoints import auth, vessels, pfz, weather, alerts, sync

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(vessels.router)
api_router.include_router(pfz.router)
api_router.include_router(weather.router)
api_router.include_router(alerts.router)
api_router.include_router(sync.router)
