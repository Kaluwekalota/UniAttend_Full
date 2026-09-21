from datetime import datetime, timedelta
import secrets

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from .database import Base, engine, get_db
from .models import (
    User,
    Course,
    Timetable,
    AttendanceSession,
    Attendance,
)
from .schemas import (
    RegisterRequest,
    LoginRequest,
    AttendanceMarkRequest,
)
from .security import (
    hash_password,
    verify_password,
    create_access_token,
)
from .dependencies import (
    current_user,
)

from .academic_features import (
    router as academic_router,
    user_timetable_router,
)


# ============================================================
# DATABASE
# ============================================================

Base.metadata.create_all(bind=engine)


# ============================================================
# FASTAPI APPLICATION
# ============================================================

app = FastAPI(
    title="UniAttend API",
    version="2.1",
    description="University attendance management system",
)


# ============================================================
# CORS
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# ACADEMIC / ADMIN ROUTER
# ============================================================

app.include_router(
    academic_router,
    prefix="/admin",
    tags=["Admin & Academic"],
)

app.include_router(user_timetable_router)


# ============================================================
# BASIC ROUTES
# ============================================================

@app.get("/")
def root():
    return {
        "success": True,
        "message": "UniAttend API is running.",
        "version": "2.1",
    }


@app.get("/health")
def health():
    return {
        "success": True,
        "status": "healthy",
        "service": "UniAttend API",
    }


# ============================================================
# AUTHENTICATION
# ============================================================

@app.post("/auth/register")
def register(
    data: RegisterRequest,
    db: Session = Depends(get_db),
):
    """
    Register a student or lecturer.
    """

    email = data.email.strip().lower()

    existing_email = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if existing_email:
        raise HTTPException(
            status_code=400,
            detail="An account with this email already exists.",
        )

    role = data.role.strip().lower()

    if role not in ["student", "lecturer", "admin"]:
        raise HTTPException(
            status_code=400,
            detail="Role must be student, lecturer, or admin.",
        )

    if len(data.password) < 6:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 6 characters.",
        )

    student_id = None
    staff_id = None

    if role == "student":
        if not data.student_id:
            raise HTTPException(
                status_code=400,
                detail="Student ID is required for student accounts.",
            )

        student_id = data.student_id.strip()

        existing_student = (
            db.query(User)
            .filter(User.student_id == student_id)
            .first()
        )

        if existing_student:
            raise HTTPException(
                status_code=400,
                detail="This student ID is already registered.",
            )

    if role == "lecturer":
        if data.staff_id:
            staff_id = data.staff_id.strip()

            existing_staff = (
                db.query(User)
                .filter(User.staff_id == staff_id)
                .first()
            )

            if existing_staff:
                raise HTTPException(
                    status_code=400,
                    detail="This staff ID is already registered.",
                )

    user = User(
        full_name=data.full_name.strip(),
        email=email,
        password_hash=hash_password(data.password),
        role=role,
        student_id=student_id,
        staff_id=staff_id,
        programme=(
            data.programme.strip()
            if data.programme
            else None
        ),
        department=(
            data.department.strip()
            if data.department
            else None
        ),
        is_active=True,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return {
        "success": True,
        "message": "Registration successful.",
        "user": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "role": user.role,
            "student_id": user.student_id,
            "staff_id": user.staff_id,
            "programme": user.programme,
            "department": user.department,
        },
    }


# ============================================================
# LOGIN
# ============================================================

@app.post("/auth/login")
def login(
    data: LoginRequest,
    db: Session = Depends(get_db),
):
    """
    Login student, lecturer, or admin.

    IMPORTANT:
    The current security.py uses:

        create_access_token(user_id, role)

    Therefore the token is created using two arguments.
    """

    email = data.email.strip().lower()

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password.",
        )

    if not verify_password(
        data.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="This account has been disabled.",
        )

    # ========================================================
    # IMPORTANT TOKEN CREATION
    # ========================================================

    token = create_access_token(
        str(user.id),
        user.role,
    )

    return {
        "success": True,
        "message": "Login successful.",
        "access_token": token,
        "token_type": "bearer",

        # Flutter compatibility
        "token": token,

        "user": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "role": user.role,
            "student_id": user.student_id,
            "staff_id": user.staff_id,
            "programme": user.programme,
            "department": user.department,
        },
    }


