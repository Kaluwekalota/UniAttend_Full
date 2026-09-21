# UniAttend Backend Phase 1

FastAPI + SQLite backend matching the current Flutter API.

## Start on Windows

1. Install Python 3.11+.
2. In this folder run:
   `py -m venv .venv`
   `.venv\Scripts\python.exe -m pip install -r requirements.txt`
3. Start:
   `.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`
4. Open `http://127.0.0.1:8000/docs`.

If `pip` is not recognized, always use `py -m pip` or the venv Python path.

## Flutter

Set `mobile/lib/services/api.dart`:
`static const String baseUrl = 'http://YOUR-PC-IP:8000';`

For an Android phone, the phone and PC must be on the same reachable network.

## Included

Login, student/lecturer registration, JWT, PBKDF2 password hashing, roles, courses, enrollment, timetable, 5-minute server-side QR sessions, QR expiry, duplicate attendance prevention, idempotency, attendance history, audit logs and basic analytics.

University authentication is intentionally not included.

## Admin

Create the first admin from this folder:
`py create_admin.py`

Do not expose the development server directly to the public internet. Production needs HTTPS, restricted CORS, a strong secret, rate limiting, backups and a production database.
