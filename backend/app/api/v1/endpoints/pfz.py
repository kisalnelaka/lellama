"""Potential Fishing Zones (PFZ) endpoints: Coordinates & RFC 7946 GeoJSON feed."""

from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.pfz import PFZCoordinate
from app.schemas.pfz import (
    PFZResponse,
    PFZGeoJSONFeatureCollection,
    PFZGeoJSONFeature,
    PFZGeoJSONProperties,
    GeoJSONGeometryPoint,
)

router = APIRouter(prefix="/pfz", tags=["Potential Fishing Zones"])


@router.get(
    "/",
    response_model=List[PFZResponse],
    summary="List active PFZ coordinates for Sri Lankan waters",
)
def list_pfzs(
    target_date: Optional[date] = Query(
        None, description="Filter PFZs by date (default: today)"
    ),
    min_confidence: float = Query(
        0.5, ge=0.0, le=1.0, description="Minimum confidence score threshold"
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieve filtered PFZ entries from oceanographic analysis."""
    query = db.query(PFZCoordinate).filter(
        PFZCoordinate.status == "active",
        PFZCoordinate.confidence_score >= min_confidence,
    )
    if target_date:
        query = query.filter(PFZCoordinate.detection_date == target_date)
    return query.order_by(PFZCoordinate.confidence_score.desc()).all()


@router.get(
    "/geojson",
    response_model=PFZGeoJSONFeatureCollection,
    summary="Get active PFZs formatted as an RFC 7946 GeoJSON FeatureCollection",
)
def get_pfz_geojson(
    target_date: Optional[date] = Query(None),
    min_confidence: float = Query(0.5, ge=0.0, le=1.0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Generate high-contrast GeoJSON features for mapping rendering and offline caching."""
    query = db.query(PFZCoordinate).filter(
        PFZCoordinate.status == "active",
        PFZCoordinate.confidence_score >= min_confidence,
    )
    if target_date:
        query = query.filter(PFZCoordinate.detection_date == target_date)

    zones = query.all()
    features = []

    for zone in zones:
        feature = PFZGeoJSONFeature(
            type="Feature",
            geometry=GeoJSONGeometryPoint(
                type="Point",
                coordinates=[zone.longitude, zone.latitude],  # [lon, lat] per RFC 7946
            ),
            properties=PFZGeoJSONProperties(
                id=zone.id,
                detection_date=str(zone.detection_date),
                sst_celsius=zone.sst_value,
                sst_gradient_c_per_km=zone.sst_gradient,
                chlorophyll_mg_m3=zone.chlorophyll_value,
                confidence=zone.confidence_score,
                status=zone.status,
            ),
        )
        features.append(feature)

    return PFZGeoJSONFeatureCollection(
        type="FeatureCollection",
        features=features,
        generated_at=datetime.now(timezone.utc),
        total_zones=len(features),
    )


@router.post(
    "/",
    response_model=PFZResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Ingest a detected PFZ point (Pipeline / Admin only)",
)
def create_pfz(
    latitude: float,
    longitude: float,
    sst_value: float,
    sst_gradient: float,
    chlorophyll_value: float,
    confidence_score: float,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Insert a verified PFZ point into the database."""
    pfz = PFZCoordinate(
        detection_date=date.today(),
        latitude=latitude,
        longitude=longitude,
        sst_value=sst_value,
        sst_gradient=sst_gradient,
        chlorophyll_value=chlorophyll_value,
        confidence_score=confidence_score,
        status="active",
    )
    db.add(pfz)
    db.commit()
    db.refresh(pfz)
    return pfz
