"""Unit and integration tests for PFZ coordinates, GeoJSON export, and weather forecasts."""

from datetime import datetime, timezone, date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.models.pfz import PFZCoordinate
from app.models.weather import WeatherCache


def test_pfz_geojson_export(client: TestClient, auth_headers: dict, db_session: Session):
    """Ensure active PFZs are rendered into an RFC 7946 GeoJSON FeatureCollection."""
    # Seed a sample PFZ off the southern coast of Sri Lanka (Dondra / Mirissa)
    pfz = PFZCoordinate(
        detection_date=date.today(),
        latitude=5.8200,
        longitude=80.6000,
        sst_value=28.4,
        sst_gradient=0.35,
        chlorophyll_value=1.85,
        confidence_score=0.88,
        status="active",
    )
    db_session.add(pfz)
    db_session.commit()

    response = client.get("/api/v1/pfz/geojson", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["type"] == "FeatureCollection"
    assert data["total_zones"] >= 1

    feature = data["features"][0]
    assert feature["type"] == "Feature"
    assert feature["geometry"]["type"] == "Point"
    # Verify [longitude, latitude] GeoJSON order
    assert feature["geometry"]["coordinates"] == [80.6000, 5.8200]
    assert feature["properties"]["sst_celsius"] == 28.4
    assert feature["properties"]["confidence"] == 0.88


def test_weather_cache_and_point_query(
    client: TestClient, auth_headers: dict, db_session: Session
):
    """Ensure weather forecasts can be ingested and queried by location."""
    now = datetime.now(timezone.utc)
    entry = WeatherCache(
        latitude=6.4800,
        longitude=79.9800,
        location_name="Beruwala Fishery Harbour",
        forecast_timestamp=now,
        valid_for_time=now + timedelta(hours=1),
        wave_height=1.8,
        wave_direction=210.0,
        wind_wave_height=0.9,
        swell_wave_height=1.4,
        ocean_current_velocity=0.45,
        ocean_current_direction=180.0,
        source="open-meteo",
        is_stale=False,
    )
    db_session.add(entry)
    db_session.commit()

    response = client.get(
        "/api/v1/weather/point?latitude=6.48&longitude=79.98",
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["latitude"] == 6.48
    assert len(data["forecasts"]) >= 1
    assert data["forecasts"][0]["wave_height"] == 1.8
    assert data["warning_active"] is False
