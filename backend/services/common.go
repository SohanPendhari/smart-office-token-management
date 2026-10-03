// Package services holds the business rules. Handlers call services; services call repositories.
package services

import (
	"context"
	"database/sql"

	"smartoffice/models"
	"smartoffice/repositories"
	"smartoffice/utils"
)

// Deps bundles what every service needs.
type Deps struct {
	DB         *sql.DB
	Users      *repositories.UserRepository
	Tokens     *repositories.TokenRepository
	Depts      *repositories.DepartmentRepository
	Dashboard  *repositories.DashboardRepository
	JWTSecret  string
	JWTTTLHour int
}

// authorizeDept: admins may act on any department, staff only on their own.
func authorizeDept(c *utils.Claims, deptID int) error {
	if c == nil {
		return utils.Unauthorized("login required")
	}
	if c.Role == models.RoleAdmin {
		return nil
	}
	if c.DepartmentID != nil && *c.DepartmentID == deptID {
		return nil
	}
	return utils.Forbidden("you can only manage your own department")
}

func userIDPtr(c *utils.Claims) *int {
	if c == nil {
		return nil
	}
	id := c.UserID
	return &id
}

// estimateSeconds = people ahead x average service time / active counters (rounded up).
func estimateSeconds(ahead int, m models.Metrics) int {
	if ahead <= 0 {
		return 0
	}
	counters := m.ActiveCounters
	if counters < 1 {
		counters = 1
	}
	return (ahead*m.AvgServiceSeconds + counters - 1) / counters
}

// enrich fills the live queue_position / people_ahead / estimated wait of a WAITING token.
func enrich(ctx context.Context, d *Deps, q repositories.DBTX, t *models.Token) error {
	if t.Status != models.StatusWaiting {
		t.QueuePosition, t.PeopleAhead = 0, 0
		if t.Status != models.StatusServing {
			t.EstimatedWaitSeconds = 0
		}
		return nil
	}
	ahead, err := d.Tokens.PeopleAhead(ctx, q, t.ID)
	if err != nil {
		return err
	}
	st, err := d.Depts.Settings(ctx, q, t.DepartmentID)
	if err != nil {
		return err
	}
	m, err := d.Depts.Metrics(ctx, q, t.DepartmentID, st)
	if err != nil {
		return err
	}
	t.PeopleAhead = ahead
	t.QueuePosition = ahead + 1
	t.EstimatedWaitSeconds = estimateSeconds(ahead, m)
	return nil
}
