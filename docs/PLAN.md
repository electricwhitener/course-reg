# Plan: Course Registration with Seat Contention (MySQL + Flask)

## Context
A two-person college RDBMS project. You need a MySQL database connected to an interface, a project report, and a demo with viva questions. The idea: students register for course sections that have limited seats, a waitlist, and clash detection. **The demo:** two users try to take the last seat at the same moment. Without locking, both get in (the seat is overbooked). With a transaction, `SELECT ... FOR UPDATE` and `ROLLBACK`, exactly one gets the seat and the other is waitlisted.

The feedback is that the plan shouldn't be too basic. It should be **eye-catching** and use as much of the semester's MySQL material as possible. So:
- **The rules live in MySQL itself:** stored procedures, functions, triggers, cursors, handlers, views, indexes and roles.
- **The UI makes the database visible:** you can see the SQL as it runs, watch locks being held, and see the race play out on a timeline.

Constraints:
- Both of you build with your own Claude Code subscription.
- You work only inside WSL (Ubuntu, WSL2) so Windows stays clean.
- Your teammate uses a native Windows install.
- You both know git and GitHub.

Stack:
- **MySQL 8 + Python 3 + Flask + mysql-connector-python.** No ORM.
- **Bootstrap 5 + Chart.js** loaded from a CDN, so there is no build step.
- Flask stays thin: it mostly runs `CALL sp_...()`, so the database does the real work.

Scope tiers: **Core** (must have) → **Showpiece** (what makes it eye-catching) → **Stretch** (if time allows).

---

## 1. Environment setup

### You (WSL only, nothing installed on Windows)
1. In VS Code: `Ctrl+Shift+P` → **WSL: Connect to WSL**. Every terminal you open is now Ubuntu.
2. Keep the code **inside the Linux filesystem** (`~/projects/course-reg`), not on the Windows Desktop or `/mnt/c`. Delete the empty `Desktop\RDBMS Proj` folder.
3. Install the tools in Ubuntu:
   ```bash
   sudo apt update && sudo apt install -y mysql-server python3-venv python3-pip git gh
   sudo service mysql start           # run once after each WSL restart (or enable systemd)
   ```
4. Install Claude Code **inside WSL** (`curl -fsSL https://claude.ai/install.sh | bash`), run `claude` and log in, and install the VS Code Claude Code extension on the WSL side. Then run `gh auth login`.
5. Create the database user (in `sudo mysql`). The app's limited roles are created later by `db/security.sql`.
   ```sql
   CREATE DATABASE course_reg;
   CREATE USER 'coursereg_dev'@'localhost' IDENTIFIED BY 'devpass';
   GRANT ALL PRIVILEGES ON course_reg.* TO 'coursereg_dev'@'localhost';
   GRANT PROCESS ON *.* TO 'coursereg_dev'@'localhost';
   GRANT SELECT ON performance_schema.* TO 'coursereg_dev'@'localhost';
   ```
   The last two grants let the live lock monitor work.
6. Flask runs in WSL, and the Windows browser reaches it at `http://localhost:5000` automatically.
7. To remove everything later: `sudo apt purge mysql-server` and friends, or `wsl --unregister Ubuntu` to delete the whole distro.

### Teammate (native Windows)
Install MySQL Community Server 8.x and MySQL Workbench (Workbench draws the ER diagram), Python 3.11+, Git, `gh`, and Claude Code. Create the same database and user.

### Cross-platform rules
- **Table and column names in lowercase snake_case only.** Windows MySQL ignores name case and Linux MySQL doesn't.
- `.gitattributes` with `* text=auto eol=lf` keeps line endings consistent.
- Credentials go in `.env` (gitignored), with `.env.example` committed.
- `.sql` files with procedures use `DELIMITER $$`, and you load them with the `mysql` CLI (the same command on both machines).
- Use MySQL 8.0 features only: no 8.4-only syntax.

---

## 2. Collaborating with two Claude Code subscriptions
**GitHub is the only point of contact between you.** Each person runs their own Claude Code on their own clone.

1. Create a private repo `course-reg`, add the other person as a collaborator, and both clone it.
2. Commit a **`CLAUDE.md`** in the repo root. Both Claude sessions read it automatically. Contents:
   - The stack, the folder layout, and the run and reset commands.
   - Naming rules.
   - Where business logic goes: "in stored procedures, not Python".
   - The **procedure contract** (section 4).
   - Parameterized queries only.
   - Git rules: feature branch → PR → the other person reviews and merges.
3. **Workflow:**
   1. `git pull`, then `git checkout -b feat/xyz`.
   2. Work with Claude and commit.
   3. Open a PR with `gh pr create`.
   4. The other person reviews it (`/code-review` in their Claude Code helps) and merges.
