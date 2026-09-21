# Uni Attend User Guide

## Student

1. Register as Student.
2. Login.
3. Open Student Dashboard.
4. View timetable.
5. Tap Scan Attendance QR.
6. Scan the lecturer's QR.
7. Complete fingerprint/biometric prompt if available.
8. Wait for validation.
9. Successful attendance appears on screen.
10. View attendance history and reports.

## Lecturer

1. Register as Lecturer.
2. Login.
3. Open Lecturer Dashboard.
4. Select a course.
5. Tap Generate Attendance QR.
6. Show the QR to students.
7. Watch live attendance count.
8. View reports.

## Admin

Use the demo account for local testing.

Admin can:
- view system statistics
- manage courses
- view students/lecturers
- inspect audit logs
- view timetable
- download reports

## QR security

The server creates a random attendance token with an expiration time. The QR contains the token. The server checks:
- token exists
- token has not expired
- student identity matches authenticated account
- student has not already attended the session

The database schema additionally has:
`UNIQUE(session_id, student_id)`
and:
`UNIQUE(idempotency_key)`
for duplicate protection.
