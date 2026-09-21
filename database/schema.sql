CREATE TABLE IF NOT EXISTS users (
 id BIGSERIAL PRIMARY KEY,
 full_name TEXT NOT NULL,
 email TEXT UNIQUE NOT NULL,
 password_hash TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN ('student','lecturer','admin')),
 student_no TEXT UNIQUE,
 staff_no TEXT UNIQUE,
 department TEXT,
 programme TEXT,
 active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS courses (
 id BIGSERIAL PRIMARY KEY,
 code TEXT UNIQUE NOT NULL,
 title TEXT NOT NULL,
 programme TEXT NOT NULL,
 active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS timetable (
 id BIGSERIAL PRIMARY KEY,
 course_id BIGINT NOT NULL REFERENCES courses(id),
 day TEXT NOT NULL,
 start_time TEXT NOT NULL,
 end_time TEXT NOT NULL,
 room TEXT NOT NULL,
 group_name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attendance_sessions (
 id BIGSERIAL PRIMARY KEY,
 course_id BIGINT NOT NULL REFERENCES courses(id),
 lecturer_id BIGINT NOT NULL REFERENCES users(id),
 token_hash TEXT UNIQUE NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS attendance (
 id BIGSERIAL PRIMARY KEY,
 session_id BIGINT NOT NULL REFERENCES attendance_sessions(id),
 student_id BIGINT NOT NULL REFERENCES users(id),
 idempotency_key TEXT UNIQUE NOT NULL,
 marked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 method TEXT NOT NULL,
 UNIQUE(session_id, student_id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
 id BIGSERIAL PRIMARY KEY,
 actor_user_id BIGINT REFERENCES users(id),
 action TEXT NOT NULL,
 entity_type TEXT,
 entity_id TEXT,
 details JSONB,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
