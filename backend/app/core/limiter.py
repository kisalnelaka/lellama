"""Rate limiting configuration using SlowAPI and client identifiers."""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Default limiter binding to remote client IP
limiter = Limiter(key_func=get_remote_address, default_limits=["120/minute"])
