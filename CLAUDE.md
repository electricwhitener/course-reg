# CLAUDE.md

Course registration with seat contention: a two-person college RDBMS project. Students register for
course sections that have limited seats, a waitlist, prerequisite checks and clash detection. The
centrepiece demo is two users racing for the last seat: without locking both get in, but with
`SELECT ... FOR UPDATE` exactly one does. The full design is in [docs/PLAN.md](docs/PLAN.md). Read it
before making design decisions.

Two developers each run their own Claude Code on their own clone. **GitHub is the only shared state**,
so anything the other person needs to know goes in this file, a PR description, or the code.

**Team:** Person A is **Eknoor Brar** (database; GitHub `electricwhitener`, owns the repo). Person B is
**Bhavya Ransiwal** (interface; GitHub `harshransiwal-max`).

**Opened this file outside the repo?** If there's no `db/` folder next to this file, you're in a folder
that only holds a copy of it. Follow **Getting started on Windows (Person B)** below, then keep working
inside the cloned `course-reg` folder.

## Stack
- MySQL **8.0** (InnoDB, REPEATABLE READ default), Python 3.11+, Flask, `mysql-connector-python`.
  **No ORM.**
- Bootstrap 5 and Chart.js come from a CDN. There is no JS build step.
- Person A works in WSL2 (Ubuntu 24.04). Person B works on native Windows. Everything must work on both.

## Layout and ownership
```
db/01_schema.sql 02_views.sql 03_functions.sql 04_procedures.sql
   05_triggers.sql 06_security.sql 07_seed.sql      # loaded in numeric order by reset.sh
db/reset.sh          # drop + recreate the DB, then run db/0*.sql in order
db/tests.sql         # CALLs procedures and SELECTs expected state
app/app.py           # Flask routes
app/db.py            # connection handling + SQL Inspector logging; ALL DB access goes through here
app/registration.py  # thin Python wrappers around CALL sp_...(), plus the race and deadlock runners
app/isolation.py     # Isolation Lab: two sessions stepping through scripted anomaly scenarios
app/templates/  app/static/
demo/race.py deadlock.py isolation.py   # command-line versions of the demos
demo/manual_lock_demo.sql explain_indexes.sql
docs/PLAN.md         # the full project plan (interface design: section 5)
docs/report/         # report material and measured results
```
| Area | Owner | Rule |
|---|---|---|
| `db/`, `app/registration.py`, `app/isolation.py`, `demo/`, `docs/report/` | **Person A** (database engine) | Only A edits these |
| `app/templates/`, `app/static/` | **Person B** (interface) | Only B edits these |
| `app/app.py`, `app/db.py`, `CLAUDE.md`, root config | Shared | Small PRs, merged quickly |

If a task needs a change in the other person's area, don't make it. Describe what's needed in the PR
or ask the user to raise it with their teammate.

## Setup
`.env` holds credentials. Copy `.env.example` to `.env`. Never commit `.env`.

One-time MySQL setup (in `sudo mysql` on WSL, or the MySQL root shell on Windows):
```sql
CREATE DATABASE course_reg;
CREATE USER 'coursereg_dev'@'localhost' IDENTIFIED BY 'devpass';
GRANT ALL PRIVILEGES ON course_reg.* TO 'coursereg_dev'@'localhost';
GRANT PROCESS ON *.* TO 'coursereg_dev'@'localhost';                  -- lock monitor
GRANT SELECT ON performance_schema.* TO 'coursereg_dev'@'localhost';  -- lock monitor
-- 06_security.sql creates roles and users, and grants them access:
GRANT CREATE ROLE, DROP ROLE, CREATE USER, ROLE_ADMIN ON *.* TO 'coursereg_dev'@'localhost';
GRANT ALL PRIVILEGES ON course_reg.* TO 'coursereg_dev'@'localhost' WITH GRANT OPTION;
-- Binary logging is on by default, and without this only SUPER can create functions and triggers:
SET PERSIST log_bin_trust_function_creators = 1;
```
WSL only: if systemd isn't enabled, run `sudo service mysql start` after each WSL restart.

## Commands
```bash
python3 -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

bash db/reset.sh          # rebuild the DB from scratch (Windows: run it from Git Bash)
mysql -u coursereg_dev -p course_reg < db/tests.sql   # SQL tests: last line must be 43 (passed), 0 (failed)
flask --app app/app.py run --debug                    # http://localhost:5000
```
Before opening a PR that touches `db/`, run `bash db/reset.sh` followed by `db/tests.sql`. Both must
pass cleanly.

