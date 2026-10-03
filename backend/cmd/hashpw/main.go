// hashpw prints a bcrypt hash, e.g. to create new users:  go run ./cmd/hashpw "MyPassword"
package main

import (
	"fmt"
	"os"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println(`usage: go run ./cmd/hashpw "<password>"`)
		os.Exit(1)
	}
	h, err := bcrypt.GenerateFromPassword([]byte(os.Args[1]), 10)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	fmt.Println(string(h))
}
