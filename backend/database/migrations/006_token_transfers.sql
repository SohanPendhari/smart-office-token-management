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
