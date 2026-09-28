"""Vessel registration and telemetry schemas."""

from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field, ConfigDict


class VesselBase(BaseModel):
    """Base fishing vessel properties."""

    registration_number: str = Field(
        ...,
        pattern=r"^[A-Z0-9\-\s/]+$",
        description="Official Department of Fisheries registration ID (e.g., IMUL-A-0982-KLT)",
    )
    vessel_name: str = Field(..., min_length=2, max_length=255)
    vessel_type: Literal[
        "multiday", "dayboat", "traditional_oru", "inboard"
    ] = "multiday"
    home_port: str = Field(..., min_length=2, max_length=128)
    harbor_latitude: float = Field(..., ge=-90.0, le=90.0)
    harbor_longitude: float = Field(..., ge=-180.0, le=180.0)
    length_meters: float = Field(default=12.5, gt=0.0, le=100.0)


class VesselCreate(VesselBase):
    """Payload to register a new vessel under the authenticated user."""

    pass


class VesselUpdate(BaseModel):
    """Payload to update vessel metadata."""

    vessel_name: Optional[str] = None
    vessel_type: Optional[
        Literal["multiday", "dayboat", "traditional_oru", "inboard"]
    ] = None
    home_port: Optional[str] = None
    harbor_latitude: Optional[float] = None
    harbor_longitude: Optional[float] = None
    length_meters: Optional[float] = None
    is_currently_at_sea: Optional[bool] = None


class VesselPingLocation(BaseModel):
    """Offshore telemetry ping sent by mobile app when network is briefly available."""

    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    is_at_sea: bool = True


class VesselResponse(VesselBase):
    """Vessel details returned to client."""

    id: str
    user_id: str
    last_known_latitude: Optional[float] = None
    last_known_longitude: Optional[float] = None
    last_ping_time: Optional[datetime] = None
    is_currently_at_sea: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
