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
