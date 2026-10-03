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
