"""Authentication endpoints: User registration, login, and profile inspection."""

from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.core.config import settings
from app.core.database import get_db
from app.core.limiter import limiter
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
)
from app.models.user import User
from app.schemas.user import UserCreate, UserLogin, UserResponse
from app.schemas.auth import TokenResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new fisherman or maritime user",
)
@limiter.limit(settings.RATE_LIMIT_AUTH)
def register_user(
    request: Request,
    payload: UserCreate,
    db: Session = Depends(get_db),
):
    """Register a new user account with validated E.164 phone and credentials."""
    existing_user = (
        db.query(User)
        .filter(
            or_(
                User.email == payload.email,
                User.phone_number == payload.phone_number,
            )
        )
        .first()
    )
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this email or phone number is already registered.",
        )

    user = User(
        email=payload.email,
        phone_number=payload.phone_number,
        hashed_password=hash_password(payload.password),
        full_name=payload.full_name,
        language_preference=payload.language_preference,
        role=payload.role,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Authenticate user and issue JWT bearer token",
)
@limiter.limit(settings.RATE_LIMIT_AUTH)
def login_user(
    request: Request,
    payload: UserLogin,
    db: Session = Depends(get_db),
):
    """Authenticate with registered email or Sri Lankan phone number (+94...)."""
    user = (
        db.query(User)
        .filter(
            or_(
                User.email == payload.username,
                User.phone_number == payload.username,
            )
        )
        .first()
    )

    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Verify your phone/email and password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account has been disabled.",
        )

    expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    token = create_access_token(
        subject=user.id,
        claims={
            "role": user.role,
            "lang": user.language_preference,
            "phone": user.phone_number,
        },
        expires_delta=expires_delta,
    )

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in_seconds=int(expires_delta.total_seconds()),
        user_id=user.id,
        full_name=user.full_name,
        language_preference=user.language_preference,
        role=user.role,
    )


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Retrieve profile of the currently authenticated user",
)
def get_current_user_profile(
    current_user: User = Depends(get_current_user),
):
    """Return sanitized profile data for the active authenticated bearer."""
    return current_user
