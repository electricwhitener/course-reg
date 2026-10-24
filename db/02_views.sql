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
