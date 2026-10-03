-- 009: one row per time a staff member serves a token (feeds the statistics)
CREATE TABLE IF NOT EXISTS token_service_sessions (
    id                BIGSERIAL PRIMARY KEY,
    token_id          BIGINT      NOT NULL REFERENCES tokens(id),
    department_id     INT         NOT NULL REFERENCES departments(id),
    counter_id        INT REFERENCES counters(id),
    staff_id          INT REFERENCES users(id),
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at          TIMESTAMPTZ,
    duration_seconds  INT,
    outcome           VARCHAR(12) CHECK (outcome IN ('COMPLETED', 'NO_SHOW', 'TRANSFERRED'))
);
CREATE INDEX IF NOT EXISTS ix_sessions_open ON token_service_sessions (staff_id) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_sessions_dept ON token_service_sessions (department_id, outcome, id DESC);
