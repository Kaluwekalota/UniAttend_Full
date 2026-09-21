from datetime import datetime
from sqlalchemy import Boolean,Column,DateTime,ForeignKey,Integer,String,UniqueConstraint
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__="users"
    id=Column(Integer,primary_key=True,index=True); full_name=Column(String(150),nullable=False)
    email=Column(String(255),unique=True,index=True,nullable=False); password_hash=Column(String(255),nullable=False)
    role=Column(String(30),nullable=False,index=True); student_id=Column(String(80),unique=True,index=True)
    staff_id=Column(String(80),unique=True,index=True); programme=Column(String(150)); department=Column(String(150))
    profile_picture=Column(String(500)); is_active=Column(Boolean,default=True,nullable=False)
    created_at=Column(DateTime,default=datetime.utcnow,nullable=False)

class Course(Base):
    __tablename__="courses"
    id=Column(Integer,primary_key=True,index=True); code=Column(String(50),unique=True,nullable=False,index=True)
    title=Column(String(200),nullable=False); programme=Column(String(100)); lecturer_id=Column(Integer,ForeignKey("users.id"))
    lecturer=relationship("User")

class Enrollment(Base):
    __tablename__="enrollments"
    id=Column(Integer,primary_key=True); student_id=Column(Integer,ForeignKey("users.id"),nullable=False)
    course_id=Column(Integer,ForeignKey("courses.id"),nullable=False)
    __table_args__=(UniqueConstraint("student_id","course_id",name="uq_student_course"),)

class Timetable(Base):
    __tablename__ = "timetable"

    id = Column(Integer, primary_key=True)

    course_id = Column(
        Integer,
        ForeignKey("courses.id"),
        nullable=False,
    )

    day = Column(
        String(20),
        nullable=False,
    )

    start = Column(
        String(10),
        nullable=False,
    )

    end = Column(
        String(10),
        nullable=False,
    )

    room = Column(
        String(100),
    )

    group_name = Column(
        String(100),
    )

    # Example:
    # Week 1-2
    # Week 3-4
    # Week 5-6
    # Week 7-8
    # Week 9-10
    # Week 11-12
    block = Column(
        String(30),
    )

    class_mode = Column(
        String(20),
        default="PHYSICAL",
        nullable=False,
    )

    is_active = Column(
        Boolean,
        default=True,
        nullable=False,
    )

    course = relationship(
        "Course",
    )
class AttendanceSession(Base):
    __tablename__="attendance_sessions"
    id=Column(Integer,primary_key=True); timetable_id=Column(Integer,ForeignKey("timetable.id"),nullable=False)
    course_id=Column(Integer,ForeignKey("courses.id"),nullable=False); lecturer_id=Column(Integer,ForeignKey("users.id"),nullable=False)
    token=Column(String(120),unique=True,nullable=False,index=True); created_at=Column(DateTime,default=datetime.utcnow,nullable=False)
    expires_at=Column(DateTime,nullable=False); class_end_at=Column(DateTime,nullable=False); is_active=Column(Boolean,default=True,nullable=False)
    session_type=Column(String(20),default="PHYSICAL",nullable=False)
    timetable=relationship("Timetable"); course=relationship("Course"); lecturer=relationship("User")

class Attendance(Base):
    __tablename__="attendance"
    id=Column(Integer,primary_key=True); session_id=Column(Integer,ForeignKey("attendance_sessions.id"),nullable=False)
    student_id=Column(Integer,ForeignKey("users.id"),nullable=False); idempotency_key=Column(String(120),unique=True,nullable=False,index=True)
    method=Column(String(50),default="QR+biometric",nullable=False); marked_at=Column(DateTime,default=datetime.utcnow,nullable=False)
    session=relationship("AttendanceSession"); student=relationship("User")
    __table_args__=(UniqueConstraint("session_id","student_id",name="uq_attendance_session_student"),)

class AuditLog(Base):
    __tablename__="audit_logs"
    id=Column(Integer,primary_key=True); user_id=Column(Integer,ForeignKey("users.id")); action=Column(String(100),nullable=False)
    details=Column(String(1000)); created_at=Column(DateTime,default=datetime.utcnow,nullable=False); user=relationship("User")
