"""Application configuration and environment settings.

Provides centralized typed settings using Pydantic Settings management.
"""

from typing import List, Optional
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central configuration class for the Lellama Marine Backend."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # Project Information
    PROJECT_NAME: str = "Lellama Marine PFZ & Safety Platform"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Security & JWT Credentials
    SECRET_KEY: str = Field(
        default="insecure-dev-secret-key-change-in-production-marine-platform",
        description="HMAC secret key used for signing JWT tokens",
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 Hours for offshore maritime sessions

    # Database Configuration
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "lellama_admin"
    POSTGRES_PASSWORD: str = "secure_marine_password"
    POSTGRES_DB: str = "lellama_marine"
    DATABASE_URL: Optional[str] = None

    # Redis Configuration
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    REDIS_URL: str = "redis://localhost:6379/0"

    # Rate Limiting Policies
    RATE_LIMIT_DEFAULT: str = "60/minute"
    RATE_LIMIT_SYNC: str = "10/minute"
    RATE_LIMIT_AUTH: str = "15/minute"

    # Maritime Geographic Constants (Sri Lankan EEZ Bounding Box)
    # Sri Lanka EEZ approx: Lat 4.5°N - 10.5°N, Lon 78.5°E - 83.5°E
    SRI_LANKA_MIN_LAT: float = 4.5
    SRI_LANKA_MAX_LAT: float = 10.5
    SRI_LANKA_MIN_LON: float = 78.5
    SRI_LANKA_MAX_LON: float = 83.5

    # Marine Alerting Gateways
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_PHONE_NUMBER: Optional[str] = None
    FCM_SERVER_KEY: Optional[str] = None

    # Weather & Earth Observation API Credentials
    COPERNICUS_USERNAME: Optional[str] = None
    COPERNICUS_PASSWORD: Optional[str] = None
    STORMGLASS_API_KEY: Optional[str] = None

    # CORS Allowed Origins
    CORS_ORIGINS: List[str] = ["*"]

    def get_database_url(self) -> str:
        """Construct or return the active SQLAlchemy database URL."""
        if self.DATABASE_URL:
            return self.DATABASE_URL.strip("\"'")
        return (
            f"postgresql+psycopg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )



settings = Settings()
