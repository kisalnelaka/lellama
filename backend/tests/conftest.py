"""Pytest configuration and test database fixtures."""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.security import hash_password, create_access_token
from app.models.user import User
from app.models.vessel import Vessel
from app.main import app

# Test database: In-memory SQLite with single connection StaticPool
TEST_DATABASE_URL = "sqlite:///:memory:"

test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(
    autocommit=False, autoflush=False, bind=test_engine
)


@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    """Create all database tables for the test session."""
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def db_session():
    """Provide a clean, isolated database transaction for each test function."""
    connection = test_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session):
    """FastAPI TestClient with overridden get_db dependency."""

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db_session) -> User:
    """Create and return a fixture fisherman user."""
    user = User(
        email="chaminda@fisheries.lk",
        phone_number="+94771234567",
        hashed_password=hash_password("FisherPass123!"),
        full_name="Chaminda Perera",
        language_preference="si",
        role="fisher",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def user_token(test_user) -> str:
    """Generate a valid JWT bearer token for the test user."""
    return create_access_token(
        subject=test_user.id,
        claims={"role": test_user.role, "lang": test_user.language_preference},
    )


@pytest.fixture
def auth_headers(user_token) -> dict:
    """Return HTTP authorization header dict with the bearer token."""
    return {"Authorization": f"Bearer {user_token}"}


@pytest.fixture
def test_vessel(db_session, test_user) -> Vessel:
    """Create and return a fixture registered vessel."""
    vessel = Vessel(
        user_id=test_user.id,
        registration_number="IMUL-A-0982-KLT",
        vessel_name="Sayura Jaya 01",
        vessel_type="multiday",
        home_port="Beruwala",
        harbor_latitude=6.4789,
        harbor_longitude=79.9827,
        length_meters=14.2,
        last_known_latitude=6.3500,
        last_known_longitude=80.1200,
        is_currently_at_sea=True,
    )
    db_session.add(vessel)
    db_session.commit()
    db_session.refresh(vessel)
    return vessel
