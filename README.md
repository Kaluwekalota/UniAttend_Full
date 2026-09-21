# UNI ATTEND — FULL PHASE 2 PACKAGE

This is a complete, runnable offline-first attendance application source package.

Included:
- Student registration/login
- Lecturer registration/login
- Admin login
- Role-based dashboards
- Student timetable
- Lecturer timetable
- ICT and AAS timetable views
- Lecturer QR generation
- Student QR scanning
- Fingerprint/biometric verification on supported Android devices
- Attendance validation
- Duplicate attendance prevention
- Offline SQLite queue
- Automatic retry/synchronization
- FastAPI backend
- Secure Argon2 password hashing
- JWT authentication
- Course management endpoints
- Timetable endpoints
- Attendance analytics endpoints
- PDF/CSV report endpoints
- Audit logs
- PostgreSQL production schema

IMPORTANT:
The backend runs with an in-memory development repository by default so the project can be tested without first installing PostgreSQL. The database/schema.sql is ready for the production PostgreSQL repository.

## 1. Prepare Flutter

Open PowerShell:

```powershell
cd mobile
flutter create .
flutter pub get
```

The `flutter create .` command generates the Android platform project while preserving the lib/ and pubspec files in this package.

## 2. Configure Android

The generated Android app needs camera and biometric permissions. The Dart packages are already included.

For local HTTP development, AndroidManifest.xml must allow cleartext traffic. Add:

```xml
android:usesCleartextTraffic="true"
```

to the `<application>` element in:
`mobile/android/app/src/main/AndroidManifest.xml`

Camera permission should also be present:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

Biometric support uses Android's native biometric prompt through `local_auth`.

## 3. Configure PC IP

Open:
`mobile/lib/services/api.dart`

Change:

```dart
static const String baseUrl = 'http://192.168.1.20:8000';
```

to your PC's IPv4 address.

Find it with:

```powershell
ipconfig
```

Example:

```text
IPv4 Address . . . . . . : 192.168.1.20
```

Phone and PC must be on the same Wi-Fi.

## 4. Start Python backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Test on PC:

`http://127.0.0.1:8000/health`

Test from phone browser:

`http://YOUR_PC_IP:8000/health`

## 5. Run the Android app

```powershell
cd mobile
flutter devices
flutter run
```

## 6. Build APK

```powershell
flutter build apk --release
```

APK:
`mobile/build/app/outputs/flutter-apk/app-release.apk`

## Demo admin

For local demonstration the backend creates:

Email: admin@uniattend.local
Password: Admin@12345

Change this before production.

## Attendance flow

Lecturer:
Login -> Dashboard -> Generate QR -> Select Course -> Display QR

Student:
Login -> Dashboard -> Scan QR -> Biometric -> Validate -> Attendance Success

Offline:
Student -> Scan/verify -> SQLite queue -> Internet returns -> API sync -> server duplicate check

## Production

Replace:
- in-memory repository
- development JWT secret
- HTTP
- demo admin password

with:
- PostgreSQL
- environment secret
- HTTPS
- proper Android signing
- backups
- monitoring
- university-specific policies

University authentication is intentionally NOT included, as requested.
