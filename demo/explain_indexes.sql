-- explain_indexes.sql: query plans before and after adding the two non-key indexes, for the
-- report's indexing chapter. It adds and then removes 100,000 audit rows; run reset.sh afterwards.
--   mysql -u coursereg_dev -p course_reg -t < demo/explain_indexes.sql

-- 1. Clash detection: the join inside fn_has_clash looks for meetings on the same day. ------------
ALTER TABLE section_meetings DROP INDEX idx_section_meetings_day_start;
ANALYZE TABLE section_meetings;   -- refresh statistics: the optimizer plans from them
SELECT 'Clash query BEFORE idx_section_meetings_day_start' AS step;
EXPLAIN
SELECT 1
FROM section_meetings new_m
JOIN section_meetings old_m ON old_m.day = new_m.day
                           AND new_m.start_time < old_m.end_time
                           AND old_m.start_time < new_m.end_time
JOIN enrollments e          ON e.section_id = old_m.section_id
WHERE new_m.section_id = 10 AND e.student_id = 3 AND old_m.section_id <> 10;

ALTER TABLE section_meetings ADD INDEX idx_section_meetings_day_start (day, start_time);
ANALYZE TABLE section_meetings;
SELECT 'Clash query AFTER idx_section_meetings_day_start' AS step;
EXPLAIN
SELECT 1
FROM section_meetings new_m
JOIN section_meetings old_m ON old_m.day = new_m.day
                           AND new_m.start_time < old_m.end_time
                           AND old_m.start_time < new_m.end_time
JOIN enrollments e          ON e.section_id = old_m.section_id
WHERE new_m.section_id = 10 AND e.student_id = 3 AND old_m.section_id <> 10;

-- 2. Admin audit feed: the 20 newest rows of a 100,000-row log, with real timings. ---------------
SET SESSION cte_max_recursion_depth = 100000;
INSERT INTO audit_log (action, student_id, section_id, details, logged_at)
WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 100000)
SELECT 'ENROLL', 1 + i % 15, 1 + i % 14, 'bulk test row', NOW(6) - INTERVAL i MINUTE FROM n;
ANALYZE TABLE audit_log;

ALTER TABLE audit_log DROP INDEX idx_audit_log_logged_at;
SELECT 'Audit feed BEFORE idx_audit_log_logged_at' AS step;
EXPLAIN SELECT * FROM audit_log ORDER BY logged_at DESC LIMIT 20;
EXPLAIN ANALYZE SELECT * FROM audit_log ORDER BY logged_at DESC LIMIT 20\G

ALTER TABLE audit_log ADD INDEX idx_audit_log_logged_at (logged_at);
SELECT 'Audit feed AFTER idx_audit_log_logged_at' AS step;
EXPLAIN SELECT * FROM audit_log ORDER BY logged_at DESC LIMIT 20;
EXPLAIN ANALYZE SELECT * FROM audit_log ORDER BY logged_at DESC LIMIT 20\G

DELETE FROM audit_log WHERE details = 'bulk test row';
