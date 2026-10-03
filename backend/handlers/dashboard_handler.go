package handlers

import (
	"net/http"

	"smartoffice/services"
	"smartoffice/utils"
)

type DashboardHandler struct{ svc *services.DashboardService }

func NewDashboardHandler(s *services.DashboardService) *DashboardHandler {
	return &DashboardHandler{s}
}

func (h *DashboardHandler) Get(w http.ResponseWriter, r *http.Request) {
	d, err := h.svc.Get(r.Context())
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, d)
}
