# CLAUDE.md

Course registration with seat contention: a two-person college RDBMS project. Students register for
course sections that have limited seats, a waitlist, prerequisite checks and clash detection. The
centrepiece demo is two users racing for the last seat: without locking both get in, but with
`SELECT ... FOR UPDATE` exactly one does. The full design is in [docs/PLAN.md](docs/PLAN.md). Read it
before making design decisions.

Two developers each run their own Claude Code on their own clone. **GitHub is the only shared state**,
so anything the other person needs to know goes in this file, a PR description, or the code.

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
app/registration.py  # thin Python wrappers around CALL sp_...()
app/templates/  app/static/
demo/race.py  demo/manual_lock_demo.sql
docs/PLAN.md  docs/report/
```
| Area | Owner | Rule |
|---|---|---|
| `db/`, `app/registration.py`, `demo/` | **Person A** (database engine) | Only A edits these |
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
```
WSL only: if systemd isn't enabled, run `sudo service mysql start` after each WSL restart.

## Commands
```bash
python3 -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

bash db/reset.sh          # rebuild the DB from scratch (Windows: run it from Git Bash)
mysql -u coursereg_dev -p course_reg < db/tests.sql   # SQL tests
flask --app app/app.py run --debug                    # http://localhost:5000
```
Before opening a PR that touches `db/`, run `bash db/reset.sh` followed by `db/tests.sql`. Both must
pass cleanly.

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
   - Routines and views: `sp_` procedures, `fn_` functions, `trg_` triggers, `v_` views.
     Parameters use `p_` and local variables use `v_`.
5. **MySQL 8.0 syntax only.** No 8.4-only features.
6. **SQL files:** any file with routines or triggers uses `DELIMITER $$ ... $$ DELIMITER ;` and must
   load with the plain `mysql` CLI, because that's the same command on both machines. Each file is
   re-runnable after `reset.sh` (no assumptions about leftover state). Stored functions declare
   `READS SQL DATA` (or `DETERMINISTIC`), because binary logging is on by default in 8.0.
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
| `fn_has_clash` | `(p_student_id INT, p_section_id INT) RETURNS BOOLEAN` |
| `fn_prereqs_met` | `(p_student_id INT, p_course_id INT) RETURNS BOOLEAN` |
| `fn_current_credits` | `(p_student_id INT) RETURNS INT` |
| `v_section_seats` | section, course, instructor, capacity, enrolled, seats_left, waitlist_len, fill_pct |
| `v_student_timetable` | one row per meeting of each section the student is enrolled in |

`sp_register` sets `p_status` to one of `ENROLLED`, `WAITLISTED` or `REJECTED`, and `p_msg` to a
human-readable reason. The UI shows `p_msg` verbatim in a toast. Business-rule failures are reported
through `REJECTED` + `p_msg`. Unexpected errors (and `p_fail = TRUE`) roll back and propagate as a
MySQL error (`SIGNAL`/`RESIGNAL`, SQLSTATE `45000`), which the app must catch and display.

`p_safe = FALSE` deliberately skips `FOR UPDATE` so the race demo can overbook. `p_delay` (seconds)
widens the race window. Both exist for the demo. Normal UI calls pass `p_safe = TRUE`, `p_delay = 0`
and `p_fail = FALSE`.

## Git workflow
1. `git pull` on `main`, then `git checkout -b feat/<short-name>` (or `fix/...`, `docs/...`).
2. Commit small, focused changes with messages in the imperative mood.
3. `gh pr create`. **Never push directly to `main`.**
4. The *other* person reviews (`/code-review` helps) and merges.
5. B can work against stub functions in `app/registration.py` until A's procedures merge. Stubs must
   return the same shape as the real contract.
