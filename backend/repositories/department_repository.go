package repositories

import (
	"context"
	"database/sql"
	"errors"

	"smartoffice/models"
)

type DepartmentRepository struct{}

const deptSelect = `
	SELECT d.id, d.name, d.code, d.status, COALESCE(s.allow_visitor_priority, TRUE)
	FROM departments d
	LEFT JOIN queue_settings s ON s.department_id = d.id`

func scanDept(sc interface{ Scan(...any) error }) (*models.Department, error) {
	var d models.Department
	if err := sc.Scan(&d.ID, &d.Name, &d.Code, &d.Status, &d.AllowVisitorPriority); err != nil {
		return nil, err
	}
	d.CurrentlyServing = []string{}
	return &d, nil
}

// List returns departments without live numbers (the service adds those).
func (r *DepartmentRepository) List(ctx context.Context, q DBTX) ([]models.Department, error) {
	rows, err := q.QueryContext(ctx, deptSelect+` ORDER BY d.id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Department
	for rows.Next() {
		d, err := scanDept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *d)
	}
	return out, rows.Err()
}

// Get returns nil, nil when the department does not exist.
// lockShare takes a FOR SHARE lock so a concurrent pause cannot slip in during token generation.
func (r *DepartmentRepository) Get(ctx context.Context, q DBTX, id int, lockShare bool) (*models.Department, error) {
	sqlText := deptSelect + ` WHERE d.id = $1`
	if lockShare {
		sqlText += ` FOR SHARE OF d`
	}
	d, err := scanDept(q.QueryRowContext(ctx, sqlText, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return d, err
}

func (r *DepartmentRepository) SetStatus(ctx context.Context, q DBTX, id int, status string) error {
	_, err := q.ExecContext(ctx, `
		UPDATE departments
		SET status = $2::varchar,
		    paused_at = CASE WHEN $2::varchar = 'PAUSED' THEN NOW() ELSE NULL END,
		    updated_at = NOW()
		WHERE id = $1`, id, status)
	return err
}

func (r *DepartmentRepository) Settings(ctx context.Context, q DBTX, id int) (models.Settings, error) {
	s := models.Settings{AvgServiceMinutes: 5, MaxNoShows: 2, AllowVisitorPriority: true}
	err := q.QueryRowContext(ctx,
		`SELECT avg_service_minutes, max_no_shows, allow_visitor_priority FROM queue_settings WHERE department_id = $1`, id).
		Scan(&s.AvgServiceMinutes, &s.MaxNoShows, &s.AllowVisitorPriority)
	if errors.Is(err, sql.ErrNoRows) {
		return s, nil
	}
	return s, err
}

// Metrics gathers the live numbers for one department.
func (r *DepartmentRepository) Metrics(ctx context.Context, q DBTX, id int, st models.Settings) (models.Metrics, error) {
	m := models.Metrics{ServingNumbers: []string{}}

	if err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FILTER (WHERE status = 'WAITING'),
		       COUNT(*) FILTER (WHERE status = 'SERVING')
		FROM tokens
		WHERE department_id = $1 AND status IN ('WAITING', 'SERVING')`, id).Scan(&m.Waiting, &m.Serving); err != nil {
		return m, err
	}

	rows, err := q.QueryContext(ctx,
		`SELECT token_number FROM tokens WHERE department_id = $1 AND status = 'SERVING' ORDER BY serving_at`, id)
	if err != nil {
		return m, err
	}
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			rows.Close()
			return m, err
		}
		m.ServingNumbers = append(m.ServingNumbers, n)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return m, err
	}

	if err := q.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM counters WHERE department_id = $1 AND is_active`, id).Scan(&m.ActiveCounters); err != nil {
		return m, err
	}
	if m.ActiveCounters < 1 {
		m.ActiveCounters = 1
	}

	// Average of the last 20 completed services; fall back to the configured default
	// until at least 5 samples exist. Never lower than 1 minute so demos stay readable.
	var avg, samples int
	if err := q.QueryRowContext(ctx, `
		SELECT COALESCE(AVG(duration_seconds), 0)::int, COUNT(*)
		FROM (SELECT duration_seconds FROM token_service_sessions
		      WHERE department_id = $1 AND outcome = 'COMPLETED' AND duration_seconds IS NOT NULL
		      ORDER BY id DESC LIMIT 20) s`, id).Scan(&avg, &samples); err != nil {
		return m, err
	}
	if samples < 5 {
		avg = st.AvgServiceMinutes * 60
	}
	if avg < 60 {
		avg = 60
	}
	m.AvgServiceSeconds = avg
	return m, nil
}

// UserCounter returns the counter assigned to the user in this department, or nil.
func (r *DepartmentRepository) UserCounter(ctx context.Context, q DBTX, userID, deptID int) (*int, error) {
	return optionalInt(q.QueryRowContext(ctx,
		`SELECT id FROM counters WHERE department_id = $1 AND assigned_user_id = $2 AND is_active ORDER BY id LIMIT 1`, deptID, userID))
}

// FreeCounter returns the first active counter with no open service session, or nil.
func (r *DepartmentRepository) FreeCounter(ctx context.Context, q DBTX, deptID int) (*int, error) {
	return optionalInt(q.QueryRowContext(ctx, `
		SELECT c.id FROM counters c
		WHERE c.department_id = $1 AND c.is_active
		  AND NOT EXISTS (SELECT 1 FROM token_service_sessions s WHERE s.counter_id = c.id AND s.ended_at IS NULL)
		ORDER BY c.id LIMIT 1`, deptID))
}

func optionalInt(row *sql.Row) (*int, error) {
	var v int
	if err := row.Scan(&v); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &v, nil
}
