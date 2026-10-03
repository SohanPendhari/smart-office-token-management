package services

import (
	"context"

	"smartoffice/models"
	"smartoffice/utils"
)

type DepartmentService struct{ d *Deps }

func NewDepartmentService(d *Deps) *DepartmentService { return &DepartmentService{d} }

func (s *DepartmentService) fill(ctx context.Context, dep *models.Department) error {
	st, err := s.d.Depts.Settings(ctx, s.d.DB, dep.ID)
	if err != nil {
		return err
	}
	m, err := s.d.Depts.Metrics(ctx, s.d.DB, dep.ID, st)
	if err != nil {
		return err
	}
	dep.Waiting = m.Waiting
	dep.Serving = m.Serving
	dep.CurrentlyServing = m.ServingNumbers
	dep.EstimatedWaitSeconds = estimateSeconds(m.Waiting, m) // a new normal token has everyone waiting ahead of it
	return nil
}

func (s *DepartmentService) List(ctx context.Context) ([]models.Department, error) {
	list, err := s.d.Depts.List(ctx, s.d.DB)
	if err != nil {
		return nil, err
	}
	for i := range list {
		if err := s.fill(ctx, &list[i]); err != nil {
			return nil, err
		}
	}
	if list == nil {
		list = []models.Department{}
	}
	return list, nil
}

func (s *DepartmentService) Get(ctx context.Context, id int) (*models.Department, error) {
	dep, err := s.d.Depts.Get(ctx, s.d.DB, id, false)
	if err != nil {
		return nil, err
	}
	if dep == nil {
		return nil, utils.NotFound("department not found")
	}
	return dep, s.fill(ctx, dep)
}

// SetPaused pauses or resumes a department. Existing tokens keep working; only new tokens are blocked.
func (s *DepartmentService) SetPaused(ctx context.Context, c *utils.Claims, id int, paused bool) (*models.Department, error) {
	if err := authorizeDept(c, id); err != nil {
		return nil, err
	}
	dep, err := s.d.Depts.Get(ctx, s.d.DB, id, false)
	if err != nil {
		return nil, err
	}
	if dep == nil {
		return nil, utils.NotFound("department not found")
	}
	status := models.DeptActive
	if paused {
		status = models.DeptPaused
	}
	if err := s.d.Depts.SetStatus(ctx, s.d.DB, id, status); err != nil {
		return nil, err
	}
	return s.Get(ctx, id)
}
