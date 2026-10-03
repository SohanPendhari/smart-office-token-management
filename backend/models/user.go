package models

type User struct {
	ID           int    `json:"id"`
	Name         string `json:"name"`
	Email        string `json:"email,omitempty"`
	Role         string `json:"role"`
	DepartmentID *int   `json:"department_id,omitempty"`
	IsActive     bool   `json:"-"`
	PasswordHash string `json:"-"`
}

const (
	RoleAdmin = "ADMIN"
	RoleStaff = "STAFF"
)

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}
