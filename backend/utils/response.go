// Package utils holds small shared helpers: JSON responses, errors and JWT.
package utils

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
)

// AppError is an error that carries the HTTP status to return.
type AppError struct {
	Status  int
	Message string
}

func (e *AppError) Error() string { return e.Message }

func NewError(status int, msg string) *AppError { return &AppError{Status: status, Message: msg} }

func BadRequest(msg string) *AppError   { return NewError(http.StatusBadRequest, msg) }
func Unauthorized(msg string) *AppError { return NewError(http.StatusUnauthorized, msg) }
func Forbidden(msg string) *AppError    { return NewError(http.StatusForbidden, msg) }
func NotFound(msg string) *AppError     { return NewError(http.StatusNotFound, msg) }
func Conflict(msg string) *AppError     { return NewError(http.StatusConflict, msg) }

func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v != nil {
		if err := json.NewEncoder(w).Encode(v); err != nil {
			log.Printf("write response: %v", err)
		}
	}
}

// Error writes {"error": "..."}; unexpected errors are logged and hidden behind a generic 500.
func Error(w http.ResponseWriter, err error) {
	var ae *AppError
	if errors.As(err, &ae) {
		JSON(w, ae.Status, map[string]string{"error": ae.Message})
		return
	}
	log.Printf("internal error: %v", err)
	JSON(w, http.StatusInternalServerError, map[string]string{"error": "internal server error"})
}

// DecodeJSON reads a JSON body (max 1 MB). An empty body is allowed so optional bodies work.
func DecodeJSON(r *http.Request, dst any) error {
	if r.Body == nil {
		return nil
	}
	r.Body = http.MaxBytesReader(nil, r.Body, 1<<20)
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(dst); err != nil {
		if errors.Is(err, io.EOF) {
			return nil
		}
		return BadRequest("invalid JSON body")
	}
	return nil
}
