package repositories

import (
	"context"

	"smartoffice/models"
)

type DashboardRepository struct{}

func (r *DashboardRepository) Summary(ctx context.Context, q DBTX) (*models.Dashboard, error) {
	d := &models.Dashboard{Departments: []models.DepartmentSummary{}}

	if err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FILTER (WHERE status = 'WAITING'),
		       COUNT(*) FILTER (WHERE status = 'SERVING')
		FROM tokens WHERE status IN ('WAITING', 'SERVING')`).Scan(&d.Waiting, &d.Serving); err != nil {
		return nil, err
	}
	if err := q.QueryRowContext(ctx, `
		SELECT COUNT(*),
		       COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (serving_at - generated_at))) / 60.0, 1), 0)
		FROM tokens WHERE status = 'COMPLETED' AND completed_at::date = CURRENT_DATE`).
		Scan(&d.Completed, &d.AverageWaitingMinutes); err != nil {
		return nil, err
	}
	if err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM token_events WHERE event_type = 'NO_SHOW' AND created_at::date = CURRENT_DATE`).
		Scan(&d.NoShows); err != nil {
		return nil, err
	}
	if err := q.QueryRowContext(ctx, `
		SELECT COALESCE(ROUND(AVG(duration_seconds) / 60.0, 1), 0)
		FROM token_service_sessions WHERE outcome = 'COMPLETED' AND started_at::date = CURRENT_DATE`).
		Scan(&d.AverageServiceMinutes); err != nil {
		return nil, err
	}

	rows, err := q.QueryContext(ctx, `
		SELECT d.id, d.name, d.code, d.status,
		       COUNT(t.id) FILTER (WHERE t.status = 'WAITING'),
		       COUNT(t.id) FILTER (WHERE t.status = 'SERVING')
		FROM departments d
		LEFT JOIN tokens t ON t.department_id = d.id AND t.status IN ('WAITING', 'SERVING')
		GROUP BY d.id ORDER BY d.id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var s models.DepartmentSummary
		if err := rows.Scan(&s.ID, &s.Name, &s.Code, &s.Status, &s.Waiting, &s.Serving); err != nil {
			return nil, err
		}
		d.Departments = append(d.Departments, s)
	}
	return d, rows.Err()
}

// DepartmentToday returns today's completed and no-show counts for one department.
func (r *DashboardRepository) DepartmentToday(ctx context.Context, q DBTX, deptID int) (completed, noShows int, err error) {
	err = q.QueryRowContext(ctx, `
		SELECT (SELECT COUNT(*) FROM tokens WHERE department_id = $1 AND status = 'COMPLETED' AND completed_at::date = CURRENT_DATE),
		       (SELECT COUNT(*) FROM token_events WHERE department_id = $1 AND event_type = 'NO_SHOW' AND created_at::date = CURRENT_DATE)`,
		deptID).Scan(&completed, &noShows)
	return
}

// RefreshDailyStats recomputes today's row in daily_queue_stats for a department.
func (r *DashboardRepository) RefreshDailyStats(ctx context.Context, q DBTX, deptID int) error {
	_, err := q.ExecContext(ctx, `
		INSERT INTO daily_queue_stats
			(stat_date, department_id, total_tokens, completed, cancelled, no_shows, avg_wait_seconds, avg_service_seconds, updated_at)
		SELECT CURRENT_DATE, $1::int,
		  (SELECT COUNT(*) FROM tokens WHERE department_id = $1::int AND created_date = CURRENT_DATE),
		  (SELECT COUNT(*) FROM tokens WHERE department_id = $1::int AND created_date = CURRENT_DATE AND status = 'COMPLETED'),
		  (SELECT COUNT(*) FROM tokens WHERE department_id = $1::int AND created_date = CURRENT_DATE AND status = 'CANCELLED'),
		  (SELECT COUNT(*) FROM token_events WHERE department_id = $1::int AND event_type = 'NO_SHOW' AND created_at::date = CURRENT_DATE),
		  COALESCE((SELECT AVG(EXTRACT(EPOCH FROM (serving_at - generated_at))) FROM tokens
		            WHERE department_id = $1::int AND created_date = CURRENT_DATE AND status = 'COMPLETED'), 0)::int,
		  COALESCE((SELECT AVG(duration_seconds) FROM token_service_sessions
		            WHERE department_id = $1::int AND outcome = 'COMPLETED' AND started_at::date = CURRENT_DATE), 0)::int,
		  NOW()
		ON CONFLICT (stat_date, department_id) DO UPDATE SET
		  total_tokens = EXCLUDED.total_tokens, completed = EXCLUDED.completed, cancelled = EXCLUDED.cancelled,
		  no_shows = EXCLUDED.no_shows, avg_wait_seconds = EXCLUDED.avg_wait_seconds,
		  avg_service_seconds = EXCLUDED.avg_service_seconds, updated_at = NOW()`, deptID)
	return err
}
