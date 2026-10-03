package models

import "time"

type Visitor struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Mobile    string    `json:"mobile"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateVisitorRequest struct {
	Name   string `json:"name"`
	Mobile string `json:"mobile"`
}
