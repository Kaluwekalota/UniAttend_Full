from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
import csv, io

from .database import get_db
from .models import User, Course, Timetable, Attendance, AttendanceSession, Enrollment
from .main import current_user, audit

router = APIRouter(prefix="/admin", tags=["Admin"])

def admin_only(u=Depends(current_user)):
    if u.role != "admin":
        raise HTTPException(403, "Admin access required.")
    return u

@router.get("/dashboard")
def dashboard(u=Depends(admin_only), db: Session = Depends(get_db)):
    return {
        "students": db.query(User).filter(User.role=="student").count(),
        "lecturers": db.query(User).filter(User.role=="lecturer").count(),
        "courses": db.query(Course).count(),
        "timetable_entries": db.query(Timetable).filter(Timetable.is_active==True).count(),
        "attendance_records": db.query(Attendance).count(),
        "active_sessions": db.query(AttendanceSession).filter(AttendanceSession.is_active==True).count(),
    }

@router.get("/users")
def users(u=Depends(admin_only), db: Session = Depends(get_db)):
    rows = db.query(User).order_by(User.created_at.desc()).all()
    return [{
        "id": x.id, "full_name": x.full_name, "email": x.email, "role": x.role,
        "student_id": x.student_id, "staff_id": x.staff_id,
        "programme": x.programme, "department": x.department,
        "is_active": x.is_active
    } for x in rows]

@router.patch("/users/{user_id}/status")
def user_status(user_id: int, active: bool, u=Depends(admin_only), db: Session=Depends(get_db)):
    target = db.query(User).filter(User.id==user_id).first()
    if not target:
        raise HTTPException(404, "User not found.")
    if target.id == u.id and not active:
        raise HTTPException(400, "You cannot deactivate your own admin account.")
    target.is_active = active
    db.commit()
    audit(db, u.id, "ACCOUNT_STATUS_CHANGED", f"user={target.id}, active={active}")
    return {"message": "Account status updated.", "is_active": target.is_active}

@router.post("/courses")
def create_course(code: str, title: str, lecturer_id: int|None=None,
                  programme: str|None=None, u=Depends(admin_only), db: Session=Depends(get_db)):
    if db.query(Course).filter(Course.code==code).first():
        raise HTTPException(409, "Course code already exists.")
    if lecturer_id and not db.query(User).filter(User.id==lecturer_id, User.role=="lecturer").first():
        raise HTTPException(400, "Lecturer not found.")
    c = Course(code=code.strip().upper(), title=title.strip(), lecturer_id=lecturer_id, programme=programme)
    db.add(c); db.commit(); db.refresh(c)
    audit(db, u.id, "COURSE_CREATED", f"{c.code}")
    return {"id": c.id, "code": c.code, "title": c.title, "lecturer_id": c.lecturer_id, "programme": c.programme}

@router.get("/courses")
def courses(u=Depends(admin_only), db: Session=Depends(get_db)):
    return [{
        "id":c.id,"code":c.code,"title":c.title,"lecturer_id":c.lecturer_id,
        "lecturer_name": c.lecturer.full_name if c.lecturer else None,
        "programme":c.programme
    } for c in db.query(Course).all()]

def validate_row(row):
    required = ["course_code","day","start","end","room","group","class_mode"]
    missing = [x for x in required if not str(row.get(x,"")).strip()]
    if missing:
        raise ValueError("Missing: " + ", ".join(missing))
    mode = str(row["class_mode"]).strip().upper()
    if mode not in ("PHYSICAL","ONLINE"):
        raise ValueError("class_mode must be PHYSICAL or ONLINE")
    for key in ("start","end"):
        try:
            datetime.strptime(str(row[key]).strip(), "%H:%M")
        except ValueError:
            raise ValueError(f"{key} must use HH:MM, e.g. 08:00")
    return mode

@router.post("/timetable/upload")
async def upload_timetable(file: UploadFile=File(...), replace: bool=False,
                           u=Depends(admin_only), db: Session=Depends(get_db)):
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(400, "Upload a CSV timetable file.")
    raw = await file.read()
    try:
        rows = list(csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))))
    except Exception as e:
        raise HTTPException(400, f"Could not read CSV: {e}")
    if not rows:
        raise HTTPException(400, "CSV contains no timetable rows.")

    if replace:
        db.query(Timetable).update({"is_active":False}, synchronize_session=False)
        db.commit()

    created, errors = [], []
    for line, row in enumerate(rows, start=2):
        try:
            mode = validate_row(row)
            code = str(row["course_code"]).strip().upper()
            course = db.query(Course).filter(Course.code==code).first()
            if not course:
                raise ValueError(f"Course {code} does not exist. Create the course first.")
            item = Timetable(
                course_id=course.id,
                day=str(row["day"]).strip().title(),
                start=str(row["start"]).strip(),
                end=str(row["end"]).strip(),
                room=str(row["room"]).strip(),
                group_name=str(row["group"]).strip(),
                class_mode=mode,
                is_active=True
            )
            db.add(item); db.flush()
            created.append({"id":item.id,"course":code,"day":item.day,"start":item.start,
                            "end":item.end,"room":item.room,"group":item.group_name,"class_mode":mode})
        except Exception as e:
            errors.append({"line":line,"error":str(e),"row":row})
    db.commit()
    audit(db, u.id, "TIMETABLE_UPLOADED", f"created={len(created)}, errors={len(errors)}")
    return {"created":created,"errors":errors,"created_count":len(created),"error_count":len(errors)}

@router.get("/timetable")
def admin_timetable(u=Depends(admin_only), db: Session=Depends(get_db)):
    q = db.query(Timetable).join(Course).filter(Timetable.is_active==True).order_by(Timetable.day,Timetable.start)
    return [{
        "id":x.id,"course_id":x.course_id,"course_code":x.course.code,"course_title":x.course.title,
        "lecturer":x.course.lecturer.full_name if x.course.lecturer else None,
        "day":x.day,"start":x.start,"end":x.end,"room":x.room,"group":x.group_name,
        "class_mode":x.class_mode
    } for x in q.all()]

@router.delete("/timetable/{entry_id}")
def delete_timetable(entry_id:int,u=Depends(admin_only),db:Session=Depends(get_db)):
    x=db.query(Timetable).filter(Timetable.id==entry_id).first()
    if not x: raise HTTPException(404,"Timetable entry not found.")
    x.is_active=False; db.commit()
    audit(db,u.id,"TIMETABLE_ENTRY_DELETED",str(entry_id))
    return {"message":"Timetable entry removed."}