# ============================================================
# CURRENT USER
# ============================================================

@app.get("/auth/me")
def get_me(
    user: User = Depends(current_user),
):
    return {
        "success": True,
        "user": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "role": user.role,
            "student_id": user.student_id,
            "staff_id": user.staff_id,
            "programme": user.programme,
            "department": user.department,
            "profile_picture": user.profile_picture,
            "is_active": user.is_active,
        },
    }


# ============================================================
# LECTURER TODAY
# ============================================================
#
# This route is kept for compatibility with older Flutter code.
# The new LecturerDashboard does NOT depend on this route.
#

@app.get("/lecturer/today")
def lecturer_today(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role != "lecturer":
        raise HTTPException(
            status_code=403,
            detail="Lecturer access required.",
        )

    today = datetime.now().strftime("%A")

    timetable = (
        db.query(Timetable)
        .join(Course)
        .filter(
            Course.lecturer_id == user.id,
            Timetable.is_active == True,
            Timetable.day.ilike(today),
        )
        .all()
    )

    results = []

    for item in timetable:
        results.append({
            "id": item.id,
            "course_id": item.course_id,
            "course_code": item.course.code,
            "course_title": item.course.title,
            "programme": item.course.programme,
            "lecturer_id": item.course.lecturer_id,
            "lecturer_name": (
                item.course.lecturer.full_name
                if item.course.lecturer
                else None
            ),
            "day": item.day,
            "start": item.start,
            "end": item.end,
            "room": item.room,
            "group": item.group_name,
            "block": item.block,
            "class_mode": item.class_mode,
            "is_active": item.is_active,
        })

    return results


# ============================================================
# CREATE ATTENDANCE SESSION / QR
# ============================================================

@app.post("/attendance/sessions")
def create_attendance_session(
    course_id: int,
    timetable_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """
    Lecturer generates an attendance QR code.

    Prototype behaviour:
    - No current-time restriction.
    - No enrollment requirement.
    - Timetable must exist.
    - Lecturer must own the course.
    """

    if user.role != "lecturer":
        raise HTTPException(
            status_code=403,
            detail="Only lecturers can generate attendance QR codes.",
        )

    course = (
        db.query(Course)
        .filter(Course.id == course_id)
        .first()
    )

    if course is None:
        raise HTTPException(
            status_code=404,
            detail="Course not found.",
        )

    if course.lecturer_id != user.id:
        raise HTTPException(
            status_code=403,
            detail="This course is not assigned to your lecturer account.",
        )

    timetable = (
        db.query(Timetable)
        .filter(
            Timetable.id == timetable_id,
            Timetable.course_id == course_id,
            Timetable.is_active == True,
        )
        .first()
    )

    if timetable is None:
        raise HTTPException(
            status_code=404,
            detail="Timetable entry not found for this course.",
        )

    # --------------------------------------------------------
    # Close any previous active session for this timetable
    # --------------------------------------------------------

    previous_sessions = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.timetable_id == timetable.id,
            AttendanceSession.is_active == True,
        )
        .all()
    )

    for old_session in previous_sessions:
        old_session.is_active = False

    # --------------------------------------------------------
    # Generate secure QR token
    # --------------------------------------------------------

    qr_token = secrets.token_urlsafe(32)

    now = datetime.utcnow()

    # QR remains valid for 5 minutes.
    expires_at = now + timedelta(minutes=5)

    # Class end time is kept separately.
    class_end_at = expires_at

    session = AttendanceSession(
        timetable_id=timetable.id,
        course_id=course.id,
        lecturer_id=user.id,
        token=qr_token,
        created_at=now,
        expires_at=expires_at,
        class_end_at=class_end_at,
        is_active=True,
        session_type=(
            timetable.class_mode
            if timetable.class_mode
            else "PHYSICAL"
        ),
    )

    db.add(session)
    db.commit()
    db.refresh(session)

    return {
        "success": True,
        "message": "Attendance QR generated successfully.",

        "session_id": session.id,

        # This is the value Flutter converts into the QR image.
        "token": session.token,

        "course_id": course.id,
        "course_code": course.code,
        "course_title": course.title,

        "timetable_id": timetable.id,

        "day": timetable.day,
        "start": timetable.start,
        "end": timetable.end,
        "room": timetable.room,
        "group": timetable.group_name,
        "block": timetable.block,

        "session_type": session.session_type,

        "created_at": session.created_at.isoformat(),
        "expires_at": session.expires_at.isoformat(),

        "expires_in": 300,
    }


