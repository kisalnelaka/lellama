"""Potential Fishing Zone (PFZ) Detection Algorithm.

Identifies oceanographic thermal fronts from Sea Surface Temperature (SST) gradients,
intersects them with Chlorophyll-a biological hotspots, and yields discrete, high-confidence
GPS coordinates formatted as RFC 7946 GeoJSON points.
"""

from datetime import date, datetime, timezone
from typing import List, Dict, Any, Tuple, Optional
import logging
import numpy as np
import xarray as xr
from scipy.ndimage import sobel, maximum_filter

logger = logging.getLogger(__name__)


class PFZDetector:
    """Oceanographic computer vision engine for satellite-derived Potential Fishing Zones."""

    def __init__(
        self,
        min_gradient_deg_per_km: float = 0.015,
        min_chlorophyll_mg_m3: float = 0.30,
        min_confidence: float = 0.45,
        weight_sst: float = 0.55,
        weight_chl: float = 0.45,
    ):
        self.min_gradient_deg_per_km = min_gradient_deg_per_km
        self.min_chlorophyll_mg_m3 = min_chlorophyll_mg_m3
        self.min_confidence = min_confidence
        self.weight_sst = weight_sst
        self.weight_chl = weight_chl

    def detect_potential_fishing_zones(
        self,
        sst_da: xr.DataArray,
        chl_da: xr.DataArray,
        detection_date: Optional[date] = None,
    ) -> List[Dict[str, Any]]:
        """Execute thermal front edge-detection and chlorophyll intersection.

        Args:
            sst_da: 2D DataArray with coordinates (latitude, longitude) of SST in °C.
            chl_da: 2D DataArray with coordinates (latitude, longitude) of Chlorophyll in mg/m³.
            detection_date: Date of remote sensing observation.

        Returns:
            List of detected PFZ dictionaries with geospatial coordinates and oceanographic metrics.
        """
        det_date = detection_date or date.today()

        # 0. Spatial Grid Alignment
        # CMEMS SST and Chlorophyll often originate from different sensors with disparate resolutions
        if chl_da.shape != sst_da.shape:
            logger.info(
                "Interpolating Chlorophyll grid %s to match SST grid %s",
                chl_da.shape,
                sst_da.shape,
            )
            chl_da = chl_da.interp_like(sst_da, method="linear")

        # Extract coordinate vectors
        lats = sst_da.coords["latitude"].values
        lons = sst_da.coords["longitude"].values

        sst_grid = np.nan_to_num(sst_da.values, nan=28.0)
        chl_grid = np.nan_to_num(chl_da.values, nan=0.2)

        # 1. Physical Grid Resolution Calculation
        # Average pixel delta in degrees
        d_lat_deg = abs(lats[1] - lats[0]) if len(lats) > 1 else 0.1
        d_lon_deg = abs(lons[1] - lons[0]) if len(lons) > 1 else 0.1

        # 1 degree latitude ~ 111 km; 1 degree longitude at Sri Lankan latitude (7°N) ~ 110.2 km
        dy_km = d_lat_deg * 111.0
        dx_km = d_lon_deg * 110.2

        # 2. Thermal Front Detection via 2D Spatial Sobel Gradient
        # Horizontal and vertical gradient components
        grad_y = sobel(sst_grid, axis=0) / (8.0 * dy_km)
        grad_x = sobel(sst_grid, axis=1) / (8.0 * dx_km)
        gradient_magnitude = np.sqrt(grad_x**2 + grad_y**2)  # °C / km

        # 3. Normalization (Min-Max Scaling)
        g_min, g_max = np.min(gradient_magnitude), np.max(gradient_magnitude)
        norm_gradient = (
            (gradient_magnitude - g_min) / (g_max - g_min)
            if g_max > g_min
            else np.zeros_like(gradient_magnitude)
        )

        c_min, c_max = np.min(chl_grid), np.max(chl_grid)
        norm_chlorophyll = (
            (chl_grid - c_min) / (c_max - c_min)
            if c_max > c_min
            else np.zeros_like(chl_grid)
        )

        # 4. Thermal Front & Chlorophyll Intersection Index
        # A valid PFZ requires both an active thermal boundary AND sufficient phytoplankton
        valid_front_mask = gradient_magnitude >= self.min_gradient_deg_per_km
        valid_chl_mask = chl_grid >= self.min_chlorophyll_mg_m3
        combined_mask = valid_front_mask & valid_chl_mask

        composite_pfz_score = (
            self.weight_sst * norm_gradient + self.weight_chl * norm_chlorophyll
        )
        composite_pfz_score = np.where(combined_mask, composite_pfz_score, 0.0)

        # 5. Non-Maximum Suppression (NMS) Peak Finding
        # Use 3x3 window local maxima filter to isolate distinct centroid hotspots
        neighborhood = np.ones((3, 3), dtype=bool)
        local_max = (
            maximum_filter(composite_pfz_score, footprint=neighborhood)
            == composite_pfz_score
        )
        detected_peaks = local_max & (
            composite_pfz_score >= self.min_confidence
        )

        peak_y, peak_x = np.where(detected_peaks)

        results: List[Dict[str, Any]] = []
        for y, x in zip(peak_y, peak_x):
            lat = float(lats[y])
            lon = float(lons[x])
            conf = float(composite_pfz_score[y, x])
            sst_val = float(sst_grid[y, x])
            grad_val = float(gradient_magnitude[y, x])
            chl_val = float(chl_grid[y, x])

            results.append(
                {
                    "detection_date": det_date,
                    "latitude": round(lat, 4),
                    "longitude": round(lon, 4),
                    "sst_value": round(sst_val, 2),
                    "sst_gradient": round(grad_val, 3),
                    "chlorophyll_value": round(chl_val, 2),
                    "confidence_score": round(conf, 3),
                    "source_satellite": "CMEMS Sentinel-3 SST/OLCI Fusion",
                    "status": "active",
                    "metadata_json": {
                        "algorithm": "Sobel Thermal Front + Chlorophyll-a Overlap v1.0",
                        "gradient_norm": round(float(norm_gradient[y, x]), 3),
                        "chlorophyll_norm": round(
                            float(norm_chlorophyll[y, x]), 3
                        ),
                    },
                }
            )

        # Sort descending by confidence
        results.sort(key=lambda item: item["confidence_score"], reverse=True)
        logger.info(
            "PFZ algorithm completed: identified %d candidate fishing zones",
            len(results),
        )
        return results

    def to_geojson_feature_collection(
        self, pfz_list: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Convert detected PFZ points into an RFC 7946 compliant GeoJSON FeatureCollection."""
        features = []
        for zone in pfz_list:
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [zone["longitude"], zone["latitude"]],
                },
                "properties": {
                    "detection_date": str(zone["detection_date"]),
                    "sst_celsius": zone["sst_value"],
                    "sst_gradient_c_per_km": zone["sst_gradient"],
                    "chlorophyll_mg_m3": zone["chlorophyll_value"],
                    "confidence": zone["confidence_score"],
                    "status": zone.get("status", "active"),
                },
            }
            features.append(feature)

        return {
            "type": "FeatureCollection",
            "features": features,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "total_zones": len(features),
        }