4. **Each owns a folder.** Only Person A edits `db/`, and only Person B edits `app/templates` and `app/static`. Shared files (`app/app.py`, `CLAUDE.md`) get small PRs, merged quickly.
5. On Day 1, B works against **stub Python functions** that return fake data, then swaps in the real procedure calls once A's PR merges.

### Work split

| | **Person A (you, WSL): database engine** | **Person B (teammate): interface and visualization** |
|---|---|---|
| Owns | `db/*.sql`, `app/registration.py` (procedure wrappers), `demo/` | `app/app.py` routes, `templates/`, `static/`, charts |
| Builds | Schema, seed data, procedures, functions, triggers, cursor, roles, indexes, race/deadlock logic, lock-monitor queries | Dashboard, catalog, schedule, admin, analytics charts, SQL Inspector panel, race arena page, isolation lab UI |
| Report | ER diagram, normalization, SQL objects, transactions/locking chapter, EXPLAIN | Intro, requirements, UI screenshots, user flows, testing, conclusion |

---

## 3. Database design (3NF)

| Table | Columns (key ones) |
|---|---|
| `departments` | `dept_id` PK, `name` UNIQUE |
| `students` | `student_id` PK, `name`, `email` UNIQUE, `dept_id` FK, `max_credits` DEFAULT 20 |
| `instructors` | `instructor_id` PK, `name`, `dept_id` FK |
| `courses` | `course_id` PK, `code` UNIQUE, `title`, `credits` CHECK 1–6, `dept_id` FK |
| `prerequisites` | PK(`course_id`, `prereq_course_id`), both FKs to `courses` (self-referencing many-to-many) |
| `completed_courses` | PK(`student_id`, `course_id`), `grade` (used to check prerequisites) |
| `sections` | `section_id` PK, `course_id` FK, `instructor_id` FK, `section_code`, `room`, `capacity` CHECK > 0 |
| `section_meetings` | `meeting_id` PK, `section_id` FK, `day` ENUM, `start_time`, `end_time`, CHECK start < end, INDEX(`day`, `start_time`) |
| `enrollments` | PK(`student_id`, `section_id`), `enrolled_at` |
| `waitlist` | `waitlist_id` PK, `student_id`, `section_id`, `requested_at`, UNIQUE(`student_id`, `section_id`) |
| `audit_log` | `log_id`, `action` ENUM(ENROLL, DROP, WAITLIST, PROMOTE, REJECT), `student_id`, `section_id`, `details`, `at` |

**Seed data:**
- About 3 departments, 15 students, 6 instructors, 10 courses with a prerequisite chain, and about 14 sections.
- A capacity-1 section for the race demo.
- Two sections whose times overlap, for the clash demo.
- A student missing a prerequisite, for the prerequisite rejection.

Seats taken = `COUNT(*)` from `enrollments`. There is no stored counter, which keeps the design in 3NF. The **`sections` row** is what gets locked.

---

## 4. SQL objects: the procedure contract (Person A)
| Object | Purpose | Concept shown |
|---|---|---|
| `sp_register(student, section, safe, delay, fail, OUT status, OUT msg)` | The whole registration as one transaction (steps below) | Procedures, TCL, locking, handlers, SIGNAL |
| `sp_drop(student, section)` | Delete the enrollment, lock the section, promote the earliest waitlisted student, commit | Transactions, `ORDER BY ... LIMIT 1 FOR UPDATE` |
| `sp_set_capacity(section, new_cap)` | Admin raises capacity, then a **cursor** walks the waitlist and promotes students while seats remain | **Cursor** + loop + CONTINUE HANDLER |
| `fn_has_clash(student, section)` → BOOLEAN | Do any of the new section's meetings overlap the student's? Overlap means same `day` AND `new.start < old.end AND old.start < new.end` | **Stored function**, EXISTS subquery |
| `fn_prereqs_met(student, course)` → BOOLEAN | Has the student completed every prerequisite? | NOT EXISTS (relational division) |
| `fn_current_credits(student)` → INT | Sum of credits currently enrolled | Aggregate in a function |
| `trg_enroll_after_insert` / `trg_enroll_after_delete` | Write rows to `audit_log` | **Triggers** |
| `trg_waitlist_before_insert` | Block waitlisting for a course the student is already enrolled in | BEFORE trigger + SIGNAL |
| `v_section_seats` | Section, course, instructor, capacity, enrolled, seats left, waitlist length, fill % | **View**, LEFT JOIN + GROUP BY |
| `v_student_timetable` | The student's weekly grid rows | Multi-table JOIN view |
| `security.sql` | `CREATE ROLE app_student` (EXECUTE on the procedures only), `app_admin`, plus a read-only `app_report`. The Flask app connects as a user with these roles | **DCL**: GRANT/REVOKE, least privilege |
| Indexes | On `section_meetings(day, start_time)` and the FK columns. Run `EXPLAIN` before and after, for the report | Indexing, query plans |

