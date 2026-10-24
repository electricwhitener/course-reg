# Claude Design pack: RDBMS Lab project report

How to use this file:
1. In Claude Design, start a new document and paste **Part A (layout brief)** as your first message.
   Attach the 9 PNG pages of the official template so it can copy the cover page and certificate exactly.
2. Paste **Part B (report content)** chapter by chapter. Everything in `[square brackets]` is an
   instruction or a placeholder, not report text.
3. Make Fig 2.1 with the prompt in **Part C**. Capture the screenshots using `snapshots.md`.
4. Go through **Part D (before you submit)**.

---

## Part A: layout brief (paste into Claude Design first)

> Lay out a university lab project report, A4 portrait, following these rules exactly:
> - Margins 0.7 inch on all four sides.
> - Body text: Times New Roman 12 pt, justified, 1.15 line spacing.
> - Chapter headings: Times New Roman 14 pt bold, numbered "1.", "2.", … Each chapter starts on a new page.
> - Sub-headings: numbered 1.1, 1.2, …, Times New Roman 12 pt italic.
> - Table captions **above** the table, figure captions **below** the figure, centred, numbered by
>   chapter (Table 2.1, Fig. 2.1). Tables use thin grey borders and a bold header row.
> - SQL code in Courier New 10 pt inside a light grey box, not numbered.
> - Page numbers at the bottom right. Front matter has no numbers; numbering starts at 1 on the first
>   page of Chapter 1 and continues to the end.
> - Order: cover page, certificate, abstract, list of tables, list of figures, table of contents,
>   chapters 1 to 6, references, annexure.
> - The cover page and certificate must match the attached template pages exactly (same logos,
>   wording, spacing). Only the title, names and registration numbers change.
> - The list of tables, list of figures and table of contents need correct page numbers.
> - Total length 18 to 20 pages. If it runs over, shrink screenshots before cutting text.

---

## Part B: report content

