-- 002: staff / admin users (visitors have no account)
CREATE TABLE IF NOT EXISTS users (
    id             SERIAL PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    role           VARCHAR(10)  NOT NULL CHECK (role IN ('ADMIN', 'STAFF')),
    department_id  INT REFERENCES departments(id),   -- NULL for ADMIN (can act on every department)
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_users_email ON users (LOWER(email));
