"""SQLAlchemy database model for Potential Fishing Zones (PFZs)."""

import uuid
from datetime import datetime, timezone, date
from sqlalchemy import Column, String, Float, DateTime, Date, JSON
from app.core.database import Base


class PFZCoordinate(Base):
    """Potential Fishing Zone entity computed from satellite remote sensing data."""

    __tablename__ = "pfz_coordinates"

    id = Column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    detection_date = Column(Date, default=date.today, nullable=False, index=True)
    generated_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    source_satellite = Column(
        String(128), default="CMEMS SST/Chlorophyll-A Fusion", nullable=False
    )

    # Core centroid coordinate (WGS84)
    latitude = Column(Float, nullable=False, index=True)
    longitude = Column(Float, nullable=False, index=True)

    # Oceanographic measurements
    sst_value = Column(Float, nullable=False)  # Sea Surface Temperature in Celsius
    sst_gradient = Column(
        Float, nullable=False
    )  # Horizontal gradient magnitude (°C / km)
    chlorophyll_value = Column(
        Float, nullable=False
    )  # Chlorophyll-a concentration in mg/m³
    confidence_score = Column(
        Float, nullable=False
    )  # Normalized 0.0 - 1.0 confidence indicator

    status = Column(
        String(32), default="active", nullable=False, index=True
    )  # 'active', 'expired', 'archived'

    # Extensible GeoJSON/raster metadata
    metadata_json = Column(JSON, nullable=True)

    created_at = Column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )

    def __repr__(self) -> str:
        return (
            f"<PFZ {self.latitude:.4f}N, {self.longitude:.4f}E - "
            f"Confidence: {self.confidence_score:.2f} (Date: {self.detection_date})>"
        )
