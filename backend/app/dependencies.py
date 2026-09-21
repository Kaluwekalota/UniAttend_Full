from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from .database import get_db
from .models import User, AuditLog
from .security import decode_access_token


def current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """
    Get the currently authenticated user from the JWT token.
    """

    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Authentication required.",
        )

    if not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=401,
            detail="Invalid authorization header.",
        )

    token = authorization.split(" ", 1)[1].strip()

    if not token:
        raise HTTPException(
            status_code=401,
            detail="Invalid token.",
        )

    payload = decode_access_token(token)

    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token.",
        )

    try:
        user_id = int(payload["sub"])
    except (KeyError, TypeError, ValueError):
        raise HTTPException(
            status_code=401,
            detail="Invalid token payload.",
        )

    user = (
        db.query(User)
        .filter(
            User.id == user_id,
            User.is_active == True,
        )
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=401,
            detail="User not found.",
        )

    return user


def role(*roles):
    """
    Restrict an endpoint to one or more user roles.

    Example:
        Depends(role("admin"))
        Depends(role("lecturer"))
        Depends(role("lecturer", "admin"))
    """

    def dependency(user=Depends(current_user)):
        if user.role not in roles:
            raise HTTPException(
                status_code=403,
                detail="Insufficient permissions.",
            )

        return user

    return dependency


def audit(
    db: Session,
    user_id: int,
    action: str,
    details: str = "",
):
    """
    Record an action in the audit log.
    """

    log = AuditLog(
        user_id=user_id,
        action=action,
        details=details[:1000],
    )

    db.add(log)
    db.commit()