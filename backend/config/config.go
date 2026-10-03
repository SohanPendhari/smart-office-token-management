// Package config loads runtime configuration from environment variables
// (and an optional .env file in the working directory).
package config

import (
	"bufio"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port        string
	DatabaseURL string
	JWTSecret   string
	JWTTTL      time.Duration
}

func Load() Config {
	loadDotEnv(".env")
	ttlHours, err := strconv.Atoi(get("JWT_TTL_HOURS", "12"))
	if err != nil || ttlHours <= 0 {
		ttlHours = 12
	}
	return Config{
		Port:        get("PORT", "8080"),
		DatabaseURL: get("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/smart_office?sslmode=disable"),
		JWTSecret:   get("JWT_SECRET", "dev-only-secret-change-me"),
		JWTTTL:      time.Duration(ttlHours) * time.Hour,
	}
}

func get(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

// loadDotEnv sets variables from KEY=VALUE lines without overriding variables that already exist.
func loadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.Trim(strings.TrimSpace(v), `"'`)
		if _, exists := os.LookupEnv(k); !exists {
			os.Setenv(k, v)
		}
	}
}
