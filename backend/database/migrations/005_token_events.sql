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
