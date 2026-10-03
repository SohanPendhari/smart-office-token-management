// smoketest runs the whole queue rulebook against a RUNNING backend:
//
//	go run ./cmd/smoketest            (BASE_URL defaults to http://localhost:8080)
//
// It drains all queues first, so run it on a demo database, not on live data.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

var (
	base   = envOr("BASE_URL", "http://localhost:8080")
	passed int
	failed int
	seq    = time.Now().UnixNano() % 100000000
)

type obj = map[string]any

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func call(method, path, token string, body any) (int, obj) {
	var rd *bytes.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	} else {
		rd = bytes.NewReader(nil)
	}
	req, _ := http.NewRequest(method, base+path, rd)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Println("request failed:", err)
		os.Exit(2)
	}
	defer res.Body.Close()
	var out obj
	_ = json.NewDecoder(res.Body).Decode(&out)
	return res.StatusCode, out
}

func check(name string, ok bool, detail ...any) {
	if ok {
		passed++
		fmt.Printf("  PASS  %s\n", name)
	} else {
		failed++
		fmt.Printf("  FAIL  %s  %v\n", name, detail)
	}
}

func login(email, pw string) string {
	_, r := call("POST", "/api/auth/login", "", obj{"email": email, "password": pw})
	t, _ := r["token"].(string)
	return t
}

func mobile() string { seq++; return fmt.Sprintf("9%09d", seq%1000000000) }

func gen(dept int, priority bool) (int, obj) {
	return call("POST", "/api/tokens", "", obj{"department_id": dept, "name": "Test Visitor", "mobile": mobile(), "priority": priority})
}

func num(o obj, k string) float64    { v, _ := o[k].(float64); return v }
func str(o obj, k string) string     { v, _ := o[k].(string); return v }
func id(o obj) int                   { return int(num(o, "id")) }
func path(f string, a ...any) string { return fmt.Sprintf(f, a...) }

func waitingNumbers(tok string, dept int) []string {
	_, q := call("GET", path("/api/queues/%d", dept), tok, nil)
	var out []string
	list, _ := q["waiting"].([]any)
	for _, w := range list {
		out = append(out, str(w.(obj), "token_number"))
	}
	return out
}

