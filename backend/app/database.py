from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = "sqlite:///./uni_attend.db"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


def migrate_database():
    """
    Safely add new columns to the existing SQLite database.

    This is important because SQLAlchemy's create_all()
    does NOT add new columns to tables that already exist.
    """

    inspector = inspect(engine)
    tables = inspector.get_table_names()

    # ---------------------------------------------------------
    # TIMETABLE TABLE
    # ---------------------------------------------------------
    if "timetable" in tables:

        columns = {
            column["name"]
            for column in inspector.get_columns("timetable")
        }

        with engine.begin() as connection:

            if "latitude" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE timetable "
                        "ADD COLUMN latitude FLOAT"
                    )
                )

            if "longitude" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE timetable "
                        "ADD COLUMN longitude FLOAT"
                    )
                )

            if "allowed_radius" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE timetable "
                        "ADD COLUMN allowed_radius FLOAT "
                        "NOT NULL DEFAULT 50.0"
                    )
                )

    # ---------------------------------------------------------
    # ATTENDANCE TABLE
    # ---------------------------------------------------------
    if "attendance" in tables:

        columns = {
            column["name"]
            for column in inspector.get_columns("attendance")
        }

        with engine.begin() as connection:

            if "latitude" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE attendance "
                        "ADD COLUMN latitude FLOAT"
                    )
                )

            if "longitude" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE attendance "
                        "ADD COLUMN longitude FLOAT"
                    )
                )

            if "distance_from_class" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE attendance "
                        "ADD COLUMN distance_from_class FLOAT"
                    )
                )

            if "location_verified" not in columns:
                connection.execute(
                    text(
                        "ALTER TABLE attendance "
                        "ADD COLUMN location_verified BOOLEAN "
                        "NOT NULL DEFAULT 0"
                    )
                )


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()

