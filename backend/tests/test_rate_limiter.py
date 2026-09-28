"""Unit test for API rate limiter enforcement."""

from fastapi.testclient import TestClient


def test_rate_limiter_allows_normal_traffic(client: TestClient):
    """Ensure standard legitimate request volume succeeds."""
    for _ in range(5):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
