// Package middleware contains the HTTP middlewares: auth, logging, CORS, panic recovery.
package middleware

import (
	"context"
	"net/http"
	"strings"

	"smartoffice/utils"
)

type ctxKey struct{}

// Authenticate requires a valid "Authorization: Bearer <jwt>" header.
func Authenticate(secret string) func(http.HandlerFunc) http.HandlerFunc {
	return func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			if !strings.HasPrefix(h, "Bearer ") {
				utils.Error(w, utils.Unauthorized("missing bearer token"))
				return
			}
			claims, err := utils.ParseJWT(secret, strings.TrimSpace(strings.TrimPrefix(h, "Bearer ")))
			if err != nil {
				utils.Error(w, utils.Unauthorized(err.Error()))
				return
			}
			next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, claims)))
		}
	}
}

// ClaimsFrom returns the authenticated user's claims (nil on public routes).
func ClaimsFrom(r *http.Request) *utils.Claims {
	c, _ := r.Context().Value(ctxKey{}).(*utils.Claims)
	return c
}
