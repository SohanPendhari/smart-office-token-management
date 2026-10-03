<div align="center">
🏢 Smart Office Queue & Token Management
Pick a department → get a token like `IT-021` → watch your position update live → get called.
![Flutter Web](https://img.shields.io/badge/Frontend-Flutter%20Web-02569B?logo=flutter&logoColor=white)
![Go](https://img.shields.io/badge/Backend-Go%201.22-00ADD8?logo=go&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-4169E1?logo=postgresql&logoColor=white)
![JWT](https://img.shields.io/badge/Auth-JWT%20%2B%20bcrypt-000000?logo=jsonwebtokens&logoColor=white)
![Riverpod](https://img.shields.io/badge/State-Riverpod-0553B1)
![Watch the demo](https://img.shields.io/badge/▶%20Watch%20the%20demo%20video-FF0000?style=for-the-badge&logo=googledrive&logoColor=white)
</div>
---
🎬 Demo video
<div align="center">
![Smart Office Queue demo - click to watch](https://drive.google.com/thumbnail?id=1Ikq_sIZUcE8Rdu5-ahu-2Jz85Crbkwfk&sz=w1000)
▶ Click to watch the full walkthrough on Google Drive
</div>
---
📖 Table of contents
Overview · Features · Tech stack · Architecture · Quick start · Default logins · Queue rules · API · Project structure · Testing · Limitations
🧭 Overview
Visitors choose an office department (IT Support, HR, Accounts, Administration), receive a backend-generated token, and see their queue position and estimated waiting time update live. Staff and admins run the queue from a desktop-friendly console.
> **The golden rule:** Flutter is only the presentation layer. **Go owns every business rule** (token numbers, priority, no-show, transfer, pause, concurrency) and **PostgreSQL is the source of truth**. The browser never decides which token is next.
Role	What they can do
🙋 Visitor (no account)	Choose a department, generate a token, see position + estimated wait + live queue, cancel a waiting token
🧑‍💼 Staff (one department)	Sign in, view the dashboard, call next, complete, no-show, transfer, set priority, pause / resume their department
🛡️ Admin	Everything staff can do, in every department
✨ Features
🎟️ Backend-generated, unique token numbers per department, restarting every day (`IT-001`, `IT-002`, …)
⭐ Priority queue that never interrupts the token being served
🚫 No-show rules: first → end of the queue, second → cancelled
🔀 Transfers between departments with full history
⏸️ Pause / resume a department (existing tokens continue, new ones are blocked)
⏱️ Live position and estimated wait (REST polling every 5 s)
🔒 Concurrency-safe "Call next" using `SELECT … FOR UPDATE SKIP LOCKED`
🔐 JWT authentication, bcrypt password hashes, role + department authorization
📊 Dashboard: waiting, serving, completed, no-shows, average waiting / service time, per-department counts
🧾 Audit trail (`token_events`) and statistics tables
🖥️ Responsive UI: landing page + top navigation for visitors, sidebar console for staff, works from phone to wide monitor
⚙️ API URL switchable inside the app (this PC, another device on the Wi-Fi, or Android emulator)
🧰 Tech stack
Layer	Technology
Frontend	Flutter Web, Riverpod 2, `http`, `shared_preferences`
Backend	Go 1.22+, standard-library `net/http`, `database/sql` + `lib/pq`, `golang-jwt/jwt/v5`, `bcrypt`
Database	PostgreSQL 14+
🏗️ Architecture
```mermaid
flowchart LR
    A["🖥️ Flutter Web app<br/>screens · Riverpod"] -- "REST / JSON" --> B["🟦 Go backend<br/>handlers → services → repositories"]
    B -- "SQL / transactions" --> C[("🐘 PostgreSQL")]
```
Backend layers: `handlers` (HTTP only) → `services` (all rules, own the transactions) → `repositories` (all SQL). `middleware` provides JWT auth, logging, CORS and panic recovery.
🚀 Quick start
Prerequisites
Go 1.22+ (needed for `"PATCH /api/departments/{id}/pause"` style routes)
PostgreSQL 14+ with `psql` on your PATH
Flutter SDK 3.19+ and Google Chrome (`flutter doctor` should list Chrome)
1. Database
```bat
cd database
setup.bat            :: Windows  (optional args: setup.bat <pg_user> <db_name>)
```
```bash
cd database && ./setup.sh     # macOS / Linux / Git Bash
```
<details><summary>Manual equivalent</summary>
```bash
psql -U postgres -c "CREATE DATABASE smart_office"
psql -U postgres -d smart_office -f database/schema.sql
psql -U postgres -d smart_office -f database/seed.sql
```
Optional (office time instead of UTC for the daily token reset): `ALTER DATABASE smart_office SET timezone TO 'Asia/Kolkata';`
</details>
2. Backend
```bash
cd backend
cp .env.example .env        # Windows: copy .env.example .env
# edit .env -> put your Postgres password in DATABASE_URL and set JWT_SECRET
go mod tidy                 # first time only (downloads deps, creates go.sum)
go run ./cmd/server         # http://localhost:8080
```
Check it: http://localhost:8080/api/health → `{"status":"ok"}`
`.env` values:
```
PORT=8080
DATABASE_URL=postgres://postgres:YOUR_PASSWORD@localhost:5432/smart_office?sslmode=disable
JWT_SECRET=use-a-long-random-string
JWT_TTL_HOURS=12
```
3. Frontend (Flutter Web)
```powershell
cd frontend
powershell -ExecutionPolicy Bypass -File .\setup_web.ps1     # once (macOS/Linux: ./setup_web.sh)
flutter run -d chrome --web-port 3000                        # http://localhost:3000
```
4. Point the app at the backend
Where you open the app	API URL
Chrome on the same PC as the backend	`http://localhost:8080` (default)
Browser on another PC / phone (same Wi-Fi)	`http://<backend-PC-IP>:8080` (allow port 8080 in the firewall)
Android emulator (optional)	`http://10.0.2.2:8080`
Change it in the app: top bar ⚙️ → Server settings → Test connection → Save. Or at build time: `flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.10:8080`.
To open the app from another device: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000`.
Production build: `flutter build web` → `frontend/build/web`.
🔑 Default logins
Role	Email	Password
Admin (all departments)	`admin@smartoffice.com`	`Admin@123`
IT staff	`it.staff@smartoffice.com`	`Staff@123`
HR staff	`hr.staff@smartoffice.com`	`Staff@123`
Accounts staff	`accounts.staff@smartoffice.com`	`Staff@123`
Administration staff	`admin.staff@smartoffice.com`	`Staff@123`
> ⚠️ Demo credentials. Change them and `JWT_SECRET` before any real deployment. Create a hash for a new user with `go run ./cmd/hashpw "MyPassword"`.
🧠 Queue rules
Call-next order
```sql
SELECT id FROM tokens
WHERE department_id = $1 AND status = 'WAITING'
ORDER BY priority DESC, priority_level DESC, sequence_number ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;
```
Priority + oldest → priority + next → normal + oldest → normal + next.
```mermaid
stateDiagram-v2
    [*] --> WAITING: generate token
    WAITING --> SERVING: staff "Call next"
    WAITING --> CANCELLED: visitor cancels
    SERVING --> COMPLETED: complete
    SERVING --> WAITING: 1st no-show (end of queue)
    SERVING --> CANCELLED: 2nd no-show
    WAITING --> WAITING: transfer (other department, end of queue)
```
Rule	Behaviour
Priority	Re-orders only the waiting list. It never interrupts a token being served.
No-show #1	`WAITING`, `no_show_count = 1`, new sequence number → end of the queue (priority flag dropped)
No-show #2	`CANCELLED`. Threshold = `queue_settings.max_no_shows` (default 2)
Transfer	Closes the service session, logs a `token_transfers` row, moves the token to the target department as `WAITING` at the end of that queue. The token keeps its number.
Pause	Blocks new tokens (409). Existing tokens, calling and completing keep working.
Concurrency	Call next runs in a transaction; two staff pressing it at the same instant lock different rows and never get the same token.
Unique numbers	A row-locking counter per department/day + `UNIQUE (token_number, created_date)`
Busy staff	A staff member cannot call the next token while still serving one (409)
One token per mobile	A mobile number cannot hold two active tokens in the same department
Estimated wait	`people ahead × average service time ÷ active counters` (rounded up). Average = last 20 completed services, falling back to 5 min until 5 samples exist, never below 1 min.
📡 API reference
Base URL `http://localhost:8080` · JSON everywhere · errors are `{"error": "message"}` (400 / 401 / 403 / 404 / 409). Staff endpoints need `Authorization: Bearer <JWT>`.
Public
Method	Path	Notes
GET	`/api/health`	liveness
POST	`/api/auth/login`	`{"email","password"}` → `{"token","user":{"id","name","role"}}`
GET	`/api/departments`	status, `waiting`, `serving`, `currently_serving[]`, `estimated_wait_seconds`
GET	`/api/departments/:id`	one department
POST	`/api/visitors`	`{"name","mobile"}` (optional; token creation can take name + mobile directly)
POST	`/api/tokens`	`{"department_id":1,"name":"Sohan","mobile":"9876543210","priority":false}` → 201. 409 if paused or duplicate
GET	`/api/tokens/:id`	token + live `queue_position`, `people_ahead`, `estimated_wait_seconds`
PATCH	`/api/tokens/:id/cancel`	only while `WAITING`
GET	`/api/tokens/:id/queue-position`	position, people ahead, estimate, `currently_serving[]`, anonymous `queue[]`
Staff / Admin (JWT)
Method	Path	Notes
GET	`/api/auth/me`	current user
GET	`/api/dashboard`	totals, averages, per-department counts
GET	`/api/queues/:departmentId`	`serving[]`, `waiting[]` (in call order), today's counts
POST	`/api/queues/:departmentId/call-next`	404 if empty, 409 if you are still serving
POST	`/api/tokens/:id/complete`	must be `SERVING`
POST	`/api/tokens/:id/no-show`	must be `SERVING`
POST	`/api/tokens/:id/transfer`	`{"department_id":3,"reason":"optional"}`
POST	`/api/tokens/:id/priority`	`{"priority":true,"level":1}` · `WAITING` only
PATCH	`/api/departments/:id/pause` · `/resume`	
Authorization: ADMIN may act on any department; STAFF only on their own (403 otherwise). Viewing queues and the dashboard is open to all staff.
```bash
TOKEN=$(curl -s localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"it.staff@smartoffice.com","password":"Staff@123"}' | sed 's/.*"token":"\([^"]*\)".*/\1/')
curl -s -X POST localhost:8080/api/queues/1/call-next -H "Authorization: Bearer $TOKEN"
```
🗂️ Project structure
```
smart-office-queue/
├── README.md
├── database/                  schema.sql · seed.sql · setup.bat · setup.sh · README.md
├── backend/
│   ├── cmd/server/            main.go (wiring, graceful shutdown)
│   ├── cmd/hashpw/            bcrypt helper
│   ├── cmd/smoketest/         end-to-end rule test against a running server
│   ├── config/                env / .env loading
│   ├── database/              postgres.go + migrations/001..010
│   ├── models/  repositories/  services/  handlers/  middleware/  routes/  utils/
│   └── go.mod
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/ models/ services/ providers/ utils/ widgets/
│   │   └── screens/           splash · settings · visitor/* · staff/*
│   ├── test/
│   ├── setup_web.ps1 / .sh    (generates web/)
│   └── pubspec.yaml
└── docs/screenshots/
```
Database tables: `users`, `departments`, `visitors`, `tokens`, `token_events`, `token_transfers`, `queue_settings`, `counters`, `token_service_sessions`, `daily_queue_stats` (see `database/README.md`).
✅ Testing
Backend rule test (run against a demo database: it empties the queues first):
```bash
cd backend
go run ./cmd/smoketest          # BASE_URL=http://host:port to point elsewhere
```
50 checks covering every item of the checklist: all four departments, unique numbers, position / estimate updates, cancel rules, priority never interrupts, priority before normal, no-show #1 / #2, transfer + permissions, pause / resume, dashboard updates, and two staff pressing Call next at the same instant.
Frontend: `cd frontend && flutter test`
Manual end-to-end: run backend + frontend, generate tokens as a visitor, sign in as staff in an incognito window, then call next / complete / no-show and watch the visitor screen update within ~5 s.
🖼️ Screenshots
Add your screenshots to `docs/screenshots/` and link them here, for example:
```markdown
![Home](docs/screenshots/home.png)
![Staff queue](docs/screenshots/staff-queue.png)
```
📝 Design notes & limitations
Visitors have no accounts, as specified. Anyone who knows a numeric token id can view or cancel it. For production, return a per-token secret on creation and require it on cancel.
Live updates use REST polling (5 s). SSE / WebSocket would be a natural next step.
A visitor's tokens are remembered in the browser (local storage) for the My Tokens page.
Staff sessions are JWTs valid for `JWT_TTL_HOURS`; there is no refresh token or server-side revocation.
Visitor priority requests are on by default (`queue_settings.allow_visitor_priority`); set it to `false` per department to restrict priority to staff.
---
<div align="center">Built with Go, PostgreSQL and Flutter.</div>
