from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import os

from jose import jwt, JWTError


# ============================================================
# CONFIGURATION
# ============================================================

SECRET_KEY = os.getenv(
    "UNIATTEND_SECRET_KEY",
    "UNIATTEND_DEMO_SECRET_KEY_CHANGE_LATER"
)

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 2


# ============================================================
# PASSWORD HASHING
# ============================================================

def hash_password(password: str) -> str:
    """
    Hash a password using PBKDF2-HMAC-SHA256.
    """

    salt = os.urandom(16)
    iterations = 310000

    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        iterations,
    )

    return (
        f"pbkdf2_sha256$"
        f"{iterations}$"
        f"{salt.hex()}$"
        f"{digest.hex()}"
    )


def verify_password(password: str, stored: str) -> bool:
    """
    Verify a password against a stored PBKDF2 hash.
    """

    try:
        scheme, iterations, salt, digest = stored.split("$")

        if scheme != "pbkdf2_sha256":
            return False

        calculated = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            bytes.fromhex(salt),
            int(iterations),
        )

        return hmac.compare_digest(
            calculated,
            bytes.fromhex(digest),
        )

    except Exception:
        return False


# ============================================================
# JWT ACCESS TOKEN
# ============================================================

def create_access_token(uid: int, role: str) -> str:
    """
    Create a JWT access token.
    """

    now = datetime.now(timezone.utc)
    expires = now + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)

    payload = {
        "sub": str(uid),
        "role": role,
        "iat": now,
        "exp": expires,
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )


def decode_access_token(token: str):
    """
    Decode and validate a JWT access token.

    Returns:
        dict payload if valid
        None if invalid/expired
    """

    if not token:
        return None

    token = token.strip()

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )

        # Make sure the token contains a user ID.
        if "sub" not in payload:
            return None

        return payload

    except JWTError:
        return None

    except Exception:
        return None