"""Integration test for early-morning offline sync bundle generation."""

from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.vessel import Vessel
from app.models.pfz import PFZCoordinate


def test_download_offline_sync_bundle(
    client: TestClient,
    auth_headers: dict,
    test_vessel: Vessel,
    db_session: Session,
):
    """Ensure the sync endpoint bundles PFZs, weather forecasts, alerts, and tile manifests."""
    # Seed active PFZ
    pfz = PFZCoordinate(
        detection_date=date.today(),
        latitude=6.2000,
        longitude=80.1500,
        sst_value=28.1,
        sst_gradient=0.42,
        chlorophyll_value=2.1,
        confidence_score=0.92,
        status="active",
    )
    db_session.add(pfz)
    db_session.commit()

    response = client.get(
        f"/api/v1/sync/?vessel_id={test_vessel.id}",
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()

    # Verify root bundle structure
    assert "sync_timestamp" in data
    assert data["package_version"] == "v1.0-maritime"
    assert data["vessel_id"] == test_vessel.id
    assert data["language_preference"] == "si"

    # Verify PFZ GeoJSON payload
    pfz_collection = data["pfz_collection"]
    assert pfz_collection["type"] == "FeatureCollection"
    assert pfz_collection["total_zones"] >= 1

    # Verify weather series and tile manifest
    assert "weather_forecasts" in data
    assert "offline_tile_manifest" in data
    manifest = data["offline_tile_manifest"]
    assert manifest["region"] == "Sri Lanka EEZ"
    assert manifest["bounds"]["min_lat"] == 4.5
    assert manifest["bounds"]["max_lat"] == 10.5
