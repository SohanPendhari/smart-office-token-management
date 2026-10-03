-- 008: service counters (desks). More active counters => shorter estimated wait.
CREATE TABLE IF NOT EXISTS counters (
    id                SERIAL PRIMARY KEY,
    department_id     INT          NOT NULL REFERENCES departments(id),
    name              VARCHAR(50)  NOT NULL,
    assigned_user_id  INT REFERENCES users(id),
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (department_id, name)
);
