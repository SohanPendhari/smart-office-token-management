-- Smart Office Queue: full schema (generated from backend/database/migrations/*.sql)
-- Run:  psql -U postgres -d smart_office -f database/schema.sql


-- 001: departments
CREATE TABLE IF NOT EXISTS departments (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    code        VARCHAR(10)  NOT NULL UNIQUE,
    status      VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'PAUSED')),
    paused_at   TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

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

-- 003: visitors (name + mobile only, no login)
CREATE TABLE IF NOT EXISTS visitors (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    mobile      VARCHAR(20)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_visitors_mobile ON visitors (mobile);

-- 004: tokens (core table)
-- sequence_number comes from one global sequence. Queue order is
--   priority DESC, priority_level DESC, sequence_number ASC.
-- A no-show / transferred token gets a NEW sequence number => it goes to the end.
CREATE SEQUENCE IF NOT EXISTS token_sequence_seq;

CREATE TABLE IF NOT EXISTS tokens (
    id                      BIGSERIAL PRIMARY KEY,
    token_number            VARCHAR(20) NOT NULL,                       -- e.g. IT-021
    visitor_id              BIGINT      NOT NULL REFERENCES visitors(id),
    department_id           INT         NOT NULL REFERENCES departments(id),
    priority                BOOLEAN     NOT NULL DEFAULT FALSE,
    priority_level          INT         NOT NULL DEFAULT 0,
    status                  VARCHAR(12) NOT NULL DEFAULT 'WAITING'
                            CHECK (status IN ('WAITING', 'SERVING', 'COMPLETED', 'CANCELLED')),
    sequence_number         BIGINT      NOT NULL DEFAULT nextval('token_sequence_seq'),
    no_show_count           INT         NOT NULL DEFAULT 0,
    generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    called_at               TIMESTAMPTZ,
    serving_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    cancelled_at            TIMESTAMPTZ,
    estimated_wait_seconds  INT         NOT NULL DEFAULT 0,
    created_date            DATE        NOT NULL DEFAULT CURRENT_DATE,
    created_by              INT REFERENCES users(id),                   -- NULL = created by visitor
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_token_number_per_day UNIQUE (token_number, created_date)
);
CREATE INDEX IF NOT EXISTS ix_tokens_queue ON tokens (department_id, status, priority DESC, priority_level DESC, sequence_number);
CREATE INDEX IF NOT EXISTS ix_tokens_created_date ON tokens (created_date);

-- 005: audit trail of everything that happens to a token
CREATE TABLE IF NOT EXISTS token_events (
    id             BIGSERIAL PRIMARY KEY,
    token_id       BIGINT      NOT NULL REFERENCES tokens(id),
    department_id  INT         NOT NULL REFERENCES departments(id),
    event_type     VARCHAR(20) NOT NULL
                   CHECK (event_type IN ('GENERATED','CALLED','COMPLETED','NO_SHOW','CANCELLED','TRANSFERRED','PRIORITY_SET','PRIORITY_REMOVED')),
    from_status    VARCHAR(12),
    to_status      VARCHAR(12),
    user_id        INT REFERENCES users(id),
    note           TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_token_events_token ON token_events (token_id);
CREATE INDEX IF NOT EXISTS ix_token_events_type_date ON token_events (event_type, created_at);

-- 006: transfer history
CREATE TABLE IF NOT EXISTS token_transfers (
    id                  BIGSERIAL PRIMARY KEY,
    token_id            BIGINT      NOT NULL REFERENCES tokens(id),
    from_department_id  INT         NOT NULL REFERENCES departments(id),
    to_department_id    INT         NOT NULL REFERENCES departments(id),
    transferred_by      INT REFERENCES users(id),
    reason              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (from_department_id <> to_department_id)
);
CREATE INDEX IF NOT EXISTS ix_token_transfers_token ON token_transfers (token_id);

-- 007: per-department queue configuration + the daily token counter
CREATE TABLE IF NOT EXISTS queue_settings (
    department_id          INT PRIMARY KEY REFERENCES departments(id),
    avg_service_minutes    INT     NOT NULL DEFAULT 5 CHECK (avg_service_minutes > 0),  -- fallback until real data exists
    max_no_shows           INT     NOT NULL DEFAULT 2 CHECK (max_no_shows > 0),         -- Nth no-show cancels the token
    allow_visitor_priority BOOLEAN NOT NULL DEFAULT TRUE,
    token_counter          INT     NOT NULL DEFAULT 0,                                  -- last number issued today
    token_counter_date     DATE,                                                        -- counter resets when the date changes
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

-- 010: per-day, per-department rollup (refreshed whenever a token finishes)
CREATE TABLE IF NOT EXISTS daily_queue_stats (
    stat_date            DATE NOT NULL,
    department_id        INT  NOT NULL REFERENCES departments(id),
    total_tokens         INT  NOT NULL DEFAULT 0,
    completed            INT  NOT NULL DEFAULT 0,
    cancelled            INT  NOT NULL DEFAULT 0,
    no_shows             INT  NOT NULL DEFAULT 0,
    avg_wait_seconds     INT  NOT NULL DEFAULT 0,
    avg_service_seconds  INT  NOT NULL DEFAULT 0,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (stat_date, department_id)
);
