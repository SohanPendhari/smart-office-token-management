package utils

import (
	"regexp"
	"strings"
)

var mobileRe = regexp.MustCompile(`^\+?[0-9]{7,15}$`)

// CleanName trims and validates a visitor name.
func CleanName(name string) (string, error) {
	name = strings.Join(strings.Fields(name), " ")
	if len([]rune(name)) < 2 || len([]rune(name)) > 100 {
		return "", BadRequest("name must be between 2 and 100 characters")
	}
	return name, nil
}

// CleanMobile strips spaces/dashes and validates 7-15 digits with an optional leading +.
func CleanMobile(mobile string) (string, error) {
	r := strings.NewReplacer(" ", "", "-", "", "(", "", ")", "")
	mobile = r.Replace(strings.TrimSpace(mobile))
	if !mobileRe.MatchString(mobile) {
		return "", BadRequest("mobile number must contain 7 to 15 digits")
	}
	return mobile, nil
}
