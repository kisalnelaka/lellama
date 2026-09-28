"""Unit and integration tests for fishing vessel management and telemetry."""

from fastapi.testclient import TestClient
from app.models.vessel import Vessel


def test_register_vessel(client: TestClient, auth_headers: dict):
    """Ensure an authenticated user can register a new fishing vessel."""
    payload = {
        "registration_number": "IMUL-A-1055-GLE",
        "vessel_name": "Ruhunu Kumari",
        "vessel_type": "multiday",
        "home_port": "Galle",
        "harbor_latitude": 6.0329,
        "harbor_longitude": 80.2168,
        "length_meters": 13.5,
    }
    response = client.post("/api/v1/vessels/", json=payload, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["registration_number"] == payload["registration_number"]
    assert data["vessel_name"] == payload["vessel_name"]
    assert data["home_port"] == "Galle"


def test_list_user_vessels(
    client: TestClient, auth_headers: dict, test_vessel: Vessel
):
    """Ensure user can list vessels belonging to their account."""
    response = client.get("/api/v1/vessels/", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
    assert any(v["id"] == test_vessel.id for v in data)


def test_ping_vessel_offshore_location(
    client: TestClient, auth_headers: dict, test_vessel: Vessel
):
    """Ensure vessel telemetry ping updates last known offshore coordinates and timestamp."""
    payload = {
        "latitude": 5.9200,
        "longitude": 80.4500,
        "is_at_sea": True,
    }
    response = client.post(
        f"/api/v1/vessels/{test_vessel.id}/ping",
        json=payload,
        headers=auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["last_known_latitude"] == 5.9200
    assert data["last_known_longitude"] == 80.4500
    assert data["is_currently_at_sea"] is True
    assert data["last_ping_time"] is not None
