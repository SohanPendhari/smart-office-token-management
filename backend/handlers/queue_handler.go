package handlers

import (
	"net/http"

	"smartoffice/middleware"
	"smartoffice/models"
	"smartoffice/services"
	"smartoffice/utils"
)

type QueueHandler struct{ svc *services.QueueService }

func NewQueueHandler(s *services.QueueService) *QueueHandler { return &QueueHandler{s} }

func (h *QueueHandler) GetQueue(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "departmentId")
	if err != nil {
		utils.Error(w, err)
		return
	}
	q, err := h.svc.GetQueue(r.Context(), int(id))
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, q)
}

func (h *QueueHandler) CallNext(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "departmentId")
	if err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.CallNext(r.Context(), middleware.ClaimsFrom(r), int(id))
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}

func (h *QueueHandler) Complete(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.Complete(r.Context(), middleware.ClaimsFrom(r), id)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}

func (h *QueueHandler) NoShow(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.NoShow(r.Context(), middleware.ClaimsFrom(r), id)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}

func (h *QueueHandler) Transfer(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	var req models.TransferRequest
	if err := utils.DecodeJSON(r, &req); err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.Transfer(r.Context(), middleware.ClaimsFrom(r), id, req)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}

func (h *QueueHandler) Priority(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	var req models.PriorityRequest
	if err := utils.DecodeJSON(r, &req); err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.SetPriority(r.Context(), middleware.ClaimsFrom(r), id, req)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}
