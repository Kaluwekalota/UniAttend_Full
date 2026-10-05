from typing import Optional

from pydantic import BaseModel, EmailStr, Field


# ============================================================
# REGISTRATION
# ============================================================

class RegisterRequest(BaseModel):
    full_name: str = Field(
        min_length=2,
        max_length=150,
    )

    email: EmailStr

    password: str = Field(
        min_length=6,
        max_length=128,
    )

    role: str

    student_id: Optional[str] = None
    staff_id: Optional[str] = None
    programme: Optional[str] = None
    department: Optional[str] = None


# ============================================================
# LOGIN
# ============================================================

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


# ============================================================
# TIMETABLE
# ============================================================

class TimetableCreate(BaseModel):
    course_id: int

    day: str

    start: str

    end: str

    room: Optional[str] = None

    group: Optional[str] = None

    class_mode: str = "PHYSICAL"

    # Classroom GPS coordinates
    latitude: Optional[float] = None

    longitude: Optional[float] = None

    # Allowed distance from classroom in metres
    allowed_radius: float = 50.0


# ============================================================
# ATTENDANCE MARKING
# ============================================================

class AttendanceMarkRequest(BaseModel):
    session_token: str

    student_id: int

    idempotency_key: str

    method: str = "QR+biometric"

    # Student's current GPS coordinates
    latitude: float

    longitude: float

