// Package handlers translates HTTP <-> service calls. No business rules live here.
package handlers

import (
	"net/http"
	"strconv"

	"smartoffice/utils"
)

func pathID(r *http.Request, name string) (int64, error) {
	id, err := strconv.ParseInt(r.PathValue(name), 10, 64)
	if err != nil || id <= 0 {
		return 0, utils.BadRequest("invalid " + name)
	}
	return id, nil
}