Claude can't answer a password prompt, so when Claude runs `mysql`, it sets the dev password in the
environment instead of using `-p`: `MYSQL_PWD=devpass mysql -u coursereg_dev course_reg < db/tests.sql`.
On Windows, run `.sh` scripts in **Git Bash**, not PowerShell (in PowerShell, `bash` may start WSL
instead), and use the venv's programs directly: `.venv/Scripts/python`, `.venv/Scripts/flask`.

## Getting started on Windows (Person B)
Do these in order, starting from the folder that holds this file. Explain each step to Bhavya in
plain words. Some steps need him (installers, browser logins, the MySQL root password): give him
exact instructions and wait. Skip anything that's already done.

1. **Check the tools:** `git --version`, `gh --version`, `python --version` (3.11 or newer), and
   `mysql --version` (MySQL 8.0). Install what's missing:
   - Git (this includes Git Bash): `winget install --id Git.Git -e`
   - GitHub CLI: `winget install --id GitHub.cli -e`
   - Python: `winget install --id Python.Python.3.12 -e`
   - MySQL Community Server **8.0** plus MySQL Workbench: Bhavya installs them from dev.mysql.com
     (if the main downloads page only offers newer versions, 8.0 is under "Archives"). He keeps port
     3306, sets a root password he'll remember, and lets MySQL run as a Windows service. If 8.0 can't
     be installed, 8.4 LTS is acceptable as long as step 8's tests pass. Then add the server's `bin`
     folder (e.g. `C:\Program Files\MySQL\MySQL Server 8.0\bin`) to his user PATH and reopen the
     terminal so `mysql` works.
2. **Log in to GitHub:** `gh auth status` must show `harshransiwal-max`. If not, Bhavya runs
   `gh auth login` (GitHub.com → HTTPS → log in with a web browser).
3. **Clone:** `gh repo clone electricwhitener/course-reg`, which creates a `course-reg` folder.
   Work inside it from now on. Tell Bhavya to start future Claude sessions there; the loose copy of
   this file can then be deleted.
4. **Git identity:** `git config --global user.name "Bhavya Ransiwal"`, and set `user.email` to his
   GitHub noreply address, which `gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'` prints
   (run it in Git Bash; PowerShell mangles the quotes).
5. **MySQL user and permissions:** Bhavya opens **MySQL 8.0 Command Line Client** from the Start menu
   (or runs `mysql -u root -p`), types his root password, and pastes the SQL block from **Setup**
   above. You can't type the root password for him.
6. **Python and settings** (inside `course-reg`): `python -m venv .venv`, then
   `.venv/Scripts/python -m pip install -r requirements.txt`, then copy `.env.example` to `.env`.
   Keep `.env` with LF line endings.
7. **Merge the open pull requests**, only if #1–#5 are still open (`gh pr list`). Merge them in
   order, #1 first: `gh pr merge <n> --merge --delete-branch`. They are stacked: after each merge,
   GitHub moves the next PR onto `main` within a few seconds. Check with
   `gh pr view <n> --json baseRefName` before merging it. Use merge commits, never squash, or the
   later PRs will conflict. Then `git checkout main && git pull`. If a merge fails, stop and tell
   Bhavya to ask Eknoor.
8. **Check everything works** (in Git Bash):
   `bash db/reset.sh`, then `MYSQL_PWD=devpass mysql -u coursereg_dev course_reg < db/tests.sql | tail -1`
   must print `43` and `0` (43 passed, 0 failed), and `.venv/Scripts/python demo/race.py --safe --runs 3` must end with
   `3/3 runs`. If anything fails, this is Person A's area: show Bhavya the exact error to send to
   Eknoor, and don't change `db/` yourself.
9. **Run the app:** `.venv/Scripts/flask --app app/app.py run --debug`. Bhavya opens
   http://localhost:5000 and should see the course catalog.
