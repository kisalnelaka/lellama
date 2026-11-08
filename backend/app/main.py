"""Lellama Marine Backend - FastAPI Application Entrypoint.

Provides marine geospatial analytics, Potential Fishing Zone (PFZ) intelligence,
hourly marine weather forecasting, and emergency SMS/push alerting for Sri Lankan coastal fishermen.
"""

from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI, Request, status, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.core.database import Base, engine
from app.core.limiter import limiter
from app.api.v1.router import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context for managing startup and shutdown routines."""
    # Ensure database schema is initialized if live database is reachable
    try:
        Base.metadata.create_all(bind=engine)
    except Exception:
        # Fallback when running in decoupled unit test environments
        pass
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=(
        "Mission-Critical Marine Intelligence & Safety Platform for Sri Lankan Coastal Fisheries. "
        "Integrates Copernicus Marine (CMEMS) thermal fronts/chlorophyll PFZ identification, "
        "Open-Meteo Marine ocean wave and current forecasting, and offline sync engines."
    ),
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

# SlowAPI Rate Limiting setup
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Cross-Origin Resource Sharing (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["System"])
@app.get(f"{settings.API_V1_STR}/health", tags=["System"])
def health_check():
    """Liveness probe reporting backend availability."""
    return {
        "status": "healthy",
        "service": "Lellama Marine API",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "coverage_zone": "Sri Lanka EEZ (EPSG:4326)",
    }



@app.get("/ready", tags=["System"])
@app.get(f"{settings.API_V1_STR}/ready", tags=["System"])
def readiness_check():
    """Readiness probe checking database and core connectivity."""
    try:
        from sqlalchemy import text

        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception as e:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "unhealthy", "database": str(e)},
        )

    return {
        "status": "ready",
        "database": db_status,
        "rate_limiting": "active",
    }


# Mount API v1 router
app.include_router(api_router, prefix=settings.API_V1_STR)

# Landing page and APK distribution routes
_candidate_landing_dirs = [
    Path(__file__).resolve().parent.parent.parent / "landing",
    Path(__file__).resolve().parent.parent / "landing",
    Path("/app/landing"),
]
landing_dir = next((d for d in _candidate_landing_dirs if d.is_dir()), None)

if landing_dir:
    app.mount("/static-landing", StaticFiles(directory=str(landing_dir)), name="landing-static")

    @app.get("/", include_in_schema=False)
    async def serve_landing_index():
        index_file = landing_dir / "index.html"
        if index_file.is_file():
            return FileResponse(index_file)
        return {"service": settings.PROJECT_NAME, "status": "running"}

    @app.get("/promo-video", include_in_schema=False)
    @app.get("/promo-video.html", include_in_schema=False)
    async def serve_promo_video():
        promo_file = landing_dir / "promo-video.html"
        if promo_file.is_file():
            return FileResponse(promo_file)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Promo video not found")


_candidate_apk_paths = [
    Path(__file__).resolve().parent.parent.parent / "mobile/build/app/outputs/flutter-apk/app-release.apk",
    Path(__file__).resolve().parent.parent / "mobile/build/app/outputs/flutter-apk/app-release.apk",
    Path("/app/downloads/lellama-v1.1.apk"),
    Path(__file__).resolve().parent.parent.parent / "mobile/build/app/outputs/apk/release/app-release.apk",
]
apk_path = next((p for p in _candidate_apk_paths if p.is_file()), None)


@app.get("/downloads/lellama-v1.1.apk", include_in_schema=False)
@app.get("/downloads/app-release.apk", include_in_schema=False)
async def download_apk():
    """Serve the compiled Android release APK for offshore coastal fishermen."""
    if apk_path and apk_path.is_file():
        return FileResponse(
            apk_path,
            media_type="application/vnd.android.package-archive",
            filename="lellama-v1.1.apk",
        )
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Mobile APK binary is currently building or not present on this host.",
    )

