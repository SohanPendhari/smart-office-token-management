package services

import (
	"context"
	"database/sql"

	"smartoffice/database"
	"smartoffice/models"
	"smartoffice/utils"
)

type QueueService struct{ d *Deps }

func NewQueueService(d *Deps) *QueueService { return &QueueService{d} }

// GetQueue is the staff view of one department.
func (s *QueueService) GetQueue(ctx context.Context, deptID int) (*models.StaffQueue, error) {
	depSvc := NewDepartmentService(s.d)
	dep, err := depSvc.Get(ctx, deptID)
	if err != nil {
		return nil, err
	}
	serving, err := s.d.Tokens.ListServing(ctx, s.d.DB, deptID)
	if err != nil {
		return nil, err
	}
	waiting, err := s.d.Tokens.ListWaiting(ctx, s.d.DB, deptID)
	if err != nil {
		return nil, err
	}
	st, err := s.d.Depts.Settings(ctx, s.d.DB, deptID)
	if err != nil {
		return nil, err
	}
	m, err := s.d.Depts.Metrics(ctx, s.d.DB, deptID, st)
	if err != nil {
		return nil, err
	}
	for i := range waiting { // list is already in call order, so position = index + 1
		waiting[i].PeopleAhead = i
		waiting[i].QueuePosition = i + 1
		waiting[i].EstimatedWaitSeconds = estimateSeconds(i, m)
	}
	completed, noShows, err := s.d.Dashboard.DepartmentToday(ctx, s.d.DB, deptID)
	if err != nil {
		return nil, err
	}
	return &models.StaffQueue{Department: *dep, Serving: serving, Waiting: waiting, Completed: completed, NoShows: noShows}, nil
}

// CallNext serves the next token: priority first, then oldest normal. It never interrupts a token
// the same staff member is still serving, and row locking prevents two staff getting the same token.
func (s *QueueService) CallNext(ctx context.Context, c *utils.Claims, deptID int) (*models.Token, error) {
	if err := authorizeDept(c, deptID); err != nil {
		return nil, err
	}
	var tokenID int64
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		dep, err := s.d.Depts.Get(ctx, tx, deptID, false)
		if err != nil {
			return err
		}
		if dep == nil {
			return utils.NotFound("department not found")
		}
		busy, err := s.d.Tokens.StaffBusy(ctx, tx, c.UserID, deptID)
		if err != nil {
			return err
		}
		if busy {
			return utils.Conflict("complete or mark no-show on your current token before calling the next one")
		}
		id, err := s.d.Tokens.LockNextWaiting(ctx, tx, deptID)
		if err != nil {
			return err
		}
		if id == 0 {
			return utils.NotFound("no tokens are waiting in this department")
		}
		counter, err := s.d.Depts.UserCounter(ctx, tx, c.UserID, deptID)
		if err != nil {
			return err
		}
		if counter == nil {
			if counter, err = s.d.Depts.FreeCounter(ctx, tx, deptID); err != nil {
				return err
			}
		}
		if err := s.d.Tokens.SetServing(ctx, tx, id); err != nil {
			return err
		}
		if err := s.d.Tokens.OpenSession(ctx, tx, id, deptID, counter, c.UserID); err != nil {
			return err
		}
		tokenID = id
		return s.d.Tokens.AddEvent(ctx, tx, id, deptID, "CALLED", models.StatusWaiting, models.StatusServing, userIDPtr(c), "")
	})
	if err != nil {
		return nil, err
	}
	return NewTokenService(s.d).Get(ctx, tokenID)
}

// lockToken loads a token with a row lock and checks the caller may manage its department.
func (s *QueueService) lockToken(ctx context.Context, tx *sql.Tx, c *utils.Claims, id int64) (*models.Token, error) {
	t, err := s.d.Tokens.Get(ctx, tx, id, true)
	if err != nil {
		return nil, err
	}
	if t == nil {
		return nil, utils.NotFound("token not found")
	}
	if err := authorizeDept(c, t.DepartmentID); err != nil {
		return nil, err
	}
	return t, nil
}

func (s *QueueService) Complete(ctx context.Context, c *utils.Claims, id int64) (*models.Token, error) {
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		t, err := s.lockToken(ctx, tx, c, id)
		if err != nil {
			return err
		}
		if t.Status != models.StatusServing {
			return utils.Conflict("only a token that is being served can be completed (current status: " + t.Status + ")")
		}
		if err := s.d.Tokens.SetCompleted(ctx, tx, id); err != nil {
			return err
		}
		if err := s.d.Tokens.CloseSession(ctx, tx, id, "COMPLETED"); err != nil {
			return err
		}
		if err := s.d.Tokens.AddEvent(ctx, tx, id, t.DepartmentID, "COMPLETED", t.Status, models.StatusCompleted, userIDPtr(c), ""); err != nil {
			return err
		}
		return s.d.Dashboard.RefreshDailyStats(ctx, tx, t.DepartmentID)
	})
	if err != nil {
		return nil, err
	}
	return NewTokenService(s.d).Get(ctx, id)
}

