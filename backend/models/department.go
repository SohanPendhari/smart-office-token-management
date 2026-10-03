package models

const (
	DeptActive = "ACTIVE"
	DeptPaused = "PAUSED"
)

// Department is what visitors and staff see: the department plus live queue numbers.
type Department struct {
	ID                   int      `json:"id"`
	Name                 string   `json:"name"`
	Code                 string   `json:"code"`
	Status               string   `json:"status"`
	Waiting              int      `json:"waiting"`
	Serving              int      `json:"serving"`
	CurrentlyServing     []string `json:"currently_serving"`
	EstimatedWaitSeconds int      `json:"estimated_wait_seconds"` // for a token generated right now
	AllowVisitorPriority bool     `json:"allow_visitor_priority"`
}

// Settings holds the per-department rules from queue_settings.
type Settings struct {
	AvgServiceMinutes    int
	MaxNoShows           int
	AllowVisitorPriority bool
}

// Metrics are the live numbers used for the waiting-time estimate.
type Metrics struct {
	Waiting           int
	Serving           int
	ServingNumbers    []string
	ActiveCounters    int
	AvgServiceSeconds int
}
