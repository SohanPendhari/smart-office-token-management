package services

import (
	"context"

	"smartoffice/models"
)

type DashboardService struct{ d *Deps }

func NewDashboardService(d *Deps) *DashboardService { return &DashboardService{d} }

func (s *DashboardService) Get(ctx context.Context) (*models.Dashboard, error) {
	return s.d.Dashboard.Summary(ctx, s.d.DB)
}
