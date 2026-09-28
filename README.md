# LELLAMA (ලෙල්ලම / லெல்லம) — Sri Lanka Marine PFZ & Safety Platform

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688.svg?logo=fastapi)](https://fastapi.tiangolo.com)
[![PostGIS](https://img.shields.io/badge/PostGIS-16--3.4-336791.svg?logo=postgresql)](https://postgis.net)
[![Redis](https://img.shields.io/badge/Redis-7.2-DC382D.svg?logo=redis)](https://redis.io)
[![Tests](https://img.shields.io/badge/Pytest-14%20Passed-brightgreen.svg)]()

> **Mission-critical, offline-first marine intelligence and safety platform engineered for Sri Lankan artisanal and multiday offshore fishermen.**

---

## 1. Executive Summary

Off the coast of Sri Lanka, artisanal and multiday fishing vessels routinely venture 20km to 150km beyond territorial waters into the Exclusive Economic Zone (EEZ). In these zones, high-speed cellular coverage (4G/LTE) diminishes completely.

**LELLAMA** solves two foundational challenges:
1. **Fuel-Efficient Fishing:** Daily thermal front detection and chlorophyll-a concentrations (Copernicus Marine / CMEMS) pinpoint **Potential Fishing Zones (PFZs)** to slash fuel consumption and transit time.
2. **Offshore Life Safety:** Real-time wave dynamics (Open-Meteo Marine) identify squalls and dangerous sea states (>2.5m swells), delivering push alerts onshore and failing over to **2G SMS broadcasts** when vessels are offshore.

---

## 2. System Architecture

```mermaid
graph TD
    subgraph Onshore ["Early-Morning Onshore Pre-Departure (Wi-Fi / 4G)"]
        MobileApp["Mobile App (Flutter / React Native)<br/>High-Contrast Daylight UI<br/>(Sinhala / Tamil / English)"]
        LocalCache["Local SQLite / Offline Store<br/>- Vector Map Tiles (Zoom 6-12)<br/>- PFZ GeoJSON Coordinates<br/>- 24h Hourly Marine Forecasts"]
        MobileApp <--> LocalCache
    end

    subgraph BackendInfrastructure ["Lellama Backend Infrastructure"]
        FastAPI["FastAPI Maritime Gateway<br/>JWT Auth & SlowAPI Rate Limiting"]
        PostGIS["PostgreSQL 16 + PostGIS<br/>Spatial Storage (WGS84 EPSG:4326)"]
        Redis["Redis 7.2<br/>Cache & Celery Broker"]
        CeleryWorker["Celery Pipelines<br/>- Copernicus CMEMS Ingestion<br/>- Thermal Front + Chlorophyll PFZ Algorithm<br/>- Open-Meteo Marine Weather Poller"]
        AlertEngine["Alerting Engine<br/>Threshold Evaluator & SMS Fallback"]
    end

    subgraph Offshore ["Offshore Marine Reality (>20km off Sri Lankan Coast)"]
        Vessel["Fishing Vessel at Sea<br/>(Sayura Jaya / Multi-day Craft)"]
        SMSGateway["Twilio SMS Gateway /<br/>Sri Lankan Telecom 2G Cell Towers"]
    end

    MobileApp -- "GET /api/v1/sync (Pre-departure Bundle)" --> FastAPI
    FastAPI <--> PostGIS
    FastAPI <--> Redis
    CeleryWorker <--> Redis
    CeleryWorker --> PostGIS
    AlertEngine --> PostGIS
    AlertEngine -- "Weak 2G Network Broadcast" --> SMSGateway
    SMSGateway -- "Trilingual Emergency SMS" --> Vessel
```

---

## 3. Database Schema (Phase 1)

All spatial geometries are indexed and projected in **WGS84 (EPSG:4326)** covering the Sri Lankan Exclusive Economic Zone (4.5°N - 10.5°N, 78.5°E - 83.5°E):

| Table | Purpose | Key Attributes & Spatial Fields |
| :--- | :--- | :--- |
| `users` | Fishermen, captains, and maritime authorities | `id` (UUID), `phone_number` (E.164 e.g. `+9477...`), `language_preference` (`si`/`ta`/`en`), `role` (`fisher`/`captain`/`coastguard`/`admin`) |
| `vessels` | Multi-day and dayboat vessel registration | `registration_number` (e.g. `IMUL-A-0982-KLT`), `home_port`, `harbor_latitude`, `harbor_longitude`, `last_known_latitude`, `last_known_longitude`, `last_ping_time` |
| `pfz_coordinates` | Detected Potential Fishing Zones | `detection_date`, `latitude`, `longitude`, `sst_value` (°C), `sst_gradient` (°C/km), `chlorophyll_value` (mg/m³), `confidence_score` (0.0 - 1.0) |
| `weather_caches` | Hourly ocean wave and current forecasts | `forecast_timestamp`, `valid_for_time`, `wave_height` (m), `wave_direction` (°), `wind_wave_height` (m), `swell_wave_height` (m), `ocean_current_velocity` (m/s) |
| `alert_logs` | Trilingual safety warning audit trail | `alert_level` (`advisory`/`warning`/`danger`), `channel` (`push`/`sms`/`hybrid`), `message_sinhala`, `message_tamil`, `message_english`, `delivery_status` |

---

## 4. API Endpoints Specification

All endpoints are mounted under `/api/v1` and protected with JWT Bearer authentication:

* **Authentication (`/api/v1/auth`)**
  * `POST /register` — Register user with E.164 Sri Lankan phone validation (`+947...`) and bcrypt hashing.
  * `POST /login` — Authenticate using phone number or email; issues JWT with 24-hour offshore validity.
  * `GET /me` — Retrieve sanitized active profile.
* **Vessels (`/api/v1/vessels`)**
  * `POST /` — Register fishing vessel with harbor coordinates.
  * `GET /` — List registered vessels under authenticated account.
  * `POST /{vessel_id}/ping` — Record offshore GPS coordinates and update ping telemetry.
* **Potential Fishing Zones (`/api/v1/pfz`)**
  * `GET /` — List active PFZs filtered by date and confidence threshold.
  * `GET /geojson` — RFC 7946 compliant GeoJSON FeatureCollection formatted for direct vector rendering.
* **Marine Weather (`/api/v1/weather`)**
  * `GET /point` — Retrieve 24-48 hour hourly forecast series for a specific coordinate or harbor.
* **Offline Sync Engine (`/api/v1/sync`)**
  * `GET /` — Bundle active PFZ GeoJSON, 24-hour weather forecasts (for home port and top PFZs), active alerts, and map tile caching manifests in a single payload.

---

## 5. Development & Deployment Setup

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- PostgreSQL 16 with PostGIS extension (or Docker container)
- Redis 7.2 (or Docker container)

### Quick Start (Local Development)

```bash
# 1. Clone repository and navigate to backend
cd backend

# 2. Initialize Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 3. Install production and test dependencies
pip install -r requirements.txt

# 4. Configure environment
cp .env.example .env

# 5. Run test suite
pytest -v
```

### Docker Compose Deployment

```bash
# Launch PostGIS, Redis, FastAPI Backend, and Celery pipelines
docker compose up -d --build

# Inspect running containers
docker compose ps

# Access interactive Swagger API documentation
open http://localhost:8000/api/v1/docs
```

---

## 6. Phase 1 Verification Results

The automated test suite verifies API security, data isolation, rate limiting, and bundle generation:

```
tests/test_auth.py::test_register_fisherman_success PASSED               [  7%]
tests/test_auth.py::test_register_duplicate_phone_rejected PASSED        [ 14%]
tests/test_auth.py::test_login_with_phone_number PASSED                  [ 21%]
tests/test_auth.py::test_login_with_email PASSED                         [ 28%]
tests/test_auth.py::test_login_invalid_password PASSED                   [ 35%]
tests/test_auth.py::test_get_current_user_profile PASSED                 [ 42%]
tests/test_auth.py::test_get_current_user_unauthorized_without_token PASSED [ 50%]
tests/test_pfz_and_weather.py::test_pfz_geojson_export PASSED            [ 57%]
tests/test_pfz_and_weather.py::test_weather_cache_and_point_query PASSED [ 64%]
tests/test_rate_limiter.py::test_rate_limiter_allows_normal_traffic PASSED [ 71%]
tests/test_sync.py::test_download_offline_sync_bundle PASSED             [ 78%]
tests/test_vessels.py::test_register_vessel PASSED                       [ 85%]
tests/test_vessels.py::test_list_user_vessels PASSED                     [ 92%]
tests/test_vessels.py::test_ping_vessel_offshore_location PASSED         [100%]

======================== 14 passed, 4 warnings in 3.70s ========================
```
