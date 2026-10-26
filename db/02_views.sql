-- 02_views.sql: read-only views the app queries instead of joining tables itself.

-- One row per section with live seat numbers. Counts are pre-aggregated in derived tables:
-- joining enrollments and waitlist directly would multiply rows (3 enrolled x 2 waiting = 6) and
-- inflate both counts. seats_left goes negative if the unsafe race overbooks a section.
CREATE VIEW v_section_seats AS
SELECT s.section_id,
       c.course_id,
       c.code   AS course_code,
       c.title  AS course_title,
       c.credits,
       s.section_code,
       i.name   AS instructor_name,
       s.room,
       s.capacity,
       COALESCE(e.enrolled, 0)                              AS enrolled,
       s.capacity - COALESCE(e.enrolled, 0)                 AS seats_left,
       COALESCE(w.waitlist_len, 0)                          AS waitlist_len,
       ROUND(100 * COALESCE(e.enrolled, 0) / s.capacity, 1) AS fill_pct
FROM sections s
JOIN courses c     ON c.course_id = s.course_id
JOIN instructors i ON i.instructor_id = s.instructor_id
LEFT JOIN (SELECT section_id, COUNT(*) AS enrolled
           FROM enrollments GROUP BY section_id) e ON e.section_id = s.section_id
LEFT JOIN (SELECT section_id, COUNT(*) AS waitlist_len
           FROM waitlist GROUP BY section_id) w    ON w.section_id = s.section_id;

-- One row per weekly meeting of every section a student is enrolled in.
CREATE VIEW v_student_timetable AS
SELECT e.student_id,
       s.section_id,
       c.code  AS course_code,
       c.title AS course_title,
       s.section_code,
       i.name  AS instructor_name,
       s.room,
       m.day,
       m.start_time,
       m.end_time
FROM enrollments e
JOIN sections s         ON s.section_id = e.section_id
JOIN courses c          ON c.course_id = s.course_id
JOIN instructors i      ON i.instructor_id = s.instructor_id
JOIN section_meetings m ON m.section_id = s.section_id;

-- Each waitlisted student's place in line (1 = promoted next), numbered per section by ROW_NUMBER().
CREATE VIEW v_waitlist_positions AS
SELECT w.student_id,
       w.section_id,
       c.code AS course_code,
       c.title AS course_title,
       s.section_code,
       w.requested_at,
       ROW_NUMBER() OVER (PARTITION BY w.section_id ORDER BY w.requested_at) AS position
FROM waitlist w
JOIN sections s ON s.section_id = w.section_id
JOIN courses c  ON c.course_id = s.course_id;

-- The audit log with names instead of bare ids, for the admin feed. LEFT JOINs keep log rows whose
-- student or section no longer exists.
CREATE VIEW v_audit_feed AS
SELECT a.log_id,
       a.logged_at,
       a.action,
       a.student_id,
       st.name AS student_name,
       a.section_id,
       CONCAT(c.code, '-', s.section_code) AS section_label,
       a.details
FROM audit_log a
LEFT JOIN students st ON st.student_id = a.student_id
LEFT JOIN sections s  ON s.section_id = a.section_id
LEFT JOIN courses c   ON c.course_id = s.course_id;

-- Analytics ---------------------------------------------------------------------------------------

-- Demand per course (enrolled + waitlisted over all its sections), ranked within its department.
-- A CTE sums the sections, then RANK() OVER (PARTITION BY ...) ranks each department separately.
CREATE VIEW v_course_demand AS
WITH course_totals AS (
  SELECT course_id,
         SUM(capacity)     AS capacity,
         SUM(enrolled)     AS enrolled,
         SUM(waitlist_len) AS waitlisted
  FROM v_section_seats
  GROUP BY course_id
)
SELECT d.name  AS dept_name,
       c.course_id,
       c.code  AS course_code,
       c.title AS course_title,
       t.capacity,
       t.enrolled,
       t.waitlisted,
       t.enrolled + t.waitlisted                         AS demand,
       ROUND(100 * (t.enrolled + t.waitlisted) / t.capacity, 1) AS demand_pct,
       RANK() OVER (PARTITION BY c.dept_id ORDER BY t.enrolled + t.waitlisted DESC) AS dept_rank
FROM course_totals t
JOIN courses c     ON c.course_id = t.course_id
JOIN departments d ON d.dept_id = c.dept_id;

-- Courses where demand is higher than all their seats combined: candidates for a new section.
CREATE VIEW v_oversubscribed_courses AS
SELECT course_id,
       course_code,
       course_title,
       SUM(capacity)                     AS capacity,
       SUM(enrolled) + SUM(waitlist_len) AS demand
FROM v_section_seats
GROUP BY course_id, course_code, course_title
HAVING demand > capacity;

-- Registration activity per day from the audit log, with a running total of enrolled seats.
-- The CTE groups by day; SUM() OVER (ORDER BY ...) then adds each day to all the days before it.
CREATE VIEW v_daily_activity AS
WITH daily AS (
  SELECT DATE(logged_at)                    AS activity_date,
         SUM(action IN ('ENROLL', 'PROMOTE')) AS enrolls,
         SUM(action = 'DROP')                 AS drops,
         SUM(action = 'WAITLIST')             AS waitlists,
         SUM(action = 'REJECT')               AS rejects
  FROM audit_log
  GROUP BY DATE(logged_at)
)
SELECT activity_date,
       enrolls,
       drops,
       waitlists,
       rejects,
       SUM(enrolls - drops) OVER (ORDER BY activity_date) AS total_enrolled
FROM daily;

-- Live InnoDB locks on this database, for the Race Arena lock monitor. thread_id is the
-- connection id (SELECT CONNECTION_ID()); blocked_by_thread_id is set while a lock is WAITING.
-- Uses performance_schema only: it honours the view definer's privileges, so readers of the view
-- need no extra grants (information_schema.innodb_trx would demand PROCESS from every reader).
CREATE VIEW v_lock_monitor AS
SELECT th.processlist_id  AS thread_id,
       l.object_name      AS table_name,
       l.lock_type,
       l.lock_mode,
       l.lock_status,
       l.lock_data,
       bth.processlist_id AS blocked_by_thread_id
FROM performance_schema.data_locks l
JOIN performance_schema.threads th             ON th.thread_id = l.thread_id
LEFT JOIN performance_schema.data_lock_waits w ON w.requesting_engine_lock_id = l.engine_lock_id
LEFT JOIN performance_schema.threads bth       ON bth.thread_id = w.blocking_thread_id
WHERE l.object_schema = 'course_reg';
