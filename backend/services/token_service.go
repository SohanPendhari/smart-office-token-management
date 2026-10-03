package services

import (
	"context"
	"database/sql"
	"fmt"

	"smartoffice/database"
	"smartoffice/models"
	"smartoffice/utils"
)

type TokenService struct{ d *Deps }

func NewTokenService(d *Deps) *TokenService { return &TokenService{d} }

func (s *TokenService) CreateVisitor(ctx context.Context, req models.CreateVisitorRequest) (*models.Visitor, error) {
	name, err := utils.CleanName(req.Name)
	if err != nil {
		return nil, err
	}
	mobile, err := utils.CleanMobile(req.Mobile)
	if err != nil {
		return nil, err
	}
	return s.d.Tokens.InsertVisitor(ctx, s.d.DB, name, mobile)
}

// Generate creates a token. The token NUMBER is always produced here, never by the app.
// c is nil for visitors and set when a logged-in staff member issues a token.
func (s *TokenService) Generate(ctx context.Context, req models.CreateTokenRequest, c *utils.Claims) (*models.Token, error) {
	if req.DepartmentID <= 0 {
		return nil, utils.BadRequest("department_id is required")
	}
	var name, mobile string
	if req.VisitorID == 0 {
		var err error
		if name, err = utils.CleanName(req.Name); err != nil {
			return nil, err
		}
		if mobile, err = utils.CleanMobile(req.Mobile); err != nil {
			return nil, err
		}
	}

	var tokenID int64
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		dep, err := s.d.Depts.Get(ctx, tx, req.DepartmentID, true)
		if err != nil {
			return err
		}
		if dep == nil {
			return utils.NotFound("department not found")
		}
		if dep.Status == models.DeptPaused {
			return utils.Conflict("this department is paused; new tokens are temporarily unavailable")
		}
		st, err := s.d.Depts.Settings(ctx, tx, dep.ID)
		if err != nil {
			return err
		}
		if req.Priority && c == nil && !st.AllowVisitorPriority {
			return utils.BadRequest("priority requests are not allowed for this department")
		}

		visitorID := req.VisitorID
		if visitorID != 0 {
			v, err := s.d.Tokens.GetVisitor(ctx, tx, visitorID)
			if err != nil {
				return err
			}
			if v == nil {
				return utils.NotFound("visitor not found")
			}
			mobile = v.Mobile
		}

		if existing, err := s.d.Tokens.ActiveTokenForMobile(ctx, tx, mobile, dep.ID); err != nil {
			return err
		} else if existing != nil {
			return utils.Conflict(fmt.Sprintf("this mobile number already has an active %s token (%s)", dep.Name, existing.TokenNumber))
		}

		if visitorID == 0 {
			v, err := s.d.Tokens.InsertVisitor(ctx, tx, name, mobile)
			if err != nil {
				return err
			}
			visitorID = v.ID
		}

		number, err := s.d.Tokens.NextTokenNumber(ctx, tx, dep.ID, dep.Code)
		if err != nil {
			return err
		}
		tokenID, err = s.d.Tokens.Insert(ctx, tx, number, visitorID, dep.ID, req.Priority, 0, userIDPtr(c))
		if err != nil {
			return err
		}

		ahead, err := s.d.Tokens.PeopleAhead(ctx, tx, tokenID)
		if err != nil {
			return err
		}
		m, err := s.d.Depts.Metrics(ctx, tx, dep.ID, st)
		if err != nil {
			return err
		}
		if err := s.d.Tokens.SetEstimate(ctx, tx, tokenID, estimateSeconds(ahead, m)); err != nil {
			return err
		}
		if err := s.d.Tokens.AddEvent(ctx, tx, tokenID, dep.ID, "GENERATED", "", models.StatusWaiting, userIDPtr(c), ""); err != nil {
			return err
		}
		return s.d.Dashboard.RefreshDailyStats(ctx, tx, dep.ID)
	})
	if err != nil {
		return nil, err
	}
	return s.Get(ctx, tokenID)
}

func (s *TokenService) Get(ctx context.Context, id int64) (*models.Token, error) {
	t, err := s.d.Tokens.Get(ctx, s.d.DB, id, false)
	if err != nil {
		return nil, err
	}
	if t == nil {
		return nil, utils.NotFound("token not found")
	}
	return t, enrich(ctx, s.d, s.d.DB, t)
}

// Cancel lets a visitor give up a token that is still waiting (a token being served cannot be cancelled).
func (s *TokenService) Cancel(ctx context.Context, id int64) (*models.Token, error) {
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		t, err := s.d.Tokens.Get(ctx, tx, id, true)
		if err != nil {
			return err
		}
		if t == nil {
			return utils.NotFound("token not found")
		}
		if t.Status != models.StatusWaiting {
			return utils.Conflict("only a waiting token can be cancelled (current status: " + t.Status + ")")
		}
		if err := s.d.Tokens.SetCancelled(ctx, tx, id, t.NoShowCount); err != nil {
			return err
		}
		if err := s.d.Tokens.AddEvent(ctx, tx, id, t.DepartmentID, "CANCELLED", t.Status, models.StatusCancelled, nil, "cancelled by visitor"); err != nil {
			return err
		}
		return s.d.Dashboard.RefreshDailyStats(ctx, tx, t.DepartmentID)
	})
	if err != nil {
		return nil, err
	}
	return s.Get(ctx, id)
}

// QueuePosition powers the visitor's live queue screen. It never exposes other visitors' details.
func (s *TokenService) QueuePosition(ctx context.Context, id int64) (*models.QueuePosition, error) {
	t, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	dep, err := s.d.Depts.Get(ctx, s.d.DB, t.DepartmentID, false)
	if err != nil || dep == nil {
		return nil, err
	}
	st, err := s.d.Depts.Settings(ctx, s.d.DB, t.DepartmentID)
	if err != nil {
		return nil, err
	}
	m, err := s.d.Depts.Metrics(ctx, s.d.DB, t.DepartmentID, st)
	if err != nil {
		return nil, err
	}
	out := &models.QueuePosition{
		TokenID: t.ID, TokenNumber: t.TokenNumber, DepartmentID: dep.ID, DepartmentName: dep.Name,
		DepartmentStatus: dep.Status, Status: t.Status, QueuePosition: t.QueuePosition, PeopleAhead: t.PeopleAhead,
		EstimatedWaitSeconds: t.EstimatedWaitSeconds, CurrentlyServing: m.ServingNumbers, Queue: []models.QueueEntry{},
	}
	if t.Status == models.StatusWaiting {
		waiting, err := s.d.Tokens.ListWaiting(ctx, s.d.DB, t.DepartmentID)
		if err != nil {
			return nil, err
		}
		for _, w := range waiting {
			out.Queue = append(out.Queue, models.QueueEntry{
				TokenNumber: w.TokenNumber, Status: w.Status, Priority: w.Priority, IsYou: w.ID == t.ID,
			})
			if w.ID == t.ID {
				break // show only the people ahead plus the visitor
			}
		}
	}
	return out, nil
}