# ============================================================
# ROTATE QR TOKEN
# ============================================================

@app.post("/attendance/sessions/{session_id}/rotate")
def rotate_qr(
    session_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role != "lecturer":
        raise HTTPException(
            status_code=403,
            detail="Only lecturers can rotate QR codes.",
        )

    session = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.id == session_id
        )
        .first()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="Attendance session not found.",
        )

    if session.lecturer_id != user.id:
        raise HTTPException(
            status_code=403,
            detail="You do not own this attendance session.",
        )

    if not session.is_active:
        raise HTTPException(
            status_code=400,
            detail="This attendance session is no longer active.",
        )

    new_token = secrets.token_urlsafe(32)

    now = datetime.utcnow()
    expires_at = now + timedelta(minutes=5)

    session.token = new_token
    session.created_at = now
    session.expires_at = expires_at

    db.commit()
    db.refresh(session)

    return {
        "success": True,
        "message": "QR code rotated successfully.",
        "session_id": session.id,
        "token": session.token,
        "expires_at": session.expires_at.isoformat(),
        "expires_in": 300,
    }


# ============================================================
# END ATTENDANCE SESSION
# ============================================================

@app.post("/attendance/sessions/{session_id}/end")
def end_attendance_session(
    session_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role != "lecturer":
        raise HTTPException(
            status_code=403,
            detail="Only lecturers can end attendance sessions.",
        )

    session = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.id == session_id
        )
        .first()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="Attendance session not found.",
        )

    if session.lecturer_id != user.id:
        raise HTTPException(
            status_code=403,
            detail="You do not own this attendance session.",
        )

    session.is_active = False

    db.commit()

    return {
        "success": True,
        "message": "Attendance session ended.",
        "session_id": session.id,
    }


# ============================================================
# LIVE ATTENDANCE FOR LECTURER
# ============================================================

@app.get("/attendance/session/{session_id}/students")
def live_students(
    session_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role != "lecturer":
        raise HTTPException(
            status_code=403,
            detail="Only lecturers can view live attendance.",
        )

    session = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.id == session_id
        )
        .first()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="Attendance session not found.",
        )

    if session.lecturer_id != user.id:
        raise HTTPException(
            status_code=403,
            detail="You do not own this attendance session.",
        )

    records = (
        db.query(Attendance)
        .filter(
            Attendance.session_id == session_id
        )
        .order_by(
            Attendance.marked_at.asc()
        )
        .all()
    )

    result = []

    for record in records:
        student = record.student

        result.append({
            "attendance_id": record.id,
            "student_id": student.id,
            "student_number": student.student_id,
            "student_name": student.full_name,
            "full_name": student.full_name,
            "email": student.email,
            "marked_at": record.marked_at.isoformat(),
            "method": record.method,
        })

    return result


# ============================================================
# MARK ATTENDANCE
# ============================================================

