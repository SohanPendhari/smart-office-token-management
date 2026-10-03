-- 003: visitors (name + mobile only, no login)
CREATE TABLE IF NOT EXISTS visitors (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    mobile      VARCHAR(20)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_visitors_mobile ON visitors (mobile);
