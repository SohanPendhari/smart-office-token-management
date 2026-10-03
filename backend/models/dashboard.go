package models

type DepartmentSummary struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	Code    string `json:"code"`
	Status  string `json:"status"`
	Waiting int    `json:"waiting"`
	Serving int    `json:"serving"`
}

type Dashboard struct {
	Waiting               int                 `json:"waiting"`
	Serving               int                 `json:"serving"`
	Completed             int                 `json:"completed"`
	NoShows               int                 `json:"no_shows"`
	AverageWaitingMinutes float64             `json:"average_waiting_minutes"`
	AverageServiceMinutes float64             `json:"average_service_minutes"`
	Departments           []DepartmentSummary `json:"departments"`
}
