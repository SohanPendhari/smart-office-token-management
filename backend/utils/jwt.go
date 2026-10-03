package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"smartoffice/models"
)

type Claims struct {
	UserID       int    `json:"uid"`
	Role         string `json:"role"`
	DepartmentID *int   `json:"dept,omitempty"`
	jwt.RegisteredClaims
}

func GenerateJWT(secret string, ttl time.Duration, u models.User) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:       u.ID,
		Role:         u.Role,
		DepartmentID: u.DepartmentID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   u.Email,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

func ParseJWT(secret, tokenString string) (*Claims, error) {
	claims := &Claims{}
	tok, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil || !tok.Valid {
		return nil, errors.New("invalid or expired token")
	}
	return claims, nil
}