@app.post("/attendance/mark")
def mark_attendance(
    data: AttendanceMarkRequest,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """
    Student scans lecturer QR and marks attendance.

    Prototype workflow:

        QR Scan
           ↓
        Biometric verification in Flutter
           ↓
        API attendance mark
           ↓
        Duplicate check
           ↓
        Attendance saved
    """

    if user.role != "student":
        raise HTTPException(
            status_code=403,
            detail="Only students can mark attendance.",
        )

    # --------------------------------------------------------
    # Find QR attendance session
    # --------------------------------------------------------

    session = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.token == data.session_token
        )
        .first()
    )

    if session is None:
        raise HTTPException(
            status_code=404,
            detail="Invalid attendance QR code.",
        )

    # --------------------------------------------------------
    # Make sure session is active
    # --------------------------------------------------------

    if not session.is_active:
        raise HTTPException(
            status_code=400,
            detail="This attendance session has ended.",
        )

    # --------------------------------------------------------
    # Check QR expiry
    # --------------------------------------------------------

    now = datetime.utcnow()

    if now > session.expires_at:
        session.is_active = False
        db.commit()

        raise HTTPException(
            status_code=400,
            detail="This attendance QR code has expired.",
        )

    # --------------------------------------------------------
    # Student ID
    # --------------------------------------------------------

    student_id = data.student_id

    if student_id != user.id:
        raise HTTPException(
            status_code=403,
            detail="You can only mark attendance for your own account.",
        )

    # --------------------------------------------------------
    # DUPLICATE ATTENDANCE CHECK
    # --------------------------------------------------------

    existing = (
        db.query(Attendance)
        .filter(
            Attendance.session_id == session.id,
            Attendance.student_id == user.id,
        )
        .first()
    )

    if existing:
        return {
            "success": False,
            "already_recorded": True,
            "message": "Attendance has already been recorded for this class.",
            "attendance_id": existing.id,
            "marked_at": existing.marked_at.isoformat(),
        }

    # --------------------------------------------------------
    # IDEMPOTENCY CHECK
    # --------------------------------------------------------

    existing_key = (
        db.query(Attendance)
        .filter(
            Attendance.idempotency_key
            == data.idempotency_key
        )
        .first()
    )

    if existing_key:
        return {
            "success": False,
            "already_recorded": True,
            "message": "This attendance request has already been processed.",
            "attendance_id": existing_key.id,
            "marked_at": existing_key.marked_at.isoformat(),
        }

    # --------------------------------------------------------
    # CREATE ATTENDANCE RECORD
    # --------------------------------------------------------

    attendance = Attendance(
        session_id=session.id,
        student_id=user.id,
        idempotency_key=data.idempotency_key,
        method=(
            data.method
            if data.method
            else "QR+biometric"
        ),
        marked_at=now,
    )

    db.add(attendance)

    try:
        db.commit()
        db.refresh(attendance)

    except Exception:
        db.rollback()

        # Another request may have created the same
        # attendance record at almost the same time.

        duplicate = (
            db.query(Attendance)
            .filter(
                Attendance.session_id == session.id,
                Attendance.student_id == user.id,
            )
            .first()
        )

        if duplicate:
            return {
                "success": False,
                "already_recorded": True,
                "message": "Attendance has already been recorded.",
                "attendance_id": duplicate.id,
                "marked_at": duplicate.marked_at.isoformat(),
            }

        raise HTTPException(
            status_code=500,
            detail="Unable to save attendance.",
        )

    return {
        "success": True,
        "already_recorded": False,
        "message": "Attendance marked successfully.",
        "attendance_id": attendance.id,
        "session_id": session.id,
        "student_id": user.id,
        "course_id": session.course_id,
        "marked_at": attendance.marked_at.isoformat(),
        "method": attendance.method,
    }


# ============================================================
# STUDENT ATTENDANCE HISTORY
# ============================================================

@app.get("/attendance/my")
def my_attendance(
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role != "student":
        raise HTTPException(
            status_code=403,
            detail="Only students can access their attendance.",
        )

    records = (
        db.query(Attendance)
        .filter(
            Attendance.student_id == user.id
        )
        .order_by(
            Attendance.marked_at.desc()
        )
        .all()
    )

    result = []

    for record in records:
        session = record.session

        course = None

        if session:
            course = (
                db.query(Course)
                .filter(
                    Course.id == session.course_id
                )
                .first()
            )

        timetable = None

        if session:
            timetable = (
                db.query(Timetable)
                .filter(
                    Timetable.id == session.timetable_id
                )
                .first()
            )

        result.append({
            "attendance_id": record.id,
            "session_id": (
                session.id
                if session
                else None
            ),
            "course_id": (
                course.id
                if course
                else None
            ),
            "course_code": (
                course.code
                if course
                else None
            ),
            "course_title": (
                course.title
                if course
                else None
            ),
            "day": (
                timetable.day
                if timetable
                else None
            ),
            "start": (
                timetable.start
                if timetable
                else None
            ),
            "end": (
                timetable.end
                if timetable
                else None
            ),
            "room": (
                timetable.room
                if timetable
                else None
            ),
            "marked_at": record.marked_at.isoformat(),
            "method": record.method,
        })

    return result


# ============================================================
# ADMIN STATUS
# ============================================================

@app.get("/admin/status")
def admin_status(
    user: User = Depends(current_user),
):
    if user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Admin access required.",
        )

    return {
        "success": True,
        "message": "Admin access verified.",
        "user": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "role": user.role,
        },
    }