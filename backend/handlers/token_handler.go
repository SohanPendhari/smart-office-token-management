package handlers

import (
	"net/http"

	"smartoffice/models"
	"smartoffice/services"
	"smartoffice/utils"
)

type TokenHandler struct{ svc *services.TokenService }

func NewTokenHandler(s *services.TokenService) *TokenHandler { return &TokenHandler{s} }

func (h *TokenHandler) CreateVisitor(w http.ResponseWriter, r *http.Request) {
	var req models.CreateVisitorRequest
	if err := utils.DecodeJSON(r, &req); err != nil {
		utils.Error(w, err)
		return
	}
	v, err := h.svc.CreateVisitor(r.Context(), req)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusCreated, v)
}

// Generate is public (visitors). If a valid staff JWT is sent we record who issued it.
func (h *TokenHandler) Generate(authOptional func(*http.Request) *utils.Claims) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req models.CreateTokenRequest
		if err := utils.DecodeJSON(r, &req); err != nil {
			utils.Error(w, err)
			return
		}
		t, err := h.svc.Generate(r.Context(), req, authOptional(r))
		if err != nil {
			utils.Error(w, err)
			return
		}
		utils.JSON(w, http.StatusCreated, t)
	}
}

func (h *TokenHandler) Get(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.Get(r.Context(), id)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}

func (h *TokenHandler) Cancel(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	t, err := h.svc.Cancel(r.Context(), id)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, t)
}

func (h *TokenHandler) QueuePosition(w http.ResponseWriter, r *http.Request) {
	id, err := pathID(r, "id")
	if err != nil {
		utils.Error(w, err)
		return
	}
	qp, err := h.svc.QueuePosition(r.Context(), id)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, qp)
}