10. **Laptop specs for the report (Table 1.2):** run this in PowerShell and give Bhavya the output to
    send to Eknoor:
    `$p=Get-CimInstance Win32_Processor; $c=Get-CimInstance Win32_ComputerSystem; $o=Get-CimInstance Win32_OperatingSystem; "$($c.Manufacturer) $($c.Model)"; "$($p.Name.Trim()) ($($p.NumberOfCores) cores, $($p.NumberOfLogicalProcessors) threads)"; "$([math]::Round($c.TotalPhysicalMemory/1GB)) GB RAM"; $o.Caption; Get-PhysicalDisk | ForEach-Object { "$($_.MediaType) $([math]::Round($_.Size/1GB)) GB" }`

Then continue with **Interface work: status and what's left**.

## Core rules
1. **Business logic lives in MySQL** (stored procedures, functions, triggers), not in Python. Flask
   stays thin: it calls `CALL sp_...()` or reads from a `v_...` view and renders the result. Don't
   re-implement checks such as seats, clashes, prerequisites or credits in Python.
2. **Parameterized queries only.** Use `cursor.execute(sql, params)` or `cursor.callproc(name, args)`.
   Never build SQL with f-strings, `%` formatting or concatenation from user input.
3. **All database access goes through `app/db.py`**, so the SQL Inspector panel can log every
   statement, its parameters and its timing.