**`sp_register` steps:**
1. `DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END`
2. `START TRANSACTION`
3. If `safe`, run `SELECT capacity ... FOR UPDATE`, which takes an exclusive row lock. Otherwise run a plain SELECT, the deliberately unsafe path.
4. Run the checks in order. A failure means `ROLLBACK` and a REJECT row in the audit log:
   - already enrolled or waitlisted
   - another section of the same course
   - `fn_prereqs_met`
   - credit limit (`fn_current_credits`)
   - `fn_has_clash`
5. Count enrollments → `DO SLEEP(delay)`, the demo knob that widens the race window.
6. Seats left → INSERT into enrollments. Otherwise → INSERT into waitlist.
7. If `fail`, run `SIGNAL SQLSTATE '45000'` *after* the insert. The handler rolls back, which shows that atomicity undoes the insert.
8. `COMMIT`

**Why unsafe mode overbooks:** under InnoDB's REPEATABLE READ default, a plain SELECT reads a snapshot. Both transactions see "1 seat left", both sleep, and both insert. `FOR UPDATE` is a *locking read*, so transaction B waits until A commits and then sees the section full.

---

## 5. Interface (Person B): where it becomes eye-catching
**Look:** a Bootstrap 5 dashboard with a dark navbar, cards, and colored seat bars (green, then amber, then red as a section fills). A "Login as" student switcher sits in the navbar (no real auth).

### Core
- `/catalog`: section cards from `v_section_seats` with live seat bars and Register buttons. Rejections appear as toasts carrying the exact SIGNAL message from MySQL.
- `/schedule`: a **weekly timetable grid** (days × hours) built from `v_student_timetable`. Clashes would be impossible here, which shows clash detection works. It also lists waitlist positions and has Drop buttons.
- `/admin`: change capacity, which triggers the cursor-based promotion, plus all enrollments and the **audit log feed**.

### Showpiece
- **SQL Inspector panel**, a collapsible side drawer on every page. It shows each SQL statement or `CALL` the request ran, its parameters, and its time in ms. The teacher sees the real SQL behind every click.
- **Race Arena** `/race`:
  1. Pick a section and two students, and switch **Unsafe ↔ Safe**.
  2. Click "Race!". Flask starts two threads, each on its own connection, calling `sp_register(..., delay=2)`.
  3. Two side-by-side panes animate a **timeline** (BEGIN, then READ, then WAITING FOR LOCK, then INSERT, then COMMIT) from timestamps the procedure records.
  4. While the race runs, a **live lock monitor** polls `performance_schema.data_locks` and `information_schema.innodb_trx`. It shows Transaction A holding an X lock on `sections` row 7 while Transaction B waits for it.
  5. Result banner: a red **OVERBOOKED 2/1** in unsafe mode, or green **1 enrolled · 1 waitlisted** in safe mode.
- **Live seat counts:** catalog seat bars refresh every 2 s with `fetch` polling, so two browser windows side by side update each other.
- **Analytics** `/analytics`, Chart.js charts using GROUP BY/HAVING, CTEs, and **window functions**:
  - fill % by section (bar)
  - demand vs capacity, counting enrolled + waitlisted (stacked bar)
  - `RANK() OVER (PARTITION BY dept ORDER BY demand DESC)` for the most popular courses
  - enrollments over time from `audit_log` (line)

### Stretch
- **Isolation Lab** `/isolation`: two session panels (A and B) with step buttons. Pick READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ or SERIALIZABLE, then step through a scripted scenario to *see* a dirty read, a non-repeatable read, or a phantom appear or disappear. Flask holds two persistent connections in a dict, which works in single-process dev mode.
- **Deadlock demo:** two transactions lock two sections in opposite order. MySQL detects the deadlock and kills one (error 1213), the UI shows the victim, and the app retries. Show `SHOW ENGINE INNODB STATUS` output in the report.
- Scheduled **EVENT** that expires waitlist entries older than N days.
- SAVEPOINT use: multi-section "cart" registration that rolls back to a savepoint if one section fails.

`demo/race.py` is the same race as a command-line script, a backup if the browser misbehaves. `demo/manual_lock_demo.sql` holds the two-terminal script for the viva.

---

