"""User schemas for registration, updates, profile inspection, and login."""

from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, EmailStr, Field, ConfigDict


class UserBase(BaseModel):
    """Base user attributes shared across input/output schemas."""

    email: EmailStr
    phone_number: str = Field(
        ...,
        pattern=r"^\+94[0-9]{9}$",
        description="Sri Lankan phone number in standard E.164 format (e.g., +94771234567)",
    )
    full_name: str = Field(..., min_length=2, max_length=255)
    language_preference: Literal["si", "ta", "en"] = "si"
    role: Literal["fisher", "captain", "coastguard", "admin"] = "fisher"


class UserCreate(UserBase):
    """Payload required to register a new user/fisherman."""

    password: str = Field(
        ..., min_length=8, description="Minimum 8-character password"
    )


class UserUpdate(BaseModel):
    """Payload for updating user profile or preferences."""

    full_name: Optional[str] = Field(None, min_length=2, max_length=255)
    phone_number: Optional[str] = Field(None, pattern=r"^\+94[0-9]{9}$")
    language_preference: Optional[Literal["si", "ta", "en"]] = None
    password: Optional[str] = Field(None, min_length=8)


class UserLogin(BaseModel):
    """Credentials required for user authentication (phone or email)."""

    username: str = Field(
        ..., description="User's registered email address or E.164 phone number"
    )
    password: str = Field(..., min_length=1)


class UserResponse(UserBase):
    """Sanitized user profile returned to clients."""

    id: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
