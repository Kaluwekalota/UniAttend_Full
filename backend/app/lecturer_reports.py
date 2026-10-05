from io import BytesIO
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

from .database import get_db
from .models import (
    User,
    Course,
    Timetable,
    AttendanceSession,
    Attendance,
)
from .dependencies import current_user


# ============================================================
# ROUTER
# ============================================================

router = APIRouter(
    prefix="/lecturer",
    tags=["Lecturer Reports"],
)


# ============================================================
# LECTURER ACCESS CHECK
# ============================================================

def lecturer_only(user: User):
    if user.role != "lecturer":
        raise HTTPException(
            status_code=403,
            detail="Lecturer access required.",
        )

    return user


# ============================================================
# GENERATE ATTENDANCE PDF
# ============================================================

@router.get("/attendance/{session_id}/pdf")
def generate_attendance_pdf(
    session_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """
    Generate a PDF attendance report for a lecturer's
    attendance session.
    """

    # --------------------------------------------------------
    # Check lecturer role
    # --------------------------------------------------------

    lecturer_only(user)

    # --------------------------------------------------------
    # Find attendance session
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # Security:
    # lecturer can only access own session
    # --------------------------------------------------------

    if session.lecturer_id != user.id:
        raise HTTPException(
            status_code=403,
            detail=(
                "You can only generate reports "
                "for your own attendance sessions."
            ),
        )

    # --------------------------------------------------------
    # Find course
    # --------------------------------------------------------

    course = (
        db.query(Course)
        .filter(
            Course.id == session.course_id
        )
        .first()
    )

    if course is None:
        raise HTTPException(
            status_code=404,
            detail="Course associated with this session was not found.",
        )

    # --------------------------------------------------------
    # Find timetable
    # --------------------------------------------------------

    timetable = (
        db.query(Timetable)
        .filter(
            Timetable.id == session.timetable_id
        )
        .first()
    )

    # --------------------------------------------------------
    # Find attendance records
    # --------------------------------------------------------

    attendance_rows = (
        db.query(Attendance, User)
        .join(
            User,
            User.id == Attendance.student_id,
        )
        .filter(
            Attendance.session_id == session.id
        )
        .order_by(
            User.full_name.asc()
        )
        .all()
    )

    # ========================================================
    # CREATE PDF
    # ========================================================

    buffer = BytesIO()

    page_width, page_height = landscape(A4)

    document = SimpleDocTemplate(
        buffer,
        pagesize=landscape(A4),
        rightMargin=25,
        leftMargin=25,
        topMargin=25,
        bottomMargin=25,
    )

    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        "ReportTitle",
        parent=styles["Title"],
        fontSize=20,
        leading=24,
        alignment=TA_CENTER,
        spaceAfter=5,
    )

    subtitle_style = ParagraphStyle(
        "ReportSubtitle",
        parent=styles["Heading2"],
        fontSize=13,
        leading=16,
        alignment=TA_CENTER,
        spaceAfter=15,
    )

    normal_style = ParagraphStyle(
        "NormalReport",
        parent=styles["Normal"],
        fontSize=9,
        leading=11,
    )

    small_style = ParagraphStyle(
        "SmallReport",
        parent=styles["Normal"],
        fontSize=8,
        leading=10,
    )

    story = []

    # ========================================================
    # HEADER
    # ========================================================

    story.append(
        Paragraph(
            "UNI-ATTEND",
            title_style,
        )
    )

    story.append(
        Paragraph(
            "LECTURER ATTENDANCE REPORT",
            subtitle_style,
        )
    )

    # ========================================================
    # COURSE / SESSION INFORMATION
    # ========================================================

    created_at = (
        session.created_at.strftime("%Y-%m-%d %H:%M:%S")
        if session.created_at
        else "N/A"
    )

    expires_at = (
        session.expires_at.strftime("%Y-%m-%d %H:%M:%S")
        if session.expires_at
        else "N/A"
    )

    class_end_at = (
        session.class_end_at.strftime("%Y-%m-%d %H:%M:%S")
        if session.class_end_at
        else "N/A"
    )

    generated_at = datetime.utcnow().strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    session_type = (
        session.session_type
        if session.session_type
        else "N/A"
    )

    room = (
        timetable.room
        if timetable
        else "N/A"
    )

    day = (
        timetable.day
        if timetable
        else "N/A"
    )

    start_time = (
        timetable.start
        if timetable
        else "N/A"
    )

    end_time = (
        timetable.end
        if timetable
        else "N/A"
    )

    group_name = (
        timetable.group_name
        if timetable
        else "N/A"
    )

    block = (
        timetable.block
        if timetable
        else "N/A"
    )

    information = [
        [
            Paragraph("<b>Course Code</b>", normal_style),
            Paragraph(
                str(course.code or "N/A"),
                normal_style,
            ),

            Paragraph("<b>Course Title</b>", normal_style),
            Paragraph(
                str(course.title or "N/A"),
                normal_style,
            ),
        ],

        [
            Paragraph("<b>Lecturer</b>", normal_style),
            Paragraph(
                str(user.full_name or "N/A"),
                normal_style,
            ),

            Paragraph("<b>Session Type</b>", normal_style),
            Paragraph(
                str(session_type),
                normal_style,
            ),
        ],

        [
            Paragraph("<b>Day</b>", normal_style),
            Paragraph(
                str(day),
                normal_style,
            ),

            Paragraph("<b>Time</b>", normal_style),
            Paragraph(
                f"{start_time} - {end_time}",
                normal_style,
            ),
        ],

        [
            Paragraph("<b>Room</b>", normal_style),
            Paragraph(
                str(room),
                normal_style,
            ),

            Paragraph("<b>Block</b>", normal_style),
            Paragraph(
                str(block),
                normal_style,
            ),
        ],

        [
            Paragraph("<b>Group</b>", normal_style),
            Paragraph(
                str(group_name),
                normal_style,
            ),

            Paragraph("<b>Students Present</b>", normal_style),
            Paragraph(
                str(len(attendance_rows)),
                normal_style,
            ),
        ],

        [
            Paragraph("<b>Session Created</b>", normal_style),
            Paragraph(
                created_at,
                normal_style,
            ),

            Paragraph("<b>QR Expiry</b>", normal_style),
            Paragraph(
                expires_at,
                normal_style,
            ),
        ],

        [
            Paragraph("<b>Class End</b>", normal_style),
            Paragraph(
                class_end_at,
                normal_style,
            ),

            Paragraph("<b>Report Generated</b>", normal_style),
            Paragraph(
                generated_at,
                normal_style,
            ),
        ],
    ]

    information_table = Table(
        information,
        colWidths=[
            90,
            170,
            100,
            260,
        ],
        hAlign="LEFT",
    )

    information_table.setStyle(
        TableStyle([
            (
                "GRID",
                (0, 0),
                (-1, -1),
                0.5,
                colors.grey,
            ),
            (
                "BACKGROUND",
                (0, 0),
                (0, -1),
                colors.whitesmoke,
            ),
            (
                "BACKGROUND",
                (2, 0),
                (2, -1),
                colors.whitesmoke,
            ),
            (
                "VALIGN",
                (0, 0),
                (-1, -1),
                "MIDDLE",
            ),
            (
                "LEFTPADDING",
                (0, 0),
                (-1, -1),
                6,
            ),
            (
                "RIGHTPADDING",
                (0, 0),
                (-1, -1),
                6,
            ),
            (
                "TOPPADDING",
                (0, 0),
                (-1, -1),
                5,
            ),
            (
                "BOTTOMPADDING",
                (0, 0),
                (-1, -1),
                5,
            ),
        ])
    )

    story.append(information_table)

    story.append(Spacer(1, 18))

    # ========================================================
    # ATTENDANCE TABLE
    # ========================================================

    attendance_data = [
        [
            Paragraph("<b>#</b>", small_style),
            Paragraph("<b>Student ID</b>", small_style),
            Paragraph("<b>Student Name</b>", small_style),
            Paragraph("<b>Marked At</b>", small_style),
            Paragraph("<b>Method</b>", small_style),
            Paragraph("<b>Location</b>", small_style),
            Paragraph("<b>Distance</b>", small_style),
        ]
    ]

    for index, (attendance, student) in enumerate(
        attendance_rows,
        start=1,
    ):

        marked_at = (
            attendance.marked_at.strftime(
                "%Y-%m-%d %H:%M:%S"
            )
            if attendance.marked_at
            else "N/A"
        )

        location_status = (
            "Verified"
            if attendance.location_verified
            else "Not Verified"
        )

        if attendance.distance_from_class is not None:
            distance = (
                f"{attendance.distance_from_class:.1f} m"
            )
        else:
            distance = "N/A"

        attendance_data.append([
            Paragraph(
                str(index),
                small_style,
            ),

            Paragraph(
                str(student.student_id or "N/A"),
                small_style,
            ),

            Paragraph(
                str(student.full_name or "N/A"),
                small_style,
            ),

            Paragraph(
                marked_at,
                small_style,
            ),

            Paragraph(
                str(attendance.method or "N/A"),
                small_style,
            ),

            Paragraph(
                location_status,
                small_style,
            ),

            Paragraph(
                distance,
                small_style,
            ),
        ])

    attendance_table = Table(
        attendance_data,
        colWidths=[
            30,
            90,
            180,
            125,
            90,
            90,
            80,
        ],
        repeatRows=1,
        hAlign="LEFT",
    )

    attendance_table.setStyle(
        TableStyle([
            (
                "GRID",
                (0, 0),
                (-1, -1),
                0.5,
                colors.grey,
            ),

            (
                "BACKGROUND",
                (0, 0),
                (-1, 0),
                colors.lightgrey,
            ),

            (
                "FONTNAME",
                (0, 0),
                (-1, 0),
                "Helvetica-Bold",
            ),

            (
                "VALIGN",
                (0, 0),
                (-1, -1),
                "MIDDLE",
            ),

            (
                "ALIGN",
                (0, 0),
                (0, -1),
                "CENTER",
            ),

            (
                "ALIGN",
                (4, 1),
                (6, -1),
                "CENTER",
            ),

            (
                "LEFTPADDING",
                (0, 0),
                (-1, -1),
                5,
            ),

            (
                "RIGHTPADDING",
                (0, 0),
                (-1, -1),
                5,
            ),

            (
                "TOPPADDING",
                (0, 0),
                (-1, -1),
                5,
            ),

            (
                "BOTTOMPADDING",
                (0, 0),
                (-1, -1),
                5,
            ),
        ])
    )

    story.append(
        Paragraph(
            "<b>ATTENDANCE RECORDS</b>",
            normal_style,
        )
    )

    story.append(Spacer(1, 7))

    if attendance_rows:

        story.append(
            attendance_table
        )

    else:

        story.append(
            Paragraph(
                "No students have recorded attendance "
                "for this session.",
                normal_style,
            )
        )

    story.append(Spacer(1, 20))

    # ========================================================
    # FOOTER
    # ========================================================

    story.append(
        Paragraph(
            "Generated by Uni-Attend Attendance Management System.",
            small_style,
        )
    )

    # ========================================================
    # BUILD PDF
    # ========================================================

    document.build(story)

    buffer.seek(0)

    # Safe filename
    safe_course_code = (
        "".join(
            character
            for character in str(course.code)
            if character.isalnum()
            or character in ("-", "_")
        )
        or "course"
    )

    filename = (
        f"{safe_course_code}"
        f"_attendance_{session.id}.pdf"
    )

    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f'attachment; filename="{filename}"'
            )
        },
    )

