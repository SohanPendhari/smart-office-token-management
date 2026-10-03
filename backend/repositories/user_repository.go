package repositories

import (
	"context"
	"database/sql"
	"errors"

	"smartoffice/models"
)

type UserRepository struct{}

const userSelect = `SELECT id, name, email, password_hash, role, department_id, is_active FROM users`

func scanUser(row *sql.Row) (*models.User, error) {
	var u models.User
	var dept sql.NullInt64
	if err := row.Scan(&u.ID, &u.Name, &u.Email, &u.PasswordHash, &u.Role, &dept, &u.IsActive); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if dept.Valid {
		d := int(dept.Int64)
		u.DepartmentID = &d
	}
	return &u, nil
}

// GetByEmail returns nil, nil when there is no such user.
func (r *UserRepository) GetByEmail(ctx context.Context, q DBTX, email string) (*models.User, error) {
	return scanUser(q.QueryRowContext(ctx, userSelect+` WHERE LOWER(email) = LOWER($1)`, email))
}

func (r *UserRepository) GetByID(ctx context.Context, q DBTX, id int) (*models.User, error) {
	return scanUser(q.QueryRowContext(ctx, userSelect+` WHERE id = $1`, id))
}