## 6. Repo layout
```
course-reg/
  CLAUDE.md  README.md  requirements.txt  .env.example  .gitignore  .gitattributes
  db/01_schema.sql 02_views.sql 03_functions.sql 04_procedures.sql 05_triggers.sql
     06_security.sql 07_seed.sql reset.sh            # reset = drop DB + run 01..07 in order
  app/app.py  app/db.py (connection + SQL Inspector logging)  app/registration.py
  app/templates/*.html  app/static/{style.css, app.js}
  demo/race.py  demo/manual_lock_demo.sql
  docs/PLAN.md  docs/er-diagram.png  docs/report/
```

---

## 7. Milestones (about 7 working days)
1. **Day 0, both:** environments, repo, `CLAUDE.md`, the contract, and a Flask page that reads from MySQL on both machines.
2. **Day 1:** A writes the schema, seed data and views. B writes the Bootstrap layout, navbar switcher, and catalog/schedule pages against stubs.
3. **Day 2:** A writes the functions, `sp_register` and `sp_drop`. B wires the real calls and builds the timetable grid and toasts.
4. **Day 3:** A writes the triggers, the cursor-based `sp_set_capacity`, roles and indexes. B builds the admin page, audit feed and SQL Inspector.
5. **Day 4:** the Race Arena. A writes the thread runner and lock-monitor queries, B writes the timeline animation. Add live seat polling.
6. **Day 5:** analytics charts. Then stretch work: the Isolation Lab and the deadlock demo.
7. **Day 6:** report, ER diagram, screenshots, viva practice (have Claude quiz you), and a rehearsal on **both** machines.

Core is done by Day 3, Showpiece by Day 5. Stretch only happens if things are on track.

---

## 8. Report and viva
**Report outline:**
1. Introduction and problem statement
2. Requirements
3. ER diagram
4. Relational schema
5. Normalization (1NF → 3NF, with an example)
6. SQL objects (DDL, constraints, views, functions, procedures, cursor, triggers, roles)
7. Transactions and concurrency (the race, its timeline, locks, isolation levels, deadlock)
8. Indexing and EXPLAIN
9. Interface walkthrough
10. Testing
11. Conclusion and future work

**Viva topics to rehearse:**
- Keys and constraints
- Normalization, and why seat count isn't stored
- ACID
- Isolation levels and their anomalies
- Lost update
- Shared vs exclusive locks, and `FOR UPDATE` vs `FOR SHARE`
- Deadlock detection
- COMMIT, ROLLBACK and SAVEPOINT
- Procedures vs functions vs triggers
- Cursors and handlers
- Views
- Indexes and B+ trees
- Window functions and CTEs
- GRANT, REVOKE and roles
- SQL injection and parameterized queries
- JOIN types
- The interval-overlap condition

**Demo script, about 10 minutes:**
1. Reset the DB.
2. Tour the catalog and timetable.
3. Show the clash and prerequisite rejections.
4. Unsafe race → OVERBOOKED.
5. Safe race → lock monitor shows B waiting → correct result.
6. "Simulate failure" → rollback.
7. Admin raises capacity → the cursor promotes waitlisted students → the audit log updates.
8. Analytics.
9. Isolation Lab, if built.
10. Show the two-terminal `FOR UPDATE` demo in the `mysql` CLI.

---

## 9. Verification
- `db/reset.sh` (on Windows, the same `mysql` commands) builds everything cleanly on **both** WSL MySQL and Windows MySQL.
- SQL test script `db/tests.sql`: each case CALLs the procedures and SELECTs the expected state.
  - free seat → enrolled
  - full section → waitlisted
  - overlap → clash rejected and no rows inserted
  - missing prerequisite → rejected
  - over the credit limit → rejected
  - drop → first waitlisted student promoted
  - higher capacity → N students promoted by the cursor
  - `fail=1` → counts unchanged
  - triggers wrote audit rows
- Race: unsafe mode overbooks reliably with a 2 s delay. Safe mode gives exactly 1 enrolled and 1 waitlisted across 10 runs of `demo/race.py`.
- Roles: logged in as the `app_student` user, a direct `INSERT INTO enrollments` is **denied**, and `CALL sp_register` works.
- Run the full demo script on both laptops after a fresh reset.

## 10. Next step after approval
This Claude session runs on the Windows side. To start development:
1. Open VS Code connected to WSL.
2. Run `mkdir -p ~/projects/course-reg`, then `git init` and `gh repo create`.
3. Start `claude` there.
4. Copy this plan in as `docs/PLAN.md`, and generate `CLAUDE.md` and the Day 0 skeleton from it.

Your teammate then clones the repo and follows the Windows setup.
