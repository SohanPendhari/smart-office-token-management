package repositories

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"smartoffice/models"
)

type TokenRepository struct{}

const tokenSelect = `
	SELECT t.id, t.token_number, t.visitor_id, v.name, v.mobile,
	       t.department_id, d.name, d.code, t.priority, t.priority_level, t.status,
	       t.sequence_number, t.no_show_count, t.generated_at, t.called_at, t.serving_at,
	       t.completed_at, t.cancelled_at, t.estimated_wait_seconds, t.created_date::text,
	       t.created_by, t.updated_at
	FROM tokens t
	JOIN visitors v    ON v.id = t.visitor_id
	JOIN departments d ON d.id = t.department_id`

// waitingOrder is THE queue ordering: priority first, then FIFO by sequence.
const waitingOrder = ` ORDER BY t.priority DESC, t.priority_level DESC, t.sequence_number ASC`

func scanToken(sc interface{ Scan(...any) error }) (*models.Token, error) {
	var t models.Token
	var called, serving, completed, cancelled sql.NullTime
	var createdBy sql.NullInt64
	if err := sc.Scan(&t.ID, &t.TokenNumber, &t.VisitorID, &t.VisitorName, &t.VisitorMobile,
		&t.DepartmentID, &t.DepartmentName, &t.DepartmentCode, &t.Priority, &t.PriorityLevel, &t.Status,
		&t.SequenceNumber, &t.NoShowCount, &t.GeneratedAt, &called, &serving,
		&completed, &cancelled, &t.EstimatedWaitSeconds, &t.CreatedDate,
		&createdBy, &t.UpdatedAt); err != nil {
		return nil, err
	}
	if called.Valid {
		t.CalledAt = &called.Time
	}
	if serving.Valid {
		t.ServingAt = &serving.Time
	}
	if completed.Valid {
		t.CompletedAt = &completed.Time
	}
	if cancelled.Valid {
		t.CancelledAt = &cancelled.Time
	}
	if createdBy.Valid {
		v := int(createdBy.Int64)
		t.CreatedBy = &v
	}
	return &t, nil
}

// ---------- visitors ----------

func (r *TokenRepository) InsertVisitor(ctx context.Context, q DBTX, name, mobile string) (*models.Visitor, error) {
	v := models.Visitor{Name: name, Mobile: mobile}
	err := q.QueryRowContext(ctx,
		`INSERT INTO visitors (name, mobile) VALUES ($1, $2) RETURNING id, created_at`, name, mobile).
		Scan(&v.ID, &v.CreatedAt)
	return &v, err
}