// NoShow: 1st time -> back to WAITING at the END of the queue; 2nd time (max_no_shows) -> CANCELLED.
func (s *QueueService) NoShow(ctx context.Context, c *utils.Claims, id int64) (*models.Token, error) {
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		t, err := s.lockToken(ctx, tx, c, id)
		if err != nil {
			return err
		}
		if t.Status != models.StatusServing {
			return utils.Conflict("only a token that is being served can be marked no-show (current status: " + t.Status + ")")
		}
		st, err := s.d.Depts.Settings(ctx, tx, t.DepartmentID)
		if err != nil {
			return err
		}
		count := t.NoShowCount + 1
		to, note := models.StatusWaiting, "moved to end of queue"
		if count >= st.MaxNoShows {
			to, note = models.StatusCancelled, "cancelled after repeated no-shows"
			err = s.d.Tokens.SetCancelled(ctx, tx, id, count)
		} else {
			err = s.d.Tokens.Requeue(ctx, tx, id, count)
		}
		if err != nil {
			return err
		}
		if err := s.d.Tokens.CloseSession(ctx, tx, id, "NO_SHOW"); err != nil {
			return err
		}
		if err := s.d.Tokens.AddEvent(ctx, tx, id, t.DepartmentID, "NO_SHOW", t.Status, to, userIDPtr(c), note); err != nil {
			return err
		}
		return s.d.Dashboard.RefreshDailyStats(ctx, tx, t.DepartmentID)
	})
	if err != nil {
		return nil, err
	}
	return NewTokenService(s.d).Get(ctx, id)
}

// Transfer moves a waiting or serving token to another department's queue (at its end).
func (s *QueueService) Transfer(ctx context.Context, c *utils.Claims, id int64, req models.TransferRequest) (*models.Token, error) {
	if req.DepartmentID <= 0 {
		return nil, utils.BadRequest("department_id is required")
	}
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		t, err := s.lockToken(ctx, tx, c, id)
		if err != nil {
			return err
		}
		if t.Status != models.StatusWaiting && t.Status != models.StatusServing {
			return utils.Conflict("only a waiting or serving token can be transferred (current status: " + t.Status + ")")
		}
		if t.DepartmentID == req.DepartmentID {
			return utils.BadRequest("token is already in that department")
		}
		target, err := s.d.Depts.Get(ctx, tx, req.DepartmentID, false)
		if err != nil {
			return err
		}
		if target == nil {
			return utils.NotFound("target department not found")
		}
		from := t.DepartmentID
		if t.Status == models.StatusServing {
			if err := s.d.Tokens.CloseSession(ctx, tx, id, "TRANSFERRED"); err != nil {
				return err
			}
		}
		if err := s.d.Tokens.AddTransfer(ctx, tx, id, from, target.ID, userIDPtr(c), req.Reason); err != nil {
			return err
		}
		if err := s.d.Tokens.MoveToDepartment(ctx, tx, id, target.ID); err != nil {
			return err
		}
		if err := s.d.Tokens.AddEvent(ctx, tx, id, target.ID, "TRANSFERRED", t.Status, models.StatusWaiting, userIDPtr(c),
			"from "+t.DepartmentName+" to "+target.Name); err != nil {
			return err
		}
		ahead, err := s.d.Tokens.PeopleAhead(ctx, tx, id)
		if err != nil {
			return err
		}
		st, err := s.d.Depts.Settings(ctx, tx, target.ID)
		if err != nil {
			return err
		}
		m, err := s.d.Depts.Metrics(ctx, tx, target.ID, st)
		if err != nil {
			return err
		}
		if err := s.d.Tokens.SetEstimate(ctx, tx, id, estimateSeconds(ahead, m)); err != nil {
			return err
		}
		if err := s.d.Dashboard.RefreshDailyStats(ctx, tx, from); err != nil {
			return err
		}
		return s.d.Dashboard.RefreshDailyStats(ctx, tx, target.ID)
	})
	if err != nil {
		return nil, err
	}
	return NewTokenService(s.d).Get(ctx, id)
}

// SetPriority only re-orders the WAITING list. It never touches a token that is already being served.
func (s *QueueService) SetPriority(ctx context.Context, c *utils.Claims, id int64, req models.PriorityRequest) (*models.Token, error) {
	priority := true
	if req.Priority != nil {
		priority = *req.Priority
	}
	if req.Level < 0 || req.Level > 10 {
		return nil, utils.BadRequest("level must be between 0 and 10")
	}
	err := database.WithTx(ctx, s.d.DB, func(tx *sql.Tx) error {
		t, err := s.lockToken(ctx, tx, c, id)
		if err != nil {
			return err
		}
		if t.Status != models.StatusWaiting {
			return utils.Conflict("priority can only be changed on a waiting token (current status: " + t.Status + ")")
		}
		if err := s.d.Tokens.SetPriority(ctx, tx, id, priority, req.Level); err != nil {
			return err
		}
		ev := "PRIORITY_SET"
		if !priority {
			ev = "PRIORITY_REMOVED"
		}
		return s.d.Tokens.AddEvent(ctx, tx, id, t.DepartmentID, ev, t.Status, t.Status, userIDPtr(c), "")
	})
	if err != nil {
		return nil, err
	}
	return NewTokenService(s.d).Get(ctx, id)
}
