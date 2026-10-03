package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"smartoffice/config"
	"smartoffice/database"
	"smartoffice/repositories"
	"smartoffice/routes"
	"smartoffice/services"
)

func main() {
	cfg := config.Load()

	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer db.Close()

	deps := &services.Deps{
		DB:         db,
		Users:      &repositories.UserRepository{},
		Tokens:     &repositories.TokenRepository{},
		Depts:      &repositories.DepartmentRepository{},
		Dashboard:  &repositories.DashboardRepository{},
		JWTSecret:  cfg.JWTSecret,
		JWTTTLHour: int(cfg.JWTTTL / time.Hour),
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           routes.New(deps),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
	}

	go func() {
		log.Printf("Smart Office Queue API listening on http://0.0.0.0:%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	log.Println("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}
