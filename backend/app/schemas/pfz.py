"""Potential Fishing Zone (PFZ) schemas and GeoJSON structures."""

from datetime import date, datetime
from typing import List, Optional, Dict, Any, Literal
from pydantic import BaseModel, Field, ConfigDict


class PFZResponse(BaseModel):
    """Individual PFZ coordinate entity."""

    id: str
    detection_date: date
    generated_at: datetime
    source_satellite: str
    latitude: float
    longitude: float
    sst_value: float
    sst_gradient: float
    chlorophyll_value: float
    confidence_score: float
    status: str
    metadata_json: Optional[Dict[str, Any]] = None

    model_config = ConfigDict(from_attributes=True)


class GeoJSONGeometryPoint(BaseModel):
    """GeoJSON Point geometry (longitude, latitude)."""

    type: Literal["Point"] = "Point"
    coordinates: List[float] = Field(
        ..., description="[longitude, latitude] array per RFC 7946"
    )


class PFZGeoJSONProperties(BaseModel):
    """Properties payload for PFZ GeoJSON feature."""

    id: str
    detection_date: str
    sst_celsius: float
    sst_gradient_c_per_km: float
    chlorophyll_mg_m3: float
    confidence: float
    status: str


class PFZGeoJSONFeature(BaseModel):
    """GeoJSON Feature representation of a PFZ coordinate."""

    type: Literal["Feature"] = "Feature"
    geometry: GeoJSONGeometryPoint
    properties: PFZGeoJSONProperties


class PFZGeoJSONFeatureCollection(BaseModel):
    """RFC 7946 GeoJSON FeatureCollection containing all active PFZ points."""

    type: Literal["FeatureCollection"] = "FeatureCollection"
    features: List[PFZGeoJSONFeature]
    generated_at: datetime
    total_zones: int
