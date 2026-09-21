from .database import Base, engine, SessionLocal
from .models import User
from .security import hash_password

Base.metadata.create_all(bind=engine)
db=SessionLocal()

email="admin@uniattend.local"
password="Admin@12345"

if db.query(User).filter(User.email==email).first():
    print("Admin already exists:", email)
else:
    u=User(full_name="System Administrator",email=email,
           password_hash=hash_password(password),role="admin")
    db.add(u); db.commit()
    print("Admin created")
    print("Email:",email)
    print("Password:",password)
db.close()
