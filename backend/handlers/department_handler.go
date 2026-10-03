package handlers

import (
	"net/http"

	"smartoffice/middleware"
	"smartoffice/services"
	"smartoffice/utils"
)

type DepartmentHandler struct{ svc *services.DepartmentService }

func NewDepartmentHandler(s *services.DepartmentService) *DepartmentHandler {
	return &DepartmentHandler{s}
}

func (h *DepartmentHandler) List(w http.ResponseWriter, r *http.Request) {
	list, err := h.svc.List(r.Context())
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, list)
}

func (h *DepartmentHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	d, err := h.svc.Get(r.Context(), int(id))
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, d)
}

func (h *DepartmentHandler) setPaused(paused bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := pathID(r, "id")
		if err != nil {
			utils.Error(w, err)
			return
		}
		d, err := h.svc.SetPaused(r.Context(), middleware.ClaimsFrom(r), int(id), paused)
		if err != nil {
			utils.Error(w, err)
			return
		}
		utils.JSON(w, http.StatusOK, d)
	}
}

func (h *DepartmentHandler) Pause() http.HandlerFunc  { return h.setPaused(true) }
func (h *DepartmentHandler) Resume() http.HandlerFunc { return h.setPaused(false) }
