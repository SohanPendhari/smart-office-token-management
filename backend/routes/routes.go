// Package routes wires URLs to handlers using Go 1.22+ net/http method+path patterns.
package routes

import (
	"net/http"
	"strings"

	"smartoffice/handlers"
	"smartoffice/middleware"
	"smartoffice/services"
	"smartoffice/utils"
)

func New(d *services.Deps) http.Handler {
	auth := handlers.NewAuthHandler(services.NewAuthService(d))
	depts := handlers.NewDepartmentHandler(services.NewDepartmentService(d))
	tokens := handlers.NewTokenHandler(services.NewTokenService(d))
	queues := handlers.NewQueueHandler(services.NewQueueService(d))
	dash := handlers.NewDashboardHandler(services.NewDashboardService(d))

	staff := middleware.Authenticate(d.JWTSecret)

	// optionalClaims reads a staff JWT if one was sent, without rejecting visitors.
	optionalClaims := func(r *http.Request) *utils.Claims {
		h := r.Header.Get("Authorization")
		if !strings.HasPrefix(h, "Bearer ") {
			return nil
		}
		c, err := utils.ParseJWT(d.JWTSecret, strings.TrimSpace(strings.TrimPrefix(h, "Bearer ")))
		if err != nil {
			return nil
		}
		return c
	}

	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		utils.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Authentication
	mux.HandleFunc("POST /api/auth/login", auth.Login)
	mux.HandleFunc("GET /api/auth/me", staff(auth.Me))

	// Departments (public read, staff pause/resume)
	mux.HandleFunc("GET /api/departments", depts.List)
	mux.HandleFunc("GET /api/departments/{id}", depts.Get)
	mux.HandleFunc("PATCH /api/departments/{id}/pause", staff(depts.Pause()))
	mux.HandleFunc("PATCH /api/departments/{id}/resume", staff(depts.Resume()))

	// Visitor
	mux.HandleFunc("POST /api/visitors", tokens.CreateVisitor)
	mux.HandleFunc("POST /api/tokens", tokens.Generate(optionalClaims))
	mux.HandleFunc("GET /api/tokens/{id}", tokens.Get)
	mux.HandleFunc("PATCH /api/tokens/{id}/cancel", tokens.Cancel)
	mux.HandleFunc("GET /api/tokens/{id}/queue-position", tokens.QueuePosition)

	// Staff
	mux.HandleFunc("GET /api/queues/{departmentId}", staff(queues.GetQueue))
	mux.HandleFunc("POST /api/queues/{departmentId}/call-next", staff(queues.CallNext))
	mux.HandleFunc("POST /api/tokens/{id}/complete", staff(queues.Complete))
	mux.HandleFunc("POST /api/tokens/{id}/no-show", staff(queues.NoShow))
	mux.HandleFunc("POST /api/tokens/{id}/transfer", staff(queues.Transfer))
	mux.HandleFunc("POST /api/tokens/{id}/priority", staff(queues.Priority))

	// Dashboard
	mux.HandleFunc("GET /api/dashboard", staff(dash.Get))

	return middleware.Recover(middleware.Logging(middleware.CORS(mux)))
}