func (r *TokenRepository) VisitorExists(ctx context.Context, q DBTX, id int64) (bool, error) {
	var one int
	err := q.QueryRowContext(ctx, `SELECT 1 FROM visitors WHERE id = $1`, id).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// ---------- tokens ----------

// Get returns nil, nil when not found. forUpdate locks only the token row.
func (r *TokenRepository) Get(ctx context.Context, q DBTX, id int64, forUpdate bool) (*models.Token, error) {
	sqlText := tokenSelect + ` WHERE t.id = $1`
	if forUpdate {
		sqlText += ` FOR UPDATE OF t`
	}
	t, err := scanToken(q.QueryRowContext(ctx, sqlText, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return t, err
}

// NextTokenNumber issues the next number for the department (IT-001, IT-002, ...), restarting each day.
// The UPDATE row-locks queue_settings, so concurrent generations are serialised and can never collide.
func (r *TokenRepository) NextTokenNumber(ctx context.Context, q DBTX, deptID int, code string) (string, error) {
	var n int
	err := q.QueryRowContext(ctx, `
		UPDATE queue_settings
		SET token_counter = CASE WHEN token_counter_date = CURRENT_DATE THEN token_counter + 1 ELSE 1 END,
		    token_counter_date = CURRENT_DATE,
		    updated_at = NOW()
		WHERE department_id = $1
		RETURNING token_counter`, deptID).Scan(&n)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s-%03d", code, n), nil
}

func (r *TokenRepository) Insert(ctx context.Context, q DBTX, number string, visitorID int64, deptID int,
	priority bool, estimate int, createdBy *int) (int64, error) {
	level := 0
	if priority {
		level = 1
	}
	var id int64
	err := q.QueryRowContext(ctx, `
		INSERT INTO tokens (token_number, visitor_id, department_id, priority, priority_level, status,
		                    sequence_number, estimated_wait_seconds, created_by)
		VALUES ($1, $2, $3, $4, $5, 'WAITING', nextval('token_sequence_seq'), $6, $7)
		RETURNING id`, number, visitorID, deptID, priority, level, estimate, createdBy).Scan(&id)
	return id, err
}

// ActiveTokenForMobile finds a WAITING/SERVING token the same mobile already holds in a department.
func (r *TokenRepository) ActiveTokenForMobile(ctx context.Context, q DBTX, mobile string, deptID int) (*models.Token, error) {
	t, err := scanToken(q.QueryRowContext(ctx, tokenSelect+`
		WHERE v.mobile = $1 AND t.department_id = $2 AND t.status IN ('WAITING', 'SERVING')
		ORDER BY t.id DESC LIMIT 1`, mobile, deptID))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return t, err
}

func (r *TokenRepository) ListWaiting(ctx context.Context, q DBTX, deptID int) ([]models.Token, error) {
	return r.list(ctx, q, tokenSelect+` WHERE t.department_id = $1 AND t.status = 'WAITING'`+waitingOrder, deptID)
}

func (r *TokenRepository) ListServing(ctx context.Context, q DBTX, deptID int) ([]models.Token, error) {
	return r.list(ctx, q, tokenSelect+` WHERE t.department_id = $1 AND t.status = 'SERVING' ORDER BY t.serving_at`, deptID)
}

func (r *TokenRepository) list(ctx context.Context, q DBTX, sqlText string, args ...any) ([]models.Token, error) {
	rows, err := q.QueryContext(ctx, sqlText, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []models.Token{}
	for rows.Next() {
		t, err := scanToken(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *t)
	}
	return out, rows.Err()
}

// LockNextWaiting picks the next token to call and locks it. SKIP LOCKED means two staff members
// pressing "Call Next" at the same moment get two different tokens instead of blocking or colliding.
// Returns 0 when nobody is waiting.
func (r *TokenRepository) LockNextWaiting(ctx context.Context, q DBTX, deptID int) (int64, error) {
	var id int64
	err := q.QueryRowContext(ctx, `
		SELECT t.id FROM tokens t
		WHERE t.department_id = $1 AND t.status = 'WAITING'
		ORDER BY t.priority DESC, t.priority_level DESC, t.sequence_number ASC
		LIMIT 1
		FOR UPDATE SKIP LOCKED`, deptID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, nil
	}
	return id, err
}

// PeopleAhead counts WAITING tokens in the same department that will be called before this one.
func (r *TokenRepository) PeopleAhead(ctx context.Context, q DBTX, tokenID int64) (int, error) {
	var n int
	err := q.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM tokens me
		JOIN tokens o ON o.department_id = me.department_id AND o.status = 'WAITING' AND o.id <> me.id
		WHERE me.id = $1
		  AND (o.priority::int, o.priority_level, -o.sequence_number)
		    > (me.priority::int, me.priority_level, -me.sequence_number)`, tokenID).Scan(&n)
	return n, err
}

func (r *TokenRepository) exec(ctx context.Context, q DBTX, sqlText string, args ...any) error {
	_, err := q.ExecContext(ctx, sqlText, args...)
	return err
}

func (r *TokenRepository) SetServing(ctx context.Context, q DBTX, id int64) error {
	return r.exec(ctx, q, `UPDATE tokens SET status = 'SERVING', called_at = NOW(), serving_at = NOW(),
		estimated_wait_seconds = 0, updated_at = NOW() WHERE id = $1`, id)
}

func (r *TokenRepository) SetCompleted(ctx context.Context, q DBTX, id int64) error {
	return r.exec(ctx, q, `UPDATE tokens SET status = 'COMPLETED', completed_at = NOW(), updated_at = NOW() WHERE id = $1`, id)
}

func (r *TokenRepository) SetCancelled(ctx context.Context, q DBTX, id int64, noShowCount int) error {
	return r.exec(ctx, q, `UPDATE tokens SET status = 'CANCELLED', cancelled_at = NOW(), no_show_count = $2,
		estimated_wait_seconds = 0, updated_at = NOW() WHERE id = $1`, id, noShowCount)
}

// Requeue puts a no-show token back at the END of the queue (new sequence number, priority dropped).
func (r *TokenRepository) Requeue(ctx context.Context, q DBTX, id int64, noShowCount int) error {
	return r.exec(ctx, q, `UPDATE tokens SET status = 'WAITING', no_show_count = $2, called_at = NULL, serving_at = NULL,
		priority = FALSE, priority_level = 0, sequence_number = nextval('token_sequence_seq'), updated_at = NOW()
		WHERE id = $1`, id, noShowCount)
}

// MoveToDepartment is used by transfers: new department, back to WAITING, end of that queue.
func (r *TokenRepository) MoveToDepartment(ctx context.Context, q DBTX, id int64, deptID int) error {
	return r.exec(ctx, q, `UPDATE tokens SET department_id = $2, status = 'WAITING', called_at = NULL, serving_at = NULL,
		sequence_number = nextval('token_sequence_seq'), updated_at = NOW() WHERE id = $1`, id, deptID)
}

func (r *TokenRepository) SetPriority(ctx context.Context, q DBTX, id int64, priority bool, level int) error {
	if !priority {
		level = 0
	} else if level < 1 {
		level = 1
	}
	return r.exec(ctx, q, `UPDATE tokens SET priority = $2, priority_level = $3, updated_at = NOW() WHERE id = $1`, id, priority, level)
}

func (r *TokenRepository) SetEstimate(ctx context.Context, q DBTX, id int64, seconds int) error {
	return r.exec(ctx, q, `UPDATE tokens SET estimated_wait_seconds = $2 WHERE id = $1`, id, seconds)
}

// ---------- events, transfers, sessions ----------

func (r *TokenRepository) AddEvent(ctx context.Context, q DBTX, tokenID int64, deptID int, eventType, from, to string, userID *int, note string) error {
	return r.exec(ctx, q, `
		INSERT INTO token_events (token_id, department_id, event_type, from_status, to_status, user_id, note)
		VALUES ($1, $2, $3, NULLIF($4, ''), NULLIF($5, ''), $6, NULLIF($7, ''))`,
		tokenID, deptID, eventType, from, to, userID, note)
}

func (r *TokenRepository) AddTransfer(ctx context.Context, q DBTX, tokenID int64, from, to int, userID *int, reason string) error {
	return r.exec(ctx, q, `
		INSERT INTO token_transfers (token_id, from_department_id, to_department_id, transferred_by, reason)
		VALUES ($1, $2, $3, $4, NULLIF($5, ''))`, tokenID, from, to, userID, reason)
}

func (r *TokenRepository) OpenSession(ctx context.Context, q DBTX, tokenID int64, deptID int, counterID *int, staffID int) error {
	return r.exec(ctx, q, `
		INSERT INTO token_service_sessions (token_id, department_id, counter_id, staff_id)
		VALUES ($1, $2, $3, $4)`, tokenID, deptID, counterID, staffID)
}

func (r *TokenRepository) CloseSession(ctx context.Context, q DBTX, tokenID int64, outcome string) error {
	return r.exec(ctx, q, `
		UPDATE token_service_sessions
		SET ended_at = NOW(),
		    duration_seconds = GREATEST(EXTRACT(EPOCH FROM (NOW() - started_at))::int, 0),
		    outcome = $2
		WHERE token_id = $1 AND ended_at IS NULL`, tokenID, outcome)
}

// StaffBusy reports whether the staff member is still serving someone in this department.
func (r *TokenRepository) StaffBusy(ctx context.Context, q DBTX, staffID, deptID int) (bool, error) {
	var n int
	err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM token_service_sessions s
		JOIN tokens t ON t.id = s.token_id AND t.status = 'SERVING'
		WHERE s.staff_id = $1 AND s.department_id = $2 AND s.ended_at IS NULL`, staffID, deptID).Scan(&n)
	return n > 0, err
}

func (r *TokenRepository) GetVisitor(ctx context.Context, q DBTX, id int64) (*models.Visitor, error) {
	var v models.Visitor
	err := q.QueryRowContext(ctx, `SELECT id, name, mobile, created_at FROM visitors WHERE id = $1`, id).
		Scan(&v.ID, &v.Name, &v.Mobile, &v.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &v, err
}
