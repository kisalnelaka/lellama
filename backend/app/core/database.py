"""Database session management and engine configuration.

Provides declarative Base, engine initialization with connection pooling,
and FastAPI dependency injection for request-scoped database sessions.
"""

from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from app.core.config import settings

# Construct the database URL from settings
db_url = settings.get_database_url()

# Configure engine kwargs depending on dialect
connect_args = {}
engine_kwargs = {"echo": False}

if db_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False
else:
    # Production PostgreSQL connection pool optimization
    engine_kwargs.update(
        {
            "pool_size": 10,
            "max_overflow": 20,
            "pool_pre_ping": True,
            "pool_recycle": 1800,
        }
    )

engine = create_engine(db_url, connect_args=connect_args, **engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """Provide a transactional database session per request.

    Ensures rollback on unhandled exceptions and deterministic session closure.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
