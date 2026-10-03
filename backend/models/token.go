package models

import "time"

const (
	StatusWaiting   = "WAITING"
	StatusServing   = "SERVING"
	StatusCompleted = "COMPLETED"
	StatusCancelled = "CANCELLED"
)

type Token struct {
	ID                   int64      `json:"id"`
	TokenNumber          string     `json:"token_number"`
	VisitorID            int64      `json:"visitor_id"`
	VisitorName          string     `json:"visitor_name"`
	VisitorMobile        string     `json:"visitor_mobile"`
	DepartmentID         int        `json:"department_id"`
	DepartmentName       string     `json:"department_name"`
	DepartmentCode       string     `json:"department_code"`
	Priority             bool       `json:"priority"`
	PriorityLevel        int        `json:"priority_level"`
	Status               string     `json:"status"`
	SequenceNumber       int64      `json:"sequence_number"`
	NoShowCount          int        `json:"no_show_count"`
	GeneratedAt          time.Time  `json:"generated_at"`
	CalledAt             *time.Time `json:"called_at"`
	ServingAt            *time.Time `json:"serving_at"`
	CompletedAt          *time.Time `json:"completed_at"`
	CancelledAt          *time.Time `json:"cancelled_at"`
	EstimatedWaitSeconds int        `json:"estimated_wait_seconds"`
	CreatedDate          string     `json:"created_date"`
	CreatedBy            *int       `json:"created_by"`
	UpdatedAt            time.Time  `json:"updated_at"`

	// Live values, filled in by the service layer (0 when the token is not WAITING).
	QueuePosition int `json:"queue_position"`
	PeopleAhead   int `json:"people_ahead"`
}

type CreateTokenRequest struct {
	DepartmentID int    `json:"department_id"`
	VisitorID    int64  `json:"visitor_id"`
	Name         string `json:"name"`
	Mobile       string `json:"mobile"`
	Priority     bool   `json:"priority"`
}

type TransferRequest struct {
	DepartmentID int    `json:"department_id"`
	Reason       string `json:"reason"`
}

type PriorityRequest struct {
	Priority *bool `json:"priority"` // defaults to true when omitted
	Level    int   `json:"level"`
}

// QueueEntry is the anonymous row shown on the visitor's live queue screen.
type QueueEntry struct {
	TokenNumber string `json:"token_number"`
	Status      string `json:"status"`
	Priority    bool   `json:"priority"`
	IsYou       bool   `json:"is_you"`
}

// QueuePosition is the answer to GET /api/tokens/{id}/queue-position.
type QueuePosition struct {
	TokenID              int64        `json:"token_id"`
	TokenNumber          string       `json:"token_number"`
	DepartmentID         int          `json:"department_id"`
	DepartmentName       string       `json:"department_name"`
	DepartmentStatus     string       `json:"department_status"`
	Status               string       `json:"status"`
	QueuePosition        int          `json:"queue_position"`
	PeopleAhead          int          `json:"people_ahead"`
	EstimatedWaitSeconds int          `json:"estimated_wait_seconds"`
	CurrentlyServing     []string     `json:"currently_serving"`
	Queue                []QueueEntry `json:"queue"`
}

// StaffQueue is the answer to GET /api/queues/{departmentId}.
type StaffQueue struct {
	Department Department `json:"department"`
	Serving    []Token    `json:"serving"`
	Waiting    []Token    `json:"waiting"`
	Completed  int        `json:"completed_today"`
	NoShows    int        `json:"no_shows_today"`
}
