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