4. **Naming** (agreed, so don't change it without both people agreeing):
   - Lowercase `snake_case` for every table and column, because Windows MySQL ignores name case and
     Linux MySQL doesn't.
   - Tables are **plural** (`students`, `enrollments`).
   - Primary keys are `<singular>_id` (`student_id`, `section_id`), and every foreign key uses the
     **same name** as the key it points to. The exception is a second FK to the same table, which
     gets a role name (`prereq_course_id`).
   - Timestamps end in `_at` and say what happened (`enrolled_at`, `requested_at`, `logged_at`).
   - Days of the week are `ENUM('MON','TUE','WED','THU','FRI','SAT')`.
   - Every constraint and index is named explicitly: `fk_<table>_<target>`, `uq_<table>_<cols>`,
     `chk_<table>_<rule>`, `idx_<table>_<cols>`.
   - Routines and views: `sp_` procedures, `fn_` functions, `trg_` triggers, `v_` views,
     `ev_` scheduled events.
     Parameters use `p_`, local variables use `l_` (not `v_`, which means a view), and cursors use
     `cur_`.
   - Database roles are `app_<role>`; their login users are `coursereg_<role>`.
5. **MySQL 8.0 syntax only.** No 8.4-only features.
6. **SQL files:** any file with routines or triggers uses `DELIMITER $$ ... $$ DELIMITER ;` and must
   load with the plain `mysql` CLI, because that's the same command on both machines. Each file is
   re-runnable after `reset.sh` (no assumptions about leftover state). Stored functions declare
   `READS SQL DATA` (or `DETERMINISTIC`), because binary logging is on by default in 8.0.
   In a locking procedure, the `SELECT ... FOR UPDATE` on `sections` must be the transaction's first
   read: REPEATABLE READ fixes the snapshot at the first plain read, and a snapshot taken before the
   lock would miss the other transaction's insert.
7. **3NF:** seats taken is always `COUNT(*)` from `enrollments`, never a stored counter. Concurrency
   control locks the **`sections` row**.
8. **Line endings are LF** (enforced by `.gitattributes`).

## Procedure contract
This is the interface between `db/` and the app. Changing a signature or a status value is a
breaking change: update this section in the same PR and call it out in the description.

| Object | Signature / output |
|---|---|
| `sp_register` | `(p_student_id INT, p_section_id INT, p_safe BOOLEAN, p_delay DECIMAL(4,1), p_fail BOOLEAN, OUT p_status VARCHAR(20), OUT p_msg VARCHAR(255))` |
| `sp_drop` | `(p_student_id INT, p_section_id INT)`: deletes the enrollment and promotes the earliest waitlisted student |
| `sp_set_capacity` | `(p_section_id INT, p_new_capacity INT)`: a cursor promotes waitlisted students while seats remain |
| `sp_register_cart` | `(p_student_id INT, p_section_ids JSON, p_fail_section INT, OUT p_results JSON)`: one transaction, a SAVEPOINT per section; `p_results` is `[{section_id, status, msg}]` |
| `sp_expire_waitlist` | `(p_days INT)`: removes waitlist entries older than `p_days` (run nightly by `ev_expire_waitlist` with 30) |
| `sp_demo_deadlock` | `(p_first_section INT, p_second_section INT, p_delay DECIMAL(4,1))`: demo only; locks two sections in the given order |
| `fn_registration_error` | `(p_student_id INT, p_section_id INT) RETURNS VARCHAR(255)`: the first rule that fails, or NULL. Shared by `sp_register` and the cart |
| `fn_has_clash` | `(p_student_id INT, p_section_id INT) RETURNS BOOLEAN` |
| `fn_prereqs_met` | `(p_student_id INT, p_course_id INT) RETURNS BOOLEAN` |
| `fn_current_credits` | `(p_student_id INT) RETURNS INT` |
| `v_section_seats` | section, course, instructor, capacity, enrolled, seats_left, waitlist_len, fill_pct |
| `v_student_timetable` | one row per meeting of each section the student is enrolled in |
| `v_waitlist_positions` | student_id, section_id, course_code, course_title, section_code, requested_at, position (1 = next) |
| `v_audit_feed` | audit_log with student_name and section_label |
| `v_course_demand` | per course: capacity, enrolled, waitlisted, demand, demand_pct, `dept_rank` (RANK within department) |
| `v_oversubscribed_courses` | courses whose demand exceeds their total capacity |
| `v_daily_activity` | per day from `audit_log`: enrolls, drops, waitlists, rejects, running `total_enrolled` |
| `v_lock_monitor` | live row locks: thread_id, table_name, lock_type, lock_mode, lock_status, lock_data, blocked_by_thread_id |

`app/registration.py` wraps all of these for Python: `register`, `register_cart`, `drop`,
`set_capacity`, `run_race`, `lock_snapshot`, `clear_section` (demo reset), `run_deadlock`. Routes
should call these instead of `db.call` directly.

`sp_register` sets `p_status` to one of `ENROLLED`, `WAITLISTED` or `REJECTED`, and `p_msg` to a
human-readable reason. The UI shows `p_msg` verbatim in a toast. Business-rule failures are reported
through `REJECTED` + `p_msg`. Unexpected errors (and `p_fail = TRUE`) roll back and propagate as a
MySQL error (`SIGNAL`/`RESIGNAL`, SQLSTATE `45000`), which the app must catch and display.

`sp_register` also returns one result set with a single row, `t_begin, t_locked, t_counted,
t_written, t_end` (`DATETIME(6)`, NULL for steps that didn't happen), which the Race Arena timeline
uses. Python reads it with `cursor.stored_results()`. App connections use `autocommit=True` (set in
`app/db.py`).

`p_safe = FALSE` deliberately skips `FOR UPDATE` so the race demo can overbook. `p_delay` (seconds)
widens the race window. Both exist for the demo. Normal UI calls pass `p_safe = TRUE`, `p_delay = 0`
and `p_fail = FALSE`.

## JSON API (`app/app.py`)
Pages fetch from these routes. A MySQL error comes back as `{"error": msg}` with status 400, and
the `api()` helper in `static/app.js` turns that into a thrown `Error`. Timestamps are ISO strings
with microseconds, and `TIME` values are `"HH:MM"`.

| Route | Does |
|---|---|
| `GET /api/students`, `GET /api/sections` | student list (navbar switcher), `v_section_seats` |
| `GET /api/students/<id>/timetable`, `.../waitlist` | `v_student_timetable`, `v_waitlist_positions` |
| `POST /api/register` `{student_id, section_id, fail?}` | `registration.register` → `{status, msg, timeline}` |
| `POST /api/cart` `{student_id, section_ids, fail_section?}` | `registration.register_cart` |
| `POST /api/drop` `{student_id, section_id}` | `registration.drop` |
| `POST /api/admin/capacity` `{section_id, capacity}`, `GET /api/admin/audit?limit=` | capacity change (cursor), `v_audit_feed` newest first |
| `GET /api/analytics/<name>` | `section_seats`, `course_demand`, `oversubscribed`, `daily_activity` |
| `POST /api/race` `{section_id, student_ids, safe, delay}`, `POST /api/race/clear`, `GET /api/locks` | Race Arena; poll `/api/locks` while `/api/race` runs |
| `POST /api/deadlock` `{first_section?, second_section?}` | deadlock demo + InnoDB report |
| `GET /api/isolation/scenarios`, `POST /api/isolation/start` `{level}`, `.../step` `{level, scenario, index}`, `.../stop` | Isolation Lab |

## Interface work: status and what's left (Person B)
The database, the Python wrappers and the whole JSON API above are finished and tested. Person B
builds only the pages: `app/templates/`, `app/static/`, and thin page routes in the shared
`app/app.py` (one `render_template` route per page, plus a navbar link in `base.html`). The detailed
design is in `docs/PLAN.md` section 5.

**Already built:**
- `base.html` + `static/app.js` + `static/style.css` (Bhavya's redesign): navbar with Catalog,
  Schedule, Admin and Race Arena links, the "Login as" student menu (localStorage), a dark-mode
  toggle, a live MySQL status badge, and toasts. Helpers: `api(path, {method, body})`, `esc(value)`
  (always escape database text before it goes into `innerHTML`), `currentStudent()`,
  `studentById(id)`, the `studentsReady` promise, a `student-changed` event, and `toast(msg, kind)`.
  Colours are CSS tokens (`--cr-*`) redefined for dark mode, so new styles should use them.
- `catalog.html`: section cards with segmented green/amber/red seat bars, search, department
  filters, sorting, a "your registration" panel, Register / Join waitlist / Drop, refresh every 2 s.
- `schedule.html` (`/schedule`): weekly grid MON–SAT × 09:00–17:00, credits, enrolled and waitlist
  lists with Drop/Leave. Refreshes every 3 s and follows the "Login as" menu.
- `admin.html` (`/admin`): section table with a capacity form per row (the toast says how many
  students the cursor promoted) and a live audit-log feed.
- `race.html` (`/race`): section, two students, Unsafe/Safe and delay. Runs `/api/race` while
  polling `/api/locks`, then draws both timelines on a shared clock, keeps the lock snapshot that
  shows a WAITING lock, and shows an OVERBOOKED or "1 enrolled · 1 waitlisted" banner. The first
  race on a freshly started server right after `reset.sh` can run about a second slow; run one
  warm-up race before a demo.

Jinja reads `{{` as its own tag, so never write `${{ ... }}` inside a template's JavaScript; put the
object in a constant first.

**Still to build, one PR per item:**
1. **SQL Inspector:** a collapsible drawer on every page listing each SQL statement or CALL the last
   request ran, with its parameters and time in ms. This needs a small logging hook in the shared
   `app/db.py` (`query()` and `call()`), for example returned to the page in a response header.
   `run_race` and `run_deadlock` call the database from worker threads with no Flask request
   context, so the hook must check `flask.has_request_context()` before using `flask.g`.
2. **Analytics** `/analytics`: Chart.js from a CDN with an exact version (e.g. `chart.js@4.4.1`).
   Charts: fill % by section (`/api/analytics/section_seats`), demand vs capacity
   (`course_demand`), department ranking (`course_demand`, `dept_rank`), and enrollments over time
   (`daily_activity`).
3. **Stretch:** Isolation Lab `/isolation` (`/api/isolation/*`), and a deadlock demo button
   (`POST /api/deadlock`).

**The project report depends on the UI.** Eknoor's report shows screenshots that he takes himself:
- Fig. 5.3 is the Schedule grid, Fig. 5.4 the Admin page (capacity change + audit log), and Fig. 5.5
  the Race Arena with both timelines.
- The report text describes the "Login as" menu and the catalog's green/amber/red seat bars that
  refresh every 2 seconds. Keep them, or say clearly in the PR description if you change them.
- If you use Chart.js, mention it in the PR, because the report's software table lists it.
- Don't edit `docs/report/`; it's the report source, and Eknoor maintains it.

## Git workflow
1. `git pull` on `main`, then `git checkout -b feat/<short-name>` (or `fix/...`, `docs/...`).
2. Commit small, focused changes with messages in the imperative mood.
3. `gh pr create`. **Never push directly to `main`.**
4. The *other* person reviews (`/code-review` helps) and merges. Eknoor reviews Bhavya's PRs, and
   Bhavya reviews Eknoor's.
5. **No AI attribution.** Commits and PRs show only the developer who made them. Never add
   `Co-Authored-By: Claude` trailers, "Generated with Claude Code" lines, or session links.
   `.claude/settings.json` turns these off. Each developer sets `git config user.name` and
   `user.email` to their own GitHub account (the `ID+username@users.noreply.github.com` address from
   GitHub → Settings → Emails works).
