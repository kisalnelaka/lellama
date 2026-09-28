"""Lellama Marine Backend - FastAPI Application Entrypoint.

Provides marine geospatial analytics, Potential Fishing Zone (PFZ) intelligence,
hourly marine weather forecasting, and emergency SMS/push alerting for Sri Lankan coastal fishermen.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
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
