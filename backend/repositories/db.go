// Package repositories contains all SQL. Every method receives a DBTX so the same code
// runs on a plain *sql.DB or inside a *sql.Tx owned by the service layer.
package repositories

import (
	"context"
	"database/sql"
)

type DBTX interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}
