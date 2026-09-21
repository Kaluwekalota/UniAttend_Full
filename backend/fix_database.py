from sqlalchemy import inspect, text

from app.database import engine


def fix_database():
    inspector = inspect(engine)

    # Check that the timetable table exists
    tables = inspector.get_table_names()

    if "timetable" not in tables:
        print("ERROR: timetable table does not exist.")
        print("Start the backend once so the tables can be created.")
        return

    # Get existing columns
    columns = inspector.get_columns("timetable")
    column_names = {column["name"] for column in columns}

    print("Existing timetable columns:")
    for name in sorted(column_names):
        print(f"  - {name}")

    # Add block if it is missing
    if "block" not in column_names:
        print("\nAdding missing column: block")

        with engine.begin() as connection:
            connection.execute(
                text(
                    "ALTER TABLE timetable "
                    "ADD COLUMN block VARCHAR(30)"
                )
            )

        print("SUCCESS: block column has been added.")
    else:
        print("\nThe block column already exists.")

    # Check again
    inspector = inspect(engine)
    columns = inspector.get_columns("timetable")
    column_names = {column["name"] for column in columns}

    print("\nFinal timetable columns:")
    for name in sorted(column_names):
        print(f"  - {name}")

    print("\nDatabase fix completed.")


if __name__ == "__main__":
    fix_database()