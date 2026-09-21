from sqlalchemy import inspect, text

from app.database import engine


def add_column_if_missing(
    table_name: str,
    column_name: str,
    column_definition: str,
):
    inspector = inspect(engine)

    existing_columns = {
        column["name"]
        for column in inspector.get_columns(table_name)
    }

    if column_name not in existing_columns:
        print(
            f"Adding missing column "
            f"{table_name}.{column_name}..."
        )

        with engine.begin() as connection:
            connection.execute(
                text(
                    f"ALTER TABLE {table_name} "
                    f"ADD COLUMN {column_name} "
                    f"{column_definition}"
                )
            )

        print(
            f"Added {table_name}.{column_name}"
        )

    else:
        print(
            f"{table_name}.{column_name} already exists."
        )


def main():
    print("Checking Uni Attend database...")
    print()

    inspector = inspect(engine)

    tables = inspector.get_table_names()

    if "timetable" not in tables:
        print(
            "The timetable table does not exist."
        )
        print(
            "Start the FastAPI application once "
            "so SQLAlchemy can create the tables."
        )
        return

    # Current Timetable model requires this column.
    add_column_if_missing(
        "timetable",
        "block",
        "VARCHAR(30)",
    )

    print()
    print("Database migration completed.")
    print("Your existing data has NOT been deleted.")


if __name__ == "__main__":
    main()