func main() {
	fmt.Println("Smoke test against", base)
	st, _ := call("GET", "/api/health", "", nil)
	check("health endpoint", st == 200)

	fmt.Println("\n[Auth]")
	st, _ = call("POST", "/api/auth/login", "", obj{"email": "admin@smartoffice.com", "password": "wrong"})
	check("wrong password -> 401", st == 401, st)
	admin := login("admin@smartoffice.com", "Admin@123")
	itStaff := login("it.staff@smartoffice.com", "Staff@123")
	hrStaff := login("hr.staff@smartoffice.com", "Staff@123")
	accStaff := login("accounts.staff@smartoffice.com", "Staff@123")
	admStaff := login("admin.staff@smartoffice.com", "Staff@123")
	check("admin + 4 staff can log in", admin != "" && itStaff != "" && hrStaff != "" && accStaff != "" && admStaff != "")
	st, _ = call("GET", "/api/dashboard", "", nil)
	check("staff endpoint without token -> 401", st == 401, st)

	fmt.Println("\n[Prepare] draining existing queues")
	for d := 1; d <= 4; d++ {
		for i := 0; i < 500; i++ {
			// finish whatever is being served, then keep calling until empty
			_, q := call("GET", path("/api/queues/%d", d), admin, nil)
			for _, s := range q["serving"].([]any) {
				call("POST", path("/api/tokens/%d/complete", id(s.(obj))), admin, nil)
			}
			st, _ := call("POST", path("/api/queues/%d/call-next", d), admin, nil)
			if st != 200 {
				break
			}
		}
		_, q := call("GET", path("/api/queues/%d", d), admin, nil)
		for _, s := range q["serving"].([]any) {
			call("POST", path("/api/tokens/%d/complete", id(s.(obj))), admin, nil)
		}
	}

	fmt.Println("\n[Visitor] token generation")
	nums := map[string]bool{}
	for d, prefix := range map[int]string{1: "IT-", 2: "HR-", 3: "ACC-", 4: "ADM-"} {
		st, t := gen(d, false)
		check(fmt.Sprintf("generate token in department %d (%s...)", d, prefix), st == 201 && strings.HasPrefix(str(t, "token_number"), prefix), st, t)
		nums[str(t, "token_number")] = true
		call("PATCH", path("/api/tokens/%d/cancel", id(t)), "", nil)
	}
	check("token numbers are unique", len(nums) == 4)
	m := mobile()
	st, t1 := call("POST", "/api/tokens", "", obj{"department_id": 1, "name": "Dup Visitor", "mobile": m})
	st2, _ := call("POST", "/api/tokens", "", obj{"department_id": 1, "name": "Dup Visitor", "mobile": m})
	check("same mobile cannot hold two active tokens in one department", st == 201 && st2 == 409, st, st2)
	call("PATCH", path("/api/tokens/%d/cancel", id(t1)), "", nil)
	st, _ = call("POST", "/api/tokens", "", obj{"department_id": 1, "name": "X", "mobile": "12"})
	check("invalid name/mobile rejected", st == 400, st)
	st, _ = call("POST", "/api/tokens", "", obj{"department_id": 99, "name": "Valid Name", "mobile": mobile()})
	check("unknown department -> 404", st == 404, st)

	fmt.Println("\n[Logic] priority never interrupts, priority goes before normal, FIFO inside each group")
	_, n1 := gen(1, false)
	_, n2 := gen(1, false)
	_, n3 := gen(1, false)
	check("departments have separate queues (HR unaffected)", len(waitingNumbers(admin, 2)) == 0)
	st, served := call("POST", "/api/queues/1/call-next", itStaff, nil)
	check("call next serves the oldest token", st == 200 && str(served, "token_number") == str(n1, "token_number") && str(served, "status") == "SERVING", st, served)
	_, p1 := gen(1, true)
	w := waitingNumbers(admin, 1)
	check("priority token waits ahead of normal ones", len(w) == 3 && w[0] == str(p1, "token_number") && w[1] == str(n2, "token_number") && w[2] == str(n3, "token_number"), w)
	_, cur := call("GET", path("/api/tokens/%d", id(n1)), "", nil)
	check("priority arrival did NOT interrupt the serving token", str(cur, "status") == "SERVING", cur)
	st, _ = call("POST", "/api/queues/1/call-next", itStaff, nil)
	check("call next is refused while staff is still serving", st == 409, st)
	_, pos := call("GET", path("/api/tokens/%d/queue-position", id(n3)), "", nil)
	check("queue position = 3 and 2 people ahead", num(pos, "queue_position") == 3 && num(pos, "people_ahead") == 2, pos)
	est3 := num(pos, "estimated_wait_seconds")
	// 2 ahead x average service time (5 min default until 5 real services exist, then the real average, min 1 min)
	check("estimated wait = people ahead x average service time", est3 >= 120 && int(est3)%2 == 0, est3)
	check("live queue lists the people ahead plus you", len(pos["queue"].([]any)) == 3, pos["queue"])

	st, c1 := call("POST", path("/api/tokens/%d/complete", id(n1)), itStaff, nil)
	check("complete serving token", st == 200 && str(c1, "status") == "COMPLETED" && c1["completed_at"] != nil, st, c1)
	st, served = call("POST", "/api/queues/1/call-next", itStaff, nil)
	check("after completion the priority token is served first", str(served, "token_number") == str(p1, "token_number"), served)
	_, pos = call("GET", path("/api/tokens/%d/queue-position", id(n3)), "", nil)
	check("queue position and estimate update after the queue moves", num(pos, "queue_position") == 2 && num(pos, "estimated_wait_seconds") >= 60 && num(pos, "estimated_wait_seconds") < est3, pos)

	fmt.Println("\n[Logic] no-show rules")
	st, ns := call("POST", path("/api/tokens/%d/no-show", id(p1)), itStaff, nil)
	check("first no-show -> WAITING, count 1", st == 200 && str(ns, "status") == "WAITING" && num(ns, "no_show_count") == 1, ns)
	w = waitingNumbers(admin, 1)
	check("first no-show goes to the END of the queue", len(w) == 3 && w[2] == str(p1, "token_number"), w)
	for _, want := range []obj{n2, n3} {
		_, s := call("POST", "/api/queues/1/call-next", itStaff, nil)
		check("next in line is "+str(want, "token_number"), str(s, "token_number") == str(want, "token_number"), str(s, "token_number"))
		call("POST", path("/api/tokens/%d/complete", id(s)), itStaff, nil)
	}
	_, s := call("POST", "/api/queues/1/call-next", itStaff, nil)
	check("no-show token is called again", str(s, "token_number") == str(p1, "token_number"), s)
	st, ns = call("POST", path("/api/tokens/%d/no-show", id(p1)), itStaff, nil)
	check("second no-show -> CANCELLED, count 2", st == 200 && str(ns, "status") == "CANCELLED" && num(ns, "no_show_count") == 2, ns)

	fmt.Println("\n[Visitor] cancel")
	_, c := gen(1, false)
	st, r := call("PATCH", path("/api/tokens/%d/cancel", id(c)), "", nil)
	check("visitor cancels a waiting token", st == 200 && str(r, "status") == "CANCELLED", r)
	st, _ = call("PATCH", path("/api/tokens/%d/cancel", id(c)), "", nil)
	check("cancelling twice -> 409", st == 409, st)
	_, srv := gen(1, false)
	call("POST", "/api/queues/1/call-next", itStaff, nil)
	st, _ = call("PATCH", path("/api/tokens/%d/cancel", id(srv)), "", nil)
	check("serving token cannot be cancelled", st == 409, st)
	call("POST", path("/api/tokens/%d/complete", id(srv)), itStaff, nil)

	fmt.Println("\n[Staff] transfer")
	_, tr := gen(2, false)
	st, r = call("POST", path("/api/tokens/%d/transfer", id(tr)), itStaff, obj{"department_id": 3})
	check("staff of another department cannot transfer -> 403", st == 403, st)
	st, r = call("POST", path("/api/tokens/%d/transfer", id(tr)), hrStaff, obj{"department_id": 3, "reason": "wrong desk"})
	check("transfer HR -> Accounts", st == 200 && num(r, "department_id") == 3 && str(r, "status") == "WAITING", st, r)
	check("transferred token keeps its number", str(r, "token_number") == str(tr, "token_number"))
	check("HR queue is empty, Accounts has the token", len(waitingNumbers(admin, 2)) == 0 && len(waitingNumbers(admin, 3)) == 1)
	st, _ = call("POST", path("/api/tokens/%d/transfer", id(tr)), accStaff, obj{"department_id": 3})
	check("transfer to same department -> 400", st == 400, st)
	_, s = call("POST", "/api/queues/3/call-next", accStaff, nil)
	check("Accounts staff serves the transferred token", str(s, "token_number") == str(tr, "token_number"), s)
	call("POST", path("/api/tokens/%d/complete", id(tr)), accStaff, nil)

	fmt.Println("\n[Staff] priority endpoint")
	_, a := gen(4, false)
	_, b := gen(4, false)
	st, r = call("POST", path("/api/tokens/%d/priority", id(b)), admStaff, obj{"priority": true})
	w = waitingNumbers(admin, 4)
	check("staff can mark a waiting token priority and it jumps ahead", st == 200 && len(w) == 2 && w[0] == str(b, "token_number"), st, w)
	call("POST", path("/api/tokens/%d/priority", id(b)), admStaff, obj{"priority": false})
	w = waitingNumbers(admin, 4)
	check("priority can be removed again", w[0] == str(a, "token_number"), w)
	call("PATCH", path("/api/tokens/%d/cancel", id(a)), "", nil)
	call("PATCH", path("/api/tokens/%d/cancel", id(b)), "", nil)

	fmt.Println("\n[Staff] pause / resume")
	_, keep := gen(1, false)
	st, r = call("PATCH", "/api/departments/1/pause", hrStaff, nil)
	check("other department's staff cannot pause -> 403", st == 403, st)
	st, r = call("PATCH", "/api/departments/1/pause", itStaff, nil)
	check("pause department", st == 200 && str(r, "status") == "PAUSED", r)
	st, _ = gen(1, false)
	check("cannot generate token while paused -> 409", st == 409, st)
	_, kt := call("GET", path("/api/tokens/%d", id(keep)), "", nil)
	check("existing token still exists while paused", str(kt, "status") == "WAITING")
	st, _ = call("POST", "/api/queues/1/call-next", itStaff, nil)
	check("staff can keep serving existing tokens while paused", st == 200, st)
	call("POST", path("/api/tokens/%d/complete", id(keep)), itStaff, nil)
	st, r = call("PATCH", "/api/departments/1/resume", itStaff, nil)
	check("resume department", st == 200 && str(r, "status") == "ACTIVE", r)
	st, x := gen(1, false)
	check("token generation works again after resume", st == 201, st)
	call("PATCH", path("/api/tokens/%d/cancel", id(x)), "", nil)

	fmt.Println("\n[Concurrency] two staff press Call Next at the same instant")
	for i := 0; i < 8; i++ {
		gen(4, false)
	}
	dup := 0
	for round := 0; round < 4; round++ {
		var wg sync.WaitGroup
		got := make([]string, 2)
		toks := []string{admin, admStaff}
		start := make(chan struct{})
		for i := 0; i < 2; i++ {
			wg.Add(1)
			go func(i int) {
				defer wg.Done()
				<-start
				st, r := call("POST", "/api/queues/4/call-next", toks[i], nil)
				if st == 200 {
					got[i] = str(r, "token_number")
					call("POST", path("/api/tokens/%d/complete", id(r)), toks[i], nil)
				}
			}(i)
		}
		close(start)
		wg.Wait()
		if got[0] == "" || got[1] == "" || got[0] == got[1] {
			dup++
			fmt.Println("    round", round, "got", got)
		}
	}
	check("two simultaneous Call Next never return the same token", dup == 0, dup)
	for _, n := range waitingNumbers(admin, 4) { // clean up
		_ = n
	}
	for i := 0; i < 20; i++ {
		st, r := call("POST", "/api/queues/4/call-next", admin, nil)
		if st != 200 {
			break
		}
		call("POST", path("/api/tokens/%d/complete", id(r)), admin, nil)
	}

	fmt.Println("\n[Dashboard]")
	st, d := call("GET", "/api/dashboard", itStaff, nil)
	deps, _ := d["departments"].([]any)
	check("dashboard returns totals and 4 departments", st == 200 && len(deps) == 4 && num(d, "completed") > 0 && num(d, "no_shows") >= 2, st, d)
	_, g := gen(3, false)
	_, d2 := call("GET", "/api/dashboard", itStaff, nil)
	check("dashboard waiting count updates", num(d2, "waiting") == num(d, "waiting")+1, num(d, "waiting"), num(d2, "waiting"))
	call("PATCH", path("/api/tokens/%d/cancel", id(g)), "", nil)

	fmt.Printf("\nRESULT: %d passed, %d failed\n", passed, failed)
	if failed > 0 {
		os.Exit(1)
	}
}
