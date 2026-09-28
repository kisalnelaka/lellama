"""Unit tests for the oceanographic PFZ detection algorithm."""

from datetime import date, datetime
import numpy as np
import xarray as xr
from app.services.copernicus_service import CopernicusMarineService
from app.services.pfz_algorithm import PFZDetector


def test_pfz_detector_extracts_thermal_fronts():
    """Ensure the PFZDetector computes Sobel gradients and extracts valid fishing coordinates."""
    cmems = CopernicusMarineService()
    sst_da, chl_da = cmems._generate_synthetic_ocean_data(date_ref=datetime(2026, 9, 28))

    detector = PFZDetector(
        min_gradient_deg_per_km=0.015,
        min_chlorophyll_mg_m3=0.30,
        min_confidence=0.45,
    )
    zones = detector.detect_potential_fishing_zones(sst_da, chl_da, detection_date=date(2026, 9, 28))

    assert len(zones) >= 1
    top_zone = zones[0]

    # Verify physical bounds for Sri Lanka EEZ
    assert 4.5 <= top_zone["latitude"] <= 10.5
    assert 78.5 <= top_zone["longitude"] <= 83.5

    # Verify oceanographic parameters
    assert 20.0 < top_zone["sst_value"] < 35.0
    assert top_zone["sst_gradient"] > 0.01
    assert top_zone["chlorophyll_value"] >= 0.30
    assert 0.0 <= top_zone["confidence_score"] <= 1.0
    assert top_zone["status"] == "active"


def test_pfz_detector_geojson_conversion():
    """Ensure detected PFZs are serialized into an RFC 7946 compliant GeoJSON FeatureCollection."""
    cmems = CopernicusMarineService()
    sst_da, chl_da = cmems._generate_synthetic_ocean_data(date_ref=datetime(2026, 9, 28))

    detector = PFZDetector()
    zones = detector.detect_potential_fishing_zones(sst_da, chl_da)
    geojson = detector.to_geojson_feature_collection(zones)

    assert geojson["type"] == "FeatureCollection"
    assert "features" in geojson
    assert geojson["total_zones"] == len(zones)

    if zones:
        feat = geojson["features"][0]
        assert feat["type"] == "Feature"
        assert feat["geometry"]["type"] == "Point"
        # Coordinates must be [longitude, latitude] per RFC 7946
        assert len(feat["geometry"]["coordinates"]) == 2
        assert feat["properties"]["sst_celsius"] == zones[0]["sst_value"]
        assert feat["properties"]["confidence"] == zones[0]["confidence_score"]
