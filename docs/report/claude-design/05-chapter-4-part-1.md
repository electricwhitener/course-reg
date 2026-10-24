Add the first part of Chapter 4 (sections 4.1 to 4.4) below, starting on a new page after Chapter 3. Put every SQL code block in Courier New 10 pt inside a light grey box. Follow the layout rules from my first message. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

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
The excerpt is shortened; the full view also returns the course title, credits, instructor, room and fill percentage.

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

Not applicable to this project.

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
| 20 newest audit rows (100,000-row table) | `ALL` + `Using filesort`: 100,029 rows read, about 23 ms | `Backward index scan` on `idx_audit_log_logged_at`: 20 rows read, under 0.1 ms |

The audit index keeps rows in `logged_at` order in a B+ tree, so MySQL reads the last 20 entries and
stops, with no sorting at all.
