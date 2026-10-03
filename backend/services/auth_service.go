package services

import (
	"context"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"smartoffice/models"
	"smartoffice/utils"
)

type AuthService struct{ d *Deps }

func NewAuthService(d *Deps) *AuthService { return &AuthService{d} }

func (s *AuthService) Login(ctx context.Context, req models.LoginRequest) (*models.LoginResponse, error) {
	email := strings.TrimSpace(req.Email)
	if email == "" || req.Password == "" {
		return nil, utils.BadRequest("email and password are required")
	}
	u, err := s.d.Users.GetByEmail(ctx, s.d.DB, email)
	if err != nil {
		return nil, err
	}
	// Same message for unknown user / wrong password / inactive so accounts cannot be probed.
	invalid := utils.Unauthorized("invalid email or password")
	if u == nil || !u.IsActive {
		return nil, invalid
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
		return nil, invalid
	}
	token, err := utils.GenerateJWT(s.d.JWTSecret, time.Duration(s.d.JWTTTLHour)*time.Hour, *u)
	if err != nil {
		return nil, err
	}
	return &models.LoginResponse{Token: token, User: *u}, nil
}

func (s *AuthService) Me(ctx context.Context, c *utils.Claims) (*models.User, error) {
	u, err := s.d.Users.GetByID(ctx, s.d.DB, c.UserID)
	if err != nil {
		return nil, err
	}
	if u == nil || !u.IsActive {
		return nil, utils.Unauthorized("account is no longer active")
	}
	return u, nil
}
