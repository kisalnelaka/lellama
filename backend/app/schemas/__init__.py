"""Pydantic schemas package initialization."""

from app.schemas.auth import TokenResponse, TokenPayload
from app.schemas.user import UserCreate, UserUpdate, UserResponse, UserLogin
from app.schemas.vessel import VesselCreate, VesselUpdate, VesselResponse, VesselPingLocation
from app.schemas.pfz import PFZResponse, PFZGeoJSONFeature, PFZGeoJSONFeatureCollection
from app.schemas.weather import WeatherResponse, WeatherForecastSeries
from app.schemas.alert import AlertLogResponse
from app.schemas.sync import OfflineSyncPackageResponse

__all__ = [
    "TokenResponse",
    "TokenPayload",
    "UserCreate",
    "UserUpdate",
    "UserResponse",
    "UserLogin",
    "VesselCreate",
    "VesselUpdate",
    "VesselResponse",
    "VesselPingLocation",
    "PFZResponse",
    "PFZGeoJSONFeature",
    "PFZGeoJSONFeatureCollection",
    "WeatherResponse",
    "WeatherForecastSeries",
    "AlertLogResponse",
    "OfflineSyncPackageResponse",
]
