"""Tests for public web entrypoints: landing page, kinetic promo, and APK distribution."""

from fastapi.testclient import TestClient


def test_landing_page_root(client: TestClient):
    """Ensure GET / returns the public HTML landing page."""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers.get("content-type", "")
    assert "LELLAMA" in response.text
    assert "Copernicus" in response.text


def test_promo_video_route(client: TestClient):
    """Ensure GET /promo-video and /promo-video.html serve the kinetic promo video."""
    res_clean = client.get("/promo-video")
    assert res_clean.status_code == 200
    assert "Kinetic Typography" in res_clean.text

    res_html = client.get("/promo-video.html")
    assert res_html.status_code == 200
    assert "Kinetic Typography" in res_html.text


def test_apk_download_route(client: TestClient):
    """Ensure GET /downloads/lellama-v1.1.apk serves the Android binary."""
    response = client.get("/downloads/lellama-v1.1.apk")
    assert response.status_code == 200
    assert response.headers.get("content-type") == "application/vnd.android.package-archive"
    assert len(response.content) > 1000000  # Multi-megabyte APK

