"""Unit and integration tests for authentication and user accounts."""

from fastapi.testclient import TestClient
from app.models.user import User


def test_register_fisherman_success(client: TestClient):
    """Ensure a new fisherman can register with standard Sri Lankan credentials."""
    payload = {
        "email": "sunil.fernando@mirissa.lk",
        "phone_number": "+94719876543",
        "password": "StrongPassword99!",
        "full_name": "Sunil Fernando",
        "language_preference": "si",
        "role": "fisher",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == payload["email"]
    assert data["phone_number"] == payload["phone_number"]
    assert data["language_preference"] == "si"
    assert "hashed_password" not in data


def test_register_duplicate_phone_rejected(client: TestClient, test_user: User):
    """Ensure duplicate phone numbers are rejected with 409 Conflict."""
    payload = {
        "email": "different.email@fisheries.lk",
        "phone_number": test_user.phone_number,  # Re-use existing phone
        "password": "Password123!",
        "full_name": "Duplicate Tester",
        "language_preference": "en",
        "role": "fisher",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 409
    assert "already registered" in response.json()["detail"]


def test_login_with_phone_number(client: TestClient, test_user: User):
    """Ensure fishermen can log in directly using their Sri Lankan phone number."""
    payload = {
        "username": test_user.phone_number,
        "password": "FisherPass123!",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user_id"] == test_user.id
    assert data["language_preference"] == "si"


def test_login_with_email(client: TestClient, test_user: User):
    """Ensure users can log in using their email address."""
    payload = {
        "username": test_user.email,
        "password": "FisherPass123!",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data


def test_login_invalid_password(client: TestClient, test_user: User):
    """Ensure invalid passwords receive a 401 Unauthorized response."""
    payload = {
        "username": test_user.email,
        "password": "WrongPassword!",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401


def test_get_current_user_profile(client: TestClient, auth_headers: dict, test_user: User):
    """Ensure /me endpoint returns profile when supplied with valid JWT bearer token."""
    response = client.get("/api/v1/auth/me", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == test_user.id
    assert data["email"] == test_user.email
    assert data["phone_number"] == test_user.phone_number


def test_get_current_user_unauthorized_without_token(client: TestClient):
    """Ensure unauthenticated requests are rejected with 401."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
