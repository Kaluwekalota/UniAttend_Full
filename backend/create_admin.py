from app.database import Base, engine, SessionLocal
from app.models import User
from app.security import hash_password
Base.metadata.create_all(bind=engine)
db=SessionLocal()
email=input("Admin email: ").strip().lower()
name=input("Admin full name: ").strip()
password=input("Admin password (minimum 6 characters): ")
if len(password)<6: raise SystemExit("Password must be at least 6 characters.")
if db.query(User).filter(User.email==email).first(): raise SystemExit("That email already exists.")
db.add(User(full_name=name,email=email,password_hash=hash_password(password),role="admin"))
db.commit()
print("Admin created successfully.")
db.close()
