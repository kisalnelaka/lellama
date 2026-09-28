"""Vessel management endpoints: registration, lookup, telemetry update."""

from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.vessel import Vessel
from app.schemas.vessel import (
    VesselCreate,
    VesselUpdate,
    VesselResponse,
    VesselPingLocation,
)

router = APIRouter(prefix="/vessels", tags=["Vessels"])


@router.post(
    "/",
    response_model=VesselResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new fishing vessel",
)
def register_vessel(
    payload: VesselCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Register a new vessel under the currently logged-in fisherman or company."""
    existing = (
        db.query(Vessel)
        .filter(Vessel.registration_number == payload.registration_number)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Vessel with registration number '{payload.registration_number}' is already registered.",
        )

    vessel = Vessel(
        user_id=current_user.id,
        registration_number=payload.registration_number.strip().upper(),
        vessel_name=payload.vessel_name,
        vessel_type=payload.vessel_type,
        home_port=payload.home_port,
        harbor_latitude=payload.harbor_latitude,
        harbor_longitude=payload.harbor_longitude,
        length_meters=payload.length_meters,
    )
    db.add(vessel)
    db.commit()
    db.refresh(vessel)
    return vessel


@router.get(
    "/",
    response_model=List[VesselResponse],
    summary="List all vessels belonging to the authenticated user",
)
def list_vessels(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return all vessels associated with the user account, or all if admin/coastguard."""
    if current_user.role in ["admin", "coastguard"]:
        return db.query(Vessel).all()
    return db.query(Vessel).filter(Vessel.user_id == current_user.id).all()


@router.get(
    "/{vessel_id}",
    response_model=VesselResponse,
    summary="Get vessel details by ID",
)
def get_vessel(
    vessel_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve details of a specific vessel."""
    vessel = db.query(Vessel).filter(Vessel.id == vessel_id).first()
    if not vessel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vessel not found.",
        )

    if (
        vessel.user_id != current_user.id
        and current_user.role not in ["admin", "coastguard"]
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: you do not own this vessel.",
        )
    return vessel


@router.put(
    "/{vessel_id}",
    response_model=VesselResponse,
    summary="Update vessel configuration",
)
def update_vessel(
    vessel_id: str,
    payload: VesselUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update details of a registered vessel."""
    vessel = db.query(Vessel).filter(Vessel.id == vessel_id).first()
    if not vessel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vessel not found.",
        )

    if (
        vessel.user_id != current_user.id
        and current_user.role not in ["admin", "coastguard"]
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: you do not own this vessel.",
        )

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(vessel, field, value)

    db.commit()
    db.refresh(vessel)
    return vessel


@router.post(
    "/{vessel_id}/ping",
    response_model=VesselResponse,
    summary="Update vessel offshore GPS location and ping time",
)
def ping_vessel_location(
    vessel_id: str,
    payload: VesselPingLocation,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update offshore telemetry GPS coordinates when connectivity is momentarily established."""
    vessel = db.query(Vessel).filter(Vessel.id == vessel_id).first()
    if not vessel:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vessel not found.",
        )

    if (
        vessel.user_id != current_user.id
        and current_user.role not in ["admin", "coastguard"]
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: you do not own this vessel.",
        )

    vessel.last_known_latitude = payload.latitude
    vessel.last_known_longitude = payload.longitude
    vessel.last_ping_time = datetime.now(timezone.utc)
    vessel.is_currently_at_sea = payload.is_at_sea

    db.commit()
    db.refresh(vessel)
    return vessel
