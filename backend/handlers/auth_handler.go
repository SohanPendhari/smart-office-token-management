package handlers

import (
	"net/http"

	"smartoffice/middleware"
	"smartoffice/models"
	"smartoffice/services"
	"smartoffice/utils"
)

type AuthHandler struct{ svc *services.AuthService }

func NewAuthHandler(s *services.AuthService) *AuthHandler { return &AuthHandler{s} }

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req models.LoginRequest
	if err := utils.DecodeJSON(r, &req); err != nil {
		utils.Error(w, err)
		return
	}
	res, err := h.svc.Login(r.Context(), req)
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, res)
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	u, err := h.svc.Me(r.Context(), middleware.ClaimsFrom(r))
	if err != nil {
		utils.Error(w, err)
		return
	}
	utils.JSON(w, http.StatusOK, u)
}
