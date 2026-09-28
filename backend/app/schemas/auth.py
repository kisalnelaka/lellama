"""Authentication token schemas."""

from typing import Optional
from pydantic import BaseModel


class TokenResponse(BaseModel):
    """Access token payload returned upon successful authentication."""

    access_token: str
    token_type: str = "bearer"
    expires_in_seconds: int
    user_id: str
    full_name: str
    language_preference: str
    role: str


class TokenPayload(BaseModel):
    """Decoded internal representation of JWT claims."""

    sub: str
    exp: int
    iat: int
    type: str = "access"
    role: Optional[str] = None