### Cover page
- Title: **Course Registration and Waitlist Management System using MySQL**
- Student Name 1: **Eknoor Brar** ([registration number])
- Student Name 2: **[teammate's name]** ([registration number])
- Everything else exactly as in the template (RDBMS Lab (CSC2131), B.Tech CSE, submitted to Dr. Abhishek
  Dwivedi & Dr. Santosh Rajak, MUJ, August-November 2026).

### Certificate
As in the template, with `<PROJECT TITLE>` = Course Registration and Waitlist Management System using
MySQL, and the two names and registration numbers filled in.

### Abstract

Every semester, course registration opens at a fixed time and hundreds of students try to get into the
same few sections at once. Seats are limited, so the system has to check prerequisites, credit limits
and timetable clashes, and it must never give the last seat to two people. A registration system that
reads the seat count and then inserts the student as two separate steps can overbook a section when
two requests arrive together. This is the lost update problem that database courses describe in
theory. The aim of this project was to build a course registration database in MySQL 8.0 that stays
correct under that kind of concurrent load. Every registration rule runs inside the database itself,
as stored procedures, functions and triggers, instead of in application code.

Most small registration systems, including typical student projects, treat the database as passive
storage and check seat availability in the application, so the check and the insert are not atomic.
Our system runs each registration as one transaction that locks the section row with
`SELECT ... FOR UPDATE`. It adds a first-come-first-served waitlist with automatic promotion, an audit
trail written by triggers, and least-privilege roles. In a scripted race between two users for the
last seat, the unlocked version overbooked the section (2 students in 1 seat), while the locked
version gave exactly one seat and one waitlist place in all 10 runs. The project also measures the
four isolation levels, deadlock detection and the effect of indexes on query plans.

### List of tables
[Claude Design: build from the captions below]
1.1 Software requirements · 1.2 Hardware requirements · 2.1 Mapping of ER constructs to relations ·
2.2 Data dictionary · 3.1 Functional dependencies and candidate keys · 3.2 Normalization stages ·
4.1 Seed data · 4.2 Advanced SQL features used · 4.3 Effect of indexes on query plans ·
4.4 Stored programs · 4.5 Schedule without locking (lost update) · 4.6 Schedule with FOR UPDATE ·
4.7 Isolation levels and observed anomalies · 4.8 Role privileges · 5.1 Test case summary

### List of figures
[Claude Design: build from the captions below]
2.1 ER diagram · 2.2 Relational schema diagram · 5.1 Course catalog page · 5.2 Registration
messages · 5.3 Student timetable · 5.4 Admin page and audit log · 5.5 Race Arena · 5.6 SQL test
results · 5.7 Race without and with locking · 5.8 Live lock monitor · 5.9 Deadlock detection ·
5.10 Isolation level experiment · 5.11 EXPLAIN before and after indexing · 5.12 Role-based access
control · 5.13 Course demand ranking

---

## 1. Introduction & System Requirements

### 1.1 Project Overview / Problem Statement

A college runs its course registration in short windows, and demand is uneven. Popular sections fill
in minutes while others stay half empty. Each request has to pass several rules before a seat is
given: the student must have completed the course's prerequisites, must stay within their credit
limit, must not already hold a section of the same course, and must not have a class at the same
time. When a section is full, the student should be placed on a waitlist and promoted automatically
when someone drops.

The hard part is concurrency. If two students request the last seat at the same moment, both
requests can read "1 seat left" before either one writes, and both get enrolled. Database textbooks
call this a lost update [1]. The problem statement for this project is: *design a normalized
relational database for course registration that enforces every rule itself and stays correct when
requests run concurrently.* We used MySQL 8.0 with the InnoDB storage engine [2], and a small web
interface on top that only calls the database's procedures.

### 1.2 Objectives

1. Design a relational schema for departments, students, instructors, courses, prerequisites,
   sections, timetables, enrollments and waitlists, normalized to BCNF.
2. Enforce all registration rules (prerequisites, credit limit, duplicate course, timetable clash,
   capacity) inside MySQL using stored procedures, functions and triggers.
3. Prevent overbooking under concurrent requests using transactions and row-level locking, and
   demonstrate the failure that occurs without locking.
4. Keep a waitlist that promotes students in request order when seats become free.
5. Record every registration event in an audit log automatically.
6. Restrict access with database roles, so the application can only call procedures and read views.
7. Study isolation levels, deadlocks and indexing with measured results.
8. Provide a web interface that shows the database at work.

### 1.3 Software & Hardware Requirements

**Table 1.1: Software requirements**

| Component | Version / detail | Purpose |
|---|---|---|
| MySQL Community Server | 8.0.46 (InnoDB, REPEATABLE READ) | Database server |
| Python | 3.12 | Runs the web application and demo scripts |
| Flask | 3.1.0 [3] | Web framework (routes and JSON API) |
| mysql-connector-python | 9.1.0 [4] | Python driver for MySQL |
| Bootstrap | 5.3.3 [5] | Page layout and styling |
| Chart.js | 4.x | Analytics charts [remove if the analytics page is not built] |
| MySQL Workbench | 8.0 | Schema diagram |
| Git and GitHub | – | Version control and collaboration |
| Operating systems | Ubuntu 24.04 on WSL2; Windows 11 | Development machines of the two members |

**Table 1.2: Hardware requirements**

| Item | Member 1 (Eknoor Brar) | Member 2 ([name]) | Minimum needed |
|---|---|---|---|
| Processor | [from Settings → System → About] | [ ] | Any 64-bit dual-core |
| RAM | [ ] | [ ] | 4 GB |
| Storage | [ ] | [ ] | 2 GB free |
| Operating system | Windows 11 + Ubuntu 24.04 (WSL2) | Windows [ ] | Windows 10/11 or Linux |

---

## 2. Database Design & Modeling

### 2.1 Entity-Relationship (ER) Diagram

The design has eight entities. A **Department** offers courses and employs instructors, and every
student belongs to one department. A **Course** (for example CS302, Database Systems) is the subject;
a **Section** is one actual class of that course with its own instructor, room and seat capacity, so
one course can have several sections. Each section meets at one or more weekly **Meeting** times.
Students register for sections, not courses, because seats and times belong to sections.

Three relationships between students and the rest are many-to-many: a student *enrolls in* many
sections and a section has many students; a student *waits for* sections that are full; and a student
has *completed* many courses, with a grade. Courses are also related to themselves: a course
*requires* other courses as prerequisites. The **Audit Log** records events about students and
sections but is deliberately not tied to them by foreign keys, so its history survives deletions.

[Insert Fig. 2.1 here: ER diagram made with the Part C prompt]

**Fig. 2.1: ER diagram of the course registration system**

### 2.2 Relational Schema / Mapping

The ER diagram was mapped to relations using the standard rules of the relational model [6]. Strong
entities became tables with a surrogate primary key. Each one-to-many relationship became a foreign
key on the "many" side. Each many-to-many relationship became its own table whose key combines the
two participating keys. The weekly meeting times, a multi-valued attribute of a section, became a
separate table.

**Table 2.1: Mapping of ER constructs to relations**

| ER construct | Type | Relation(s) |
|---|---|---|
| Department, Student, Instructor, Course, Section | Strong entities | `departments`, `students`, `instructors`, `courses`, `sections` |
| Department–Student, Department–Instructor, Department–Course | 1 : N | foreign key `dept_id` in `students`, `instructors`, `courses` |
| Course–Section, Instructor–Section | 1 : N | foreign keys `course_id`, `instructor_id` in `sections` |
| Section meets at times | Multi-valued attribute | `section_meetings(section_id, day, start_time, end_time)` |
| Student enrolls in Section | M : N with attribute | `enrollments(student_id, section_id, enrolled_at)` |
| Student waits for Section | M : N with attribute | `waitlist(student_id, section_id, requested_at)` |
| Student completed Course | M : N with attribute | `completed_courses(student_id, course_id, grade)` |
| Course requires Course | Recursive M : N | `prerequisites(course_id, prereq_course_id)` |
| Audit Log | Independent entity | `audit_log` (no foreign keys) |

The resulting schema (primary keys underlined, foreign keys marked *):

- DEPARTMENTS(<u>dept_id</u>, name)
- STUDENTS(<u>student_id</u>, name, email, dept_id*, max_credits)
- INSTRUCTORS(<u>instructor_id</u>, name, dept_id*)
- COURSES(<u>course_id</u>, code, title, credits, dept_id*)
- PREREQUISITES(<u>course_id*, prereq_course_id*</u>)
- COMPLETED_COURSES(<u>student_id*, course_id*</u>, grade)
- SECTIONS(<u>section_id</u>, course_id*, instructor_id*, section_code, room, capacity)
- SECTION_MEETINGS(<u>meeting_id</u>, section_id*, day, start_time, end_time)
- ENROLLMENTS(<u>student_id*, section_id*</u>, enrolled_at)
- WAITLIST(<u>waitlist_id</u>, student_id*, section_id*, requested_at)
- AUDIT_LOG(<u>log_id</u>, action, student_id, section_id, details, logged_at)

[Insert Fig. 2.2 here: Workbench reverse-engineered diagram, see snapshots.md]

**Fig. 2.2: Relational schema diagram generated by MySQL Workbench**

### 2.3 Data Dictionary

Table 2.2 lists every column. All constraints are named in the DDL (for example
`chk_courses_credits`), so an error message from MySQL names the exact rule that failed.

**Table 2.2: Data dictionary**

| Table | Column | Data type | Constraints | Description |
|---|---|---|---|---|
| departments | dept_id | INT | PK; AUTO_INCREMENT | Department identifier |
|  | name | VARCHAR(100) | UNIQUE; NOT NULL | Department name |
| students | student_id | INT | PK; AUTO_INCREMENT | Student identifier |
|  | name | VARCHAR(100) | NOT NULL | Full name |
|  | email | VARCHAR(255) | UNIQUE; NOT NULL | College e-mail address |
|  | dept_id | INT | FK → departments.dept_id; NOT NULL | Home department |
|  | max_credits | TINYINT | NOT NULL; DEFAULT 20; CHECK (max_credits > 0) | Most credits the student may take per semester |
| instructors | instructor_id | INT | PK; AUTO_INCREMENT | Instructor identifier |
|  | name | VARCHAR(100) | NOT NULL | Full name |
|  | dept_id | INT | FK → departments.dept_id; NOT NULL | Department the instructor belongs to |
| courses | course_id | INT | PK; AUTO_INCREMENT | Course identifier |
|  | code | VARCHAR(10) | UNIQUE; NOT NULL | Course code, e.g. CS101 |
|  | title | VARCHAR(150) | NOT NULL | Course title |
|  | credits | TINYINT | NOT NULL; CHECK (credits between 1 and 6) | Credit value (1 to 6) |
|  | dept_id | INT | FK → departments.dept_id; NOT NULL | Department offering the course |
| prerequisites | course_id | INT | part of PK, FK → courses.course_id; CHECK (course_id <> prereq_course_id) | Course that has the prerequisite |
|  | prereq_course_id | INT | part of PK, FK → courses.course_id; CHECK (course_id <> prereq_course_id) | Course that must be completed first |
| completed_courses | student_id | INT | part of PK, FK → students.student_id | Student |
|  | course_id | INT | part of PK, FK → courses.course_id | Course passed |
|  | grade | VARCHAR(2) | NOT NULL | Letter grade, e.g. A, B+ |
| sections | section_id | INT | PK; AUTO_INCREMENT | Section identifier |
|  | course_id | INT | part of UNIQUE, FK → courses.course_id; NOT NULL | Course taught |
|  | instructor_id | INT | FK → instructors.instructor_id; NOT NULL | Instructor teaching it |
|  | section_code | VARCHAR(5) | part of UNIQUE; NOT NULL | Section letter within the course (A, B, ...) |
|  | room | VARCHAR(20) | NOT NULL | Classroom |
|  | capacity | INT | NOT NULL; CHECK (capacity > 0) | Number of seats |
| section_meetings | meeting_id | INT | PK; AUTO_INCREMENT | Meeting identifier |
|  | section_id | INT | FK → sections.section_id; NOT NULL | Section that meets |
|  | day | ENUM('MON','TUE','WED','THU','FRI','SAT') | NOT NULL | Day of the week |
|  | start_time | TIME | NOT NULL; CHECK (start_time < end_time) | Start time |
|  | end_time | TIME | NOT NULL; CHECK (start_time < end_time) | End time |
| enrollments | student_id | INT | part of PK, FK → students.student_id | Enrolled student |
|  | section_id | INT | part of PK, FK → sections.section_id | Section |
|  | enrolled_at | DATETIME(6) | NOT NULL; DEFAULT CURRENT_TIMESTAMP(6) | When the seat was taken |
| waitlist | waitlist_id | INT | PK; AUTO_INCREMENT | Waitlist entry identifier |
|  | student_id | INT | part of UNIQUE, FK → students.student_id; NOT NULL | Waiting student |
|  | section_id | INT | part of UNIQUE, FK → sections.section_id; NOT NULL | Section waited for |
|  | requested_at | DATETIME(6) | NOT NULL; DEFAULT CURRENT_TIMESTAMP(6) | When the student joined the waitlist (decides the order) |
| audit_log | log_id | INT | PK; AUTO_INCREMENT | Log entry identifier |
|  | action | ENUM('ENROLL','DROP','WAITLIST','PROMOTE','REJECT','EXPIRE') | NOT NULL | ENROLL, DROP, WAITLIST, PROMOTE, REJECT or EXPIRE |
|  | student_id | INT |  | Student involved |
|  | section_id | INT |  | Section involved |
|  | details | VARCHAR(255) |  | Reason or message |
|  | logged_at | DATETIME(6) | NOT NULL; DEFAULT CURRENT_TIMESTAMP(6) | When it happened |

---

## 3. Database Normalization

### 3.1 Functional Dependencies

Table 3.1 lists the candidate keys and the non-trivial functional dependencies of each relation.

**Table 3.1: Functional dependencies and candidate keys**

| Relation | Candidate keys | Functional dependencies |
|---|---|---|
| departments | {dept_id}, {name} | dept_id → name; name → dept_id |
| students | {student_id}, {email} | student_id → name, email, dept_id, max_credits; email → student_id |
| instructors | {instructor_id} | instructor_id → name, dept_id |
| courses | {course_id}, {code} | course_id → code, title, credits, dept_id; code → course_id |
| prerequisites | {course_id, prereq_course_id} | none (all-key relation) |
| completed_courses | {student_id, course_id} | student_id, course_id → grade |
| sections | {section_id}, {course_id, section_code} | section_id → course_id, instructor_id, section_code, room, capacity; course_id, section_code → section_id |
| section_meetings | {meeting_id} | meeting_id → section_id, day, start_time, end_time |
| enrollments | {student_id, section_id} | student_id, section_id → enrolled_at |
| waitlist | {waitlist_id}, {student_id, section_id} | waitlist_id → student_id, section_id, requested_at; student_id, section_id → waitlist_id |
| audit_log | {log_id} | log_id → action, student_id, section_id, details, logged_at |

In every relation, the left side of every non-trivial dependency is a candidate key, so all eleven
relations are in Boyce-Codd normal form, and therefore also in 3NF.

### 3.2 Normalization Steps

We started from a single flat "registration sheet", the kind of table a spreadsheet would hold, with
one row per student per section:

REG(student_id, student_name, email, student_dept, course_code, course_title, credits, course_dept,
section_code, room, instructor_name, instructor_dept, {day, start_time, end_time}, {prereq_codes},
enrolled_at)

The braces mark repeating groups: a section meets several times a week and a course can have several
prerequisites. Table 3.2 shows how the sheet was decomposed [7].

**Table 3.2: Normalization stages**

| Stage | Problem removed | Result |
|---|---|---|
| UNF → 1NF | Repeating groups (several meetings per section, several prerequisites per course) | Meetings and prerequisites moved to their own relations; every cell holds one value. Key of the rest: {student_id, course_code, section_code} |
| 1NF → 2NF | Partial dependencies: student_id → student details; course_code → course details; (course_code, section_code) → room, instructor | STUDENT, COURSE and SECTION split out. ENROLLMENT(student_id, section, enrolled_at) keeps only what depends on the whole key |
| 2NF → 3NF | Transitive dependencies: instructor_name → instructor_dept; department names repeated as text | INSTRUCTOR and DEPARTMENT split out; other relations refer to them by id |
| 3NF → BCNF check | Every determinant must be a candidate key | Already satisfied (Table 3.1). Surrogate keys added for sections and meetings, with the natural key kept as a UNIQUE constraint |

The decomposition removes the three classic anomalies. Renaming a course now changes one row in
`courses` instead of every enrolled student's row (update anomaly). A new section can be stored before
anyone joins it (insert anomaly). When the last student drops a section, its room and instructor are
not lost (delete anomaly).

One design decision follows directly from normalization: **the number of seats taken is never
stored.** It can be derived as `COUNT(*)` from `enrollments`, so storing it would duplicate data that
could drift out of step. The same applies to a student's current credits and waitlist position, which
are computed when needed.

---

## 4. Implementation (SQL Scripting & PL/SQL)

The database is built by seven SQL scripts that run in order: schema, views, functions, procedures,
triggers and events, security, and seed data. A shell script `reset.sh` drops and rebuilds the whole
database in a few seconds, which made it easy for both members to start from the same state.

### 4.1 Data Definition Language (DDL)

All tables use InnoDB. Every primary key, foreign key, unique and check constraint is given an
explicit name. The `sections` table shows the main kinds of constraint:

```sql
CREATE TABLE sections (
  section_id    INT AUTO_INCREMENT PRIMARY KEY,
  course_id     INT NOT NULL,
  instructor_id INT NOT NULL,
  section_code  VARCHAR(5) NOT NULL,
  room          VARCHAR(20) NOT NULL,
  capacity      INT NOT NULL,
  CONSTRAINT uq_sections_course_code UNIQUE (course_id, section_code),
  CONSTRAINT chk_sections_capacity CHECK (capacity > 0),
  CONSTRAINT fk_sections_course FOREIGN KEY (course_id) REFERENCES courses (course_id),
  CONSTRAINT fk_sections_instructor FOREIGN KEY (instructor_id) REFERENCES instructors (instructor_id)
);
```

The composite primary key of `enrollments` stops a student from holding two seats in one section,
with no extra code:

```sql
CREATE TABLE enrollments (
  student_id  INT NOT NULL,
  section_id  INT NOT NULL,
  enrolled_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (student_id, section_id),
  CONSTRAINT fk_enrollments_student FOREIGN KEY (student_id) REFERENCES students (student_id),
  CONSTRAINT fk_enrollments_section FOREIGN KEY (section_id) REFERENCES sections (section_id)
);
```

`DATETIME(6)` stores microseconds, because two requests can arrive within the same millisecond and the
waitlist still needs a strict order. The DDL also defines eight views. The most used one,
`v_section_seats`, computes seats from the enrollments instead of storing them. The counts are
grouped in derived tables first, because joining `enrollments` and `waitlist` directly onto
`sections` would multiply the rows and inflate both counts:

```sql
CREATE VIEW v_section_seats AS
SELECT s.section_id, c.code AS course_code, s.section_code, s.capacity,
       COALESCE(e.enrolled, 0)              AS enrolled,
       s.capacity - COALESCE(e.enrolled, 0) AS seats_left,
       COALESCE(w.waitlist_len, 0)          AS waitlist_len
FROM sections s
JOIN courses c ON c.course_id = s.course_id
LEFT JOIN (SELECT section_id, COUNT(*) AS enrolled
           FROM enrollments GROUP BY section_id) e ON e.section_id = s.section_id
LEFT JOIN (SELECT section_id, COUNT(*) AS waitlist_len
           FROM waitlist GROUP BY section_id) w ON w.section_id = s.section_id;
```
[Excerpt shortened: the full view also returns course title, credits, instructor, room and fill percentage.]

Besides the keys, two indexes were added for specific queries: `(day, start_time)` on
`section_meetings` for clash detection, and `(logged_at)` on `audit_log` for the newest-first audit
feed. Their effect is measured in Section 4.4.

### 4.2 Data Manipulation Language (DML)

The seed script loads a small but complete data set (Table 4.1). It was planned so that every demo
case exists right after a reset: a one-seat section (CS302-A) for the race, two sections whose times
overlap, a student with no completed courses, a student close to the credit limit, and two full
sections with waiting students.

**Table 4.1: Seed data**

| Table | Rows | Table | Rows |
|---|---|---|---|
| departments | 3 | sections | 14 |
| students | 15 | section_meetings | 24 |
| instructors | 6 | enrollments | 24 |
| courses | 10 | waitlist | 5 |
| prerequisites | 9 | completed_courses | 25 |

Seed timestamps are written relative to the day of the reset, so the data never ages past the
waitlist expiry rule:

```sql
SET @seed_day = CURRENT_DATE - INTERVAL 12 DAY;
INSERT INTO waitlist (student_id, section_id, requested_at) VALUES
  (8,  12, TIMESTAMP(@seed_day + INTERVAL 2 DAY, '14:05:00')),
  (9,  12, TIMESTAMP(@seed_day + INTERVAL 2 DAY, '15:15:00'));
```

After seeding, the application never writes to a table directly. Every INSERT, UPDATE and DELETE
happens inside a stored procedure. For example, dropping a section deletes the enrollment and then
moves the first eligible waitlisted student into the free seat, all in one transaction:

```sql
DELETE FROM enrollments WHERE student_id = p_student_id AND section_id = p_section_id;
...
INSERT INTO enrollments (student_id, section_id) VALUES (l_next, p_section_id);
DELETE FROM waitlist WHERE student_id = l_next AND section_id = p_section_id;
```

### 4.3 Awards and Recognitions

[This heading looks like it was copied from another template. Ask the course instructor whether to
remove it or what to write. If it must stay: "Not applicable to this project."]

### 4.4 Advanced SQL Queries

Table 4.2 lists the advanced SQL features the project uses and where.

**Table 4.2: Advanced SQL features used**

| Feature | Used in | Purpose |
|---|---|---|
| Window function `RANK() OVER (PARTITION BY …)` | `v_course_demand` | Rank courses by demand within each department |
| Window function `ROW_NUMBER()` | `v_waitlist_positions` | Each student's place in the queue |
| Running total `SUM() OVER (ORDER BY …)` | `v_daily_activity` | Cumulative enrollments per day |
| Common table expression (`WITH`) | `v_course_demand`, `v_daily_activity` | Aggregate first, then rank or accumulate |
| Recursive CTE | index test script | Generate 100,000 test rows |
| `GROUP BY … HAVING` | `v_oversubscribed_courses` | Courses with more demand than seats |
| Correlated `NOT EXISTS` (relational division) | `fn_prereqs_met` | "No prerequisite the student has not completed" |
| Interval overlap join | `fn_has_clash` | Detect timetable clashes |
| `JSON_TABLE` | `sp_register_cart` | Turn a JSON list of sections into rows |
| Derived tables + `LEFT JOIN` + `COALESCE` | `v_section_seats` | Seat counts without row multiplication |

**Ranking with a CTE and a window function [8].** The CTE adds up all sections of each course, and
`RANK()` restarts its numbering for each department:

```sql
CREATE VIEW v_course_demand AS
WITH course_totals AS (
  SELECT course_id, SUM(capacity) AS capacity,
         SUM(enrolled) AS enrolled, SUM(waitlist_len) AS waitlisted
  FROM v_section_seats GROUP BY course_id
)
SELECT d.name AS dept_name, c.code AS course_code,
       t.enrolled + t.waitlisted AS demand,
       RANK() OVER (PARTITION BY c.dept_id
                    ORDER BY t.enrolled + t.waitlisted DESC) AS dept_rank
FROM course_totals t
JOIN courses c     ON c.course_id = t.course_id
JOIN departments d ON d.dept_id = c.dept_id;
```

On the seed data, MA102 (Calculus II) ranks first in Mathematics with 8 students enrolled or waiting
(Fig. 5.13). In Computer Science, CS301 and CS302 both have zero demand and share rank 3: `RANK()`
gives tied rows the same number, where `ROW_NUMBER()` would have split them arbitrarily.

**Relational division.** A student meets a course's prerequisites when there is no prerequisite they
have not completed. That is a double negation, written with two `NOT EXISTS`:

```sql
RETURN NOT EXISTS (
  SELECT 1 FROM prerequisites p
  WHERE p.course_id = p_course_id
    AND NOT EXISTS (SELECT 1 FROM completed_courses cc
                    WHERE cc.student_id = p_student_id
                      AND cc.course_id = p.prereq_course_id));
```

**Clash detection.** Two classes clash when they are on the same day and each starts before the other
ends: `new.start < old.end AND old.start < new.end`. Because the comparison is strict, a class ending
at 10:00 does not clash with one starting at 10:00.

**Indexes and EXPLAIN.** We compared query plans with and without the two extra indexes (Table 4.3).
For the audit feed, the table was first filled with 100,000 rows using a recursive CTE so that the
difference was measurable.

**Table 4.3: Effect of indexes on query plans**

| Query | Without index | With index |
|---|---|---|
| Clash detection join on `section_meetings` | type `ALL`: full scan of all 24 meetings | type `ref` on `idx_section_meetings_day_start`: about 4 rows (same day only) |
| 20 newest audit rows (100,000-row table) | `ALL` + `Using filesort`: 100,029 rows read, 22.6 ms | `Backward index scan` on `idx_audit_log_logged_at`: 20 rows read, 0.04 ms |

The audit index keeps rows in `logged_at` order in a B+ tree, so MySQL reads the last 20 entries and
stops, with no sorting at all.

### 4.5 PL/SQL Components

PL/SQL is Oracle's procedural language. MySQL's equivalent is *stored programs*: stored procedures,
stored functions, triggers and events, written in SQL/PSM [9]. Table 4.4 lists the ones in this
project.

**Table 4.4: Stored programs**

| Object | Type | What it does | Concepts shown |
|---|---|---|---|
| `sp_register` | Procedure | One complete registration as a single transaction | Transactions, locking, handlers, SIGNAL |
| `sp_drop` | Procedure | Drop a seat and promote the first eligible waitlisted student | Transactions, `ORDER BY … LIMIT 1 FOR UPDATE` |
| `sp_set_capacity` | Procedure | Change capacity; a cursor promotes students into new seats | Cursor, loop, CONTINUE handler |
| `sp_register_cart` | Procedure | Register for several sections; failures undo only their own part | SAVEPOINT, `JSON_TABLE` |
| `sp_expire_waitlist` | Procedure | Remove waitlist entries older than N days | INSERT … SELECT, transaction |
| `sp_demo_deadlock` | Procedure | Lock two sections in a given order (deadlock demo) | Deadlock detection |
| `fn_registration_error` | Function | Returns the first rule a registration breaks, or NULL | Shared business rules |
| `fn_has_clash` | Function | Timetable clash check | EXISTS, interval overlap |
| `fn_prereqs_met` | Function | Prerequisite check | NOT EXISTS (division) |
| `fn_current_credits` | Function | Credits currently enrolled | Aggregate |
| `trg_enrollments_after_insert` / `_after_delete` | Triggers | Write ENROLL, PROMOTE or DROP to the audit log | AFTER triggers |
| `trg_waitlist_before_insert` | Trigger | Block waitlisting for a course already taken | BEFORE trigger, SIGNAL |
| `trg_waitlist_after_insert` | Trigger | Write WAITLIST to the audit log | AFTER trigger |
| `ev_expire_waitlist` | Event | Runs `sp_expire_waitlist(30)` every night | Event scheduler [13] |

**The registration transaction.** `sp_register` takes the student, the section and three demo
switches (safe mode, a delay, and a simulated failure), and returns a status of ENROLLED, WAITLISTED
or REJECTED with a message. Its steps are:

1. Start a transaction and lock the section row with `SELECT … FOR UPDATE` (safe mode).
2. Check the rules through `fn_registration_error`. If one fails, roll back, log a REJECT row and
   return the reason, for example "Missing prerequisite: CS101."
3. Count the enrolled students. If a seat is free, insert into `enrollments`; otherwise insert into
   `waitlist`.
4. Commit. Any SQL error on the way triggers the exit handler, which rolls everything back, logs the
   error and re-raises it.

```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
  GET DIAGNOSTICS CONDITION 1 l_error = MESSAGE_TEXT;
  ROLLBACK;
  INSERT INTO audit_log (action, student_id, section_id, details)
  VALUES ('REJECT', p_student_id, p_section_id, CONCAT('Rolled back: ', l_error));
  RESIGNAL;
END;

START TRANSACTION;
IF p_safe THEN
  SELECT capacity INTO l_capacity FROM sections
  WHERE section_id = p_section_id FOR UPDATE;      -- exclusive row lock
ELSE
  SELECT capacity INTO l_capacity FROM sections
  WHERE section_id = p_section_id;                 -- no lock (demo only)
END IF;
```

**Why locking is needed.** InnoDB runs at REPEATABLE READ by default, and a plain `SELECT` reads from
a snapshot without locking [11]. Table 4.5 shows what happens when two students, A and B, both ask for
the last seat of CS302-A without a lock. The 2-second delay only widens the window so the problem
shows every time.

**Table 4.5: Schedule without locking (lost update)**

| Time | Transaction A (student 1) | Transaction B (student 2) |
|---|---|---|
| t1 | START TRANSACTION; read section (no lock) | |
| t2 | COUNT enrolled = 0 → seat free | START TRANSACTION; read section (no lock) |
| t3 | sleeping | COUNT enrolled = 0 → seat free |
| t4 | INSERT enrollment; COMMIT | sleeping |
| t5 | | INSERT enrollment; COMMIT |
| Result | **2 students in a 1-seat section** | |

With `FOR UPDATE`, the first transaction takes an exclusive (X) lock on the section row. The second
must wait for that lock, and when it gets it, its reads see the committed insert [10]:

**Table 4.6: Schedule with FOR UPDATE**

| Time | Transaction A (student 1) | Transaction B (student 2) |
|---|---|---|
| t1 | START; `SELECT … FOR UPDATE` → X lock on section 5 | |
| t2 | COUNT enrolled = 0 → seat free | START; `SELECT … FOR UPDATE` → **waits** |
| t3 | INSERT enrollment; COMMIT → lock released | waiting (about 2 s) |
| t4 | | lock granted; COUNT enrolled = 1 → full |
| t5 | | INSERT into waitlist; COMMIT |
| Result | **1 enrolled, 1 waitlisted** | |

The locking read must be the first read in the transaction. Under REPEATABLE READ the snapshot is
fixed at the first plain read, and a snapshot taken before the lock would miss A's insert. The live
lock monitor (Fig. 5.8) reads `performance_schema.data_locks` through the view `v_lock_monitor` and
shows the waiting lock while the race runs.

**Isolation levels.** We ran three scripted experiments with two sessions at each of the four
isolation levels (Table 4.7).

**Table 4.7: Isolation levels and observed anomalies**

| Isolation level | Dirty read | Non-repeatable read | Phantom (plain read) |
|---|---|---|---|
| READ UNCOMMITTED | Occurred (read 99 before rollback) | Occurred (4 → 10) | Occurred (0 → 1) |
| READ COMMITTED | Prevented | Occurred (4 → 10) | Occurred (0 → 1) |
| REPEATABLE READ | Prevented | Prevented (snapshot) | Prevented for plain reads; a `FOR SHARE` read saw the new row |
| SERIALIZABLE | Prevented | Prevented (writer blocked) | Prevented (writer blocked) |

**Deadlock.** When two transactions lock sections 6 and 7 in opposite order, each holds one lock and
waits for the other. InnoDB detects the cycle at once and rolls one transaction back with error 1213;
the other then completes [12]. In our test, the victim retried and succeeded (Fig. 5.9).
`sp_register_cart` avoids this by always locking sections in `section_id` order.

**Cursor.** When an admin raises a section's capacity, `sp_set_capacity` walks the waitlist in request
order with a cursor and promotes each student who still fits, until the new seats are used up:

```sql
DECLARE cur_waitlist CURSOR FOR
  SELECT student_id FROM waitlist WHERE section_id = p_section_id ORDER BY requested_at;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET l_done = TRUE;
...
OPEN cur_waitlist;
promote_loop: LOOP
  FETCH cur_waitlist INTO l_student;
  IF l_done OR l_enrolled >= p_new_capacity THEN LEAVE promote_loop; END IF;
  IF NOT fn_has_clash(l_student, p_section_id) THEN   -- credit check omitted here
    INSERT INTO enrollments (student_id, section_id) VALUES (l_student, p_section_id);
    DELETE FROM waitlist WHERE student_id = l_student AND section_id = p_section_id;
    SET l_enrolled = l_enrolled + 1;
  END IF;
END LOOP;
CLOSE cur_waitlist;
```

**Triggers and savepoints.** The audit log is written only by triggers, so no code path can forget
it. An audit row written by a trigger belongs to the same transaction, so a rollback removes it too.
`sp_register_cart` sets a `SAVEPOINT` before each section in a multi-section request. If one section
fails, `ROLLBACK TO SAVEPOINT` undoes only that section and the rest of the cart is still committed.

**Roles (DCL).** Three roles follow the principle of least privilege [14] (Table 4.8). Procedures run
with their definer's rights, so `app_student` can call `sp_register` without any privilege on the
tables it writes to.

**Table 4.8: Role privileges**

| Role (login user) | Can do | Cannot do |
|---|---|---|
| `app_student` (`coursereg_student`) | EXECUTE `sp_register`, `sp_drop`, `sp_register_cart`; SELECT on three views | Read or write any table directly |
| `app_report` (`coursereg_report`) | SELECT on every table and view | Any write |
| `app_admin` (`coursereg_admin`) | Everything both roles above can do, plus EXECUTE `sp_set_capacity` | Change the schema |

```sql
CREATE ROLE app_student, app_admin, app_report;
GRANT EXECUTE ON PROCEDURE course_reg.sp_register TO app_student;
GRANT SELECT ON course_reg.* TO app_report;
GRANT app_student, app_report TO app_admin;   -- a role can hold other roles
```

---

## 5. System Interface

### 5.1 GUI Screenshots

The interface is a Flask web application with Bootstrap pages. Flask is kept thin: each page calls a
JSON route, and each route either reads a view or calls a stored procedure through a small Python
wrapper. No registration rule is written in Python, so the database gives the same answers whether
it is used from the web page, the command line or MySQL Workbench. A "Login as" menu in the navigation
bar switches between the 15 seeded students (there is no real authentication).

[Insert Fig. 5.1] **Fig. 5.1: Course catalog with live seat bars** (green, amber, red as a section fills; refreshes every 2 s)

[Insert Fig. 5.2] **Fig. 5.2: Registration messages returned by MySQL** (an "Enrolled" message and a "Missing prerequisite: CS101." message)

[Insert Fig. 5.3] **Fig. 5.3: Student weekly timetable** [teammate's page]

[Insert Fig. 5.4] **Fig. 5.4: Admin page with capacity change and audit log** [teammate's page]

[Insert Fig. 5.5] **Fig. 5.5: Race Arena showing both transactions' timelines** [teammate's page]

### 5.2 Query Output Snapshots

The SQL test script checks every rule against the seed data and prints PASS or FAIL for each case.
All 43 tests passed (Table 5.1, Fig. 5.6).

**Table 5.1: Test case summary**

| Group | Tests | Examples |
|---|---|---|
| Stored functions | 6 | Overlapping classes clash; back-to-back classes do not |
| Views | 5 | MA102 ranks first in Mathematics; waitlist positions 1, 2, 3 |
| Registration rules | 10 | Free seat → ENROLLED; full → WAITLISTED; clash, prerequisite and credit limit → REJECTED with no rows inserted |
| Atomicity | 3 | Simulated failure after insert → insert rolled back, audited |
| Drop and promotion | 5 | First waitlisted student promoted; dropping when not registered → error |
| Capacity change (cursor) | 5 | Capacity 3 → 5 promotes the first two in order |
| Triggers | 2 | Waitlisting an enrolled course is blocked; audit rows written |
| Cart (savepoints) | 4 | Failed section rolled back to its savepoint, others kept |
| Waitlist expiry (event) | 3 | Only the 40-day-old entry removed; event enabled |
| **Total** | **43** | **43 passed, 0 failed** |

[Insert Fig. 5.6] **Fig. 5.6: SQL test results (43 passed, 0 failed)**

[Insert Fig. 5.7 (a) and (b) side by side] **Fig. 5.7: Race for the last seat: (a) without locking, 2/1 overbooked; (b) with FOR UPDATE, 1 enrolled and 1 waitlisted in 10 of 10 runs**

[Insert Fig. 5.8] **Fig. 5.8: Live lock monitor during a safe race: one X lock granted, one waiting**

[Insert Fig. 5.9] **Fig. 5.9: Deadlock detected by InnoDB (error 1213) and the retry**

[Insert Fig. 5.10] **Fig. 5.10: Isolation level experiment output**

[Insert Fig. 5.11] **Fig. 5.11: EXPLAIN output before and after adding the audit-log index**

[Insert Fig. 5.12] **Fig. 5.12: Role-based access control: direct INSERT denied, procedure call allowed**

[Insert Fig. 5.13] **Fig. 5.13: Course demand ranking using RANK() OVER (PARTITION BY department)**

---

## 6. Conclusion

We built a course registration database in MySQL 8.0 in which every rule lives in the database: 11
tables in BCNF, 8 views, 4 functions, 6 procedures, 4 triggers, a scheduled event and 3 roles. The
central result is the race test. Without a lock, two students both got the single seat of CS302-A;
with `SELECT … FOR UPDATE` inside one transaction, exactly one student was enrolled and the other
waitlisted in every one of 10 runs. The second transaction visibly waited about 2 seconds for the
lock. The same project gave measured results for the four isolation levels, a deadlock detected and
resolved by InnoDB, and an index that cut a query from 22.6 ms to 0.04 ms. All 43 SQL tests pass on a
fresh database.

Putting the rules in stored procedures had a practical benefit too. The two of us worked on separate
machines (Linux and Windows) and separate layers, and the procedures acted as a fixed contract
between the database and the interface. The system has limits: it has no real login, it runs on a
single database server, and the demo users have development passwords. Future work could add
authentication, priority rules for the waitlist (for example final-year students first), e-mail
notification on promotion, and connection pooling for heavier load.

---

## 7. References

[1] A. Silberschatz, H. F. Korth and S. Sudarshan, *Database System Concepts*, 7th ed. New York, NY,
USA: McGraw-Hill, 2019, ISBN 978-0-07-802215-9.

[2] Oracle Corporation, "MySQL 8.0 Reference Manual." [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/. Accessed: Oct. 24, 2026.

[3] Pallets Projects, "Flask Documentation." [Online]. Available:
https://flask.palletsprojects.com/en/stable/. Accessed: Oct. 24, 2026.

[4] Oracle Corporation, "MySQL Connector/Python Developer Guide." [Online]. Available:
https://dev.mysql.com/doc/connector-python/en/. Accessed: Oct. 24, 2026.

[5] Bootstrap Team, "Bootstrap 5.3 Documentation." [Online]. Available:
https://getbootstrap.com/docs/5.3/. Accessed: Oct. 24, 2026.

[6] E. F. Codd, "A relational model of data for large shared data banks," *Communications of the
ACM*, vol. 13, no. 6, pp. 377–387, 1970, doi: 10.1145/362384.362685.

[7] R. Elmasri and S. B. Navathe, *Fundamentals of Database Systems*, 7th ed. Boston, MA, USA:
Pearson, 2016, ISBN 978-0-13-397077-7.

[8] Oracle Corporation, "Window Functions," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/window-functions.html. Accessed: Oct. 24, 2026.

[9] Oracle Corporation, "Stored Objects," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/stored-objects.html. Accessed: Oct. 24, 2026.

[10] Oracle Corporation, "Locking Reads," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html. Accessed: Oct. 24, 2026.

[11] Oracle Corporation, "Transaction Isolation Levels," in *MySQL 8.0 Reference Manual*. [Online].
Available: https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-isolation-levels.html.
Accessed: Oct. 24, 2026.

[12] Oracle Corporation, "Deadlocks in InnoDB," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/innodb-deadlocks.html. Accessed: Oct. 24, 2026.

[13] Oracle Corporation, "Using the Event Scheduler," in *MySQL 8.0 Reference Manual*. [Online].
Available: https://dev.mysql.com/doc/refman/8.0/en/event-scheduler.html. Accessed: Oct. 24, 2026.

[14] Oracle Corporation, "Using Roles," in *MySQL 8.0 Reference Manual*. [Online]. Available:
https://dev.mysql.com/doc/refman/8.0/en/roles.html. Accessed: Oct. 24, 2026.

## Annexure A: SQL scripts (optional)

[If pages allow, attach `db/01_schema.sql` to `db/07_seed.sql` in Courier New 9 pt. Otherwise write:
"The complete SQL scripts (1,148 lines) are available from the authors on request."]

---

## Part C: prompt for Fig. 2.1 (ER diagram)

> Draw an ER diagram in Chen notation on a white background, black lines, readable when printed at
> page width. Entities as rectangles, relationships as diamonds, attributes as ovals, key attributes
> underlined, cardinality written on each line (1, N, M). Double lines mean total participation.
>
> Entities and attributes:
> - DEPARTMENT: <u>dept_id</u>, name
> - STUDENT: <u>student_id</u>, name, email, max_credits
> - INSTRUCTOR: <u>instructor_id</u>, name
> - COURSE: <u>course_id</u>, code, title, credits
> - SECTION: <u>section_id</u>, section_code, room, capacity
> - MEETING: <u>meeting_id</u>, day, start_time, end_time
> - AUDIT_LOG: <u>log_id</u>, action, details, logged_at (draw it apart, connected to nothing)
>
> Relationships:
> - DEPARTMENT —1— BELONGS_TO —N— STUDENT (student side total)
> - DEPARTMENT —1— EMPLOYS —N— INSTRUCTOR (instructor side total)
> - DEPARTMENT —1— OFFERS —N— COURSE (course side total)
> - COURSE —1— HAS —N— SECTION (section side total)
> - INSTRUCTOR —1— TEACHES —N— SECTION (section side total)
> - SECTION —1— MEETS_AT —N— MEETING (meeting side total)
> - STUDENT —M— ENROLLS_IN —N— SECTION, relationship attribute: enrolled_at
> - STUDENT —M— WAITS_FOR —N— SECTION, relationship attribute: requested_at
> - STUDENT —M— COMPLETED —N— COURSE, relationship attribute: grade
> - COURSE —M— REQUIRES —N— COURSE (recursive; label the two lines "course" and "prerequisite")

---

## Part D: before you submit
- [ ] Names, registration numbers and the teammate's name filled in (cover, certificate, Table 1.2).
- [ ] Table 1.2 hardware details filled in.
- [ ] Section 4.3 settled with the instructor.
- [ ] Every `[Insert Fig …]` replaced by a real screenshot (see `snapshots.md`). Remove Figs 5.3–5.5
      and their mentions if those pages were not built, and renumber.
- [ ] Remove the Chart.js row in Table 1.1 if the analytics page doesn't use it.
- [ ] Open each reference link once to confirm it works.
- [ ] Lists of tables and figures and the table of contents match the final page numbers.
- [ ] The "General Guidelines" page of the template is **not** included.
- [ ] Ran the final PDF through a similarity checker and an AI detector, and rewrote flagged paragraphs in your own words.
- [ ] 15 to 20 pages.
