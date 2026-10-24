-- tests.sql: checks every registration rule against the seed data. It changes data, so always run
-- it on a fresh database:   bash db/reset.sh && mysql -u coursereg_dev -p course_reg < db/tests.sql
-- The last result is a PASS/FAIL table. The script ends with an error if any test failed.

DROP TEMPORARY TABLE IF EXISTS test_results;
CREATE TEMPORARY TABLE test_results (
  test_no INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(100) NOT NULL,
  passed  BOOLEAN NOT NULL
);

DROP PROCEDURE IF EXISTS test_expect_error;
DROP PROCEDURE IF EXISTS test_finish;
DROP PROCEDURE IF EXISTS test_require_fresh;

DELIMITER $$

-- Runs a statement and passes if it raises an error.
CREATE PROCEDURE test_expect_error(p_name VARCHAR(100), p_sql TEXT)
BEGIN
  DECLARE l_failed BOOLEAN DEFAULT FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET l_failed = TRUE;
    SET @test_sql = p_sql;
    PREPARE test_stmt FROM @test_sql;
    EXECUTE test_stmt;
  END;
  DEALLOCATE PREPARE test_stmt;
  INSERT INTO test_results (name, passed) VALUES (p_name, l_failed);
END$$

CREATE PROCEDURE test_finish()
BEGIN
  IF EXISTS (SELECT 1 FROM test_results WHERE NOT passed) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Some tests FAILED (see the table above).';
  END IF;
END$$

-- Seed data only ever writes ENROLL and WAITLIST rows, so anything else means the tests already ran.
CREATE PROCEDURE test_require_fresh()
BEGIN
  IF EXISTS (SELECT 1 FROM audit_log WHERE action NOT IN ('ENROLL', 'WAITLIST')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Database is not fresh: run bash db/reset.sh first.';
  END IF;
END$$

DELIMITER ;

CALL test_require_fresh();
DROP PROCEDURE test_require_fresh;

-- Functions --------------------------------------------------------------------------------------
INSERT INTO test_results (name, passed) VALUES
  ('fn_has_clash: MA102-A vs PH101-A overlap',          fn_has_clash(3, 10)),
  ('fn_has_clash: back-to-back classes do not clash',   NOT fn_has_clash(4, 3)),
  ('fn_prereqs_met: no completions -> CS201 unmet',     NOT fn_prereqs_met(4, 2)),
  ('fn_prereqs_met: CS101 done -> CS201 met',           fn_prereqs_met(3, 2)),
  ('fn_prereqs_met: course with no prerequisites',      fn_prereqs_met(4, 1)),
  ('fn_current_credits: Vihaan has 7',                  fn_current_credits(5) = 7);

-- Analytics views (on untouched seed data) --------------------------------------------------------
INSERT INTO test_results (name, passed) VALUES
  ('v_course_demand: MA102 ranks #1 in Mathematics',
     (SELECT course_code FROM v_course_demand WHERE dept_name = 'Mathematics' AND dept_rank = 1) = 'MA102'),
  ('v_oversubscribed_courses: MA102 and PH201',
     (SELECT GROUP_CONCAT(course_code ORDER BY course_code) FROM v_oversubscribed_courses) = 'MA102,PH201'),
  ('v_daily_activity: running total = 24 seeded enrollments',
     (SELECT total_enrolled FROM v_daily_activity ORDER BY activity_date DESC LIMIT 1) = 24);

-- sp_register ------------------------------------------------------------------------------------
CALL sp_register(1, 5, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('free seat -> ENROLLED', @status = 'ENROLLED'
                            AND EXISTS (SELECT 1 FROM enrollments WHERE student_id = 1 AND section_id = 5));

CALL sp_register(2, 5, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('full section -> WAITLISTED #1', @status = 'WAITLISTED' AND @msg LIKE '%#1 %'
                                    AND EXISTS (SELECT 1 FROM waitlist WHERE student_id = 2 AND section_id = 5));

CALL sp_register(1, 5, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('already enrolled -> REJECTED', @status = 'REJECTED' AND @msg LIKE 'You are already enrolled%');

CALL sp_register(2, 5, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('already waitlisted -> REJECTED', @status = 'REJECTED' AND @msg LIKE '%already on the waitlist%');

CALL sp_register(3, 14, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('other section of same course -> REJECTED', @status = 'REJECTED' AND @msg LIKE '%another section%');

SET @rows_before = (SELECT COUNT(*) FROM enrollments) + (SELECT COUNT(*) FROM waitlist);
CALL sp_register(4, 3, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('missing prerequisite -> REJECTED', @status = 'REJECTED' AND @msg = 'Missing prerequisite: CS101.');

CALL sp_register(5, 10, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('over credit limit -> REJECTED', @status = 'REJECTED' AND @msg LIKE 'Credit limit exceeded%');

CALL sp_register(3, 10, TRUE, 0, FALSE, @status, @msg);
INSERT INTO test_results (name, passed) VALUES
  ('time clash -> REJECTED', @status = 'REJECTED' AND @msg LIKE '%clashes%'),
  ('rejections inserted no rows', (SELECT COUNT(*) FROM enrollments) + (SELECT COUNT(*) FROM waitlist) = @rows_before),
  ('rejections were audited', (SELECT COUNT(*) FROM audit_log WHERE action = 'REJECT') = 6);

-- Atomicity: p_fail raises an error after the insert, and the whole transaction is undone.
SET @enrolled_before = (SELECT COUNT(*) FROM enrollments);
CALL test_expect_error('p_fail -> error raised', 'CALL sp_register(15, 10, TRUE, 0, TRUE, @s, @m)');
INSERT INTO test_results (name, passed) VALUES
  ('p_fail -> insert rolled back', (SELECT COUNT(*) FROM enrollments) = @enrolled_before
                                   AND NOT EXISTS (SELECT 1 FROM enrollments WHERE student_id = 15 AND section_id = 10)),
  ('p_fail -> audit has rollback, not ENROLL',
     EXISTS (SELECT 1 FROM audit_log WHERE action = 'REJECT' AND student_id = 15 AND details LIKE 'Rolled back%')
     AND NOT EXISTS (SELECT 1 FROM audit_log WHERE action = 'ENROLL' AND student_id = 15 AND section_id = 10));

-- sp_drop ----------------------------------------------------------------------------------------
CALL sp_drop(6, 12);
INSERT INTO test_results (name, passed) VALUES
  ('drop -> first waitlisted promoted', EXISTS (SELECT 1 FROM enrollments WHERE student_id = 8 AND section_id = 12)
                                        AND NOT EXISTS (SELECT 1 FROM waitlist WHERE student_id = 8 AND section_id = 12)),
  ('drop -> second still waiting',      EXISTS (SELECT 1 FROM waitlist WHERE student_id = 9 AND section_id = 12)),
  ('drop -> DROP and PROMOTE audited',  EXISTS (SELECT 1 FROM audit_log WHERE action = 'DROP' AND student_id = 6 AND section_id = 12)
                                        AND EXISTS (SELECT 1 FROM audit_log WHERE action = 'PROMOTE' AND student_id = 8 AND section_id = 12));

CALL sp_drop(2, 5);
INSERT INTO test_results (name, passed) VALUES
  ('drop from waitlist -> removed', NOT EXISTS (SELECT 1 FROM waitlist WHERE student_id = 2 AND section_id = 5));

CALL test_expect_error('drop when not registered -> error', 'CALL sp_drop(15, 12)');

-- sp_set_capacity (cursor) -----------------------------------------------------------------------
CALL sp_set_capacity(14, 5);
INSERT INTO test_results (name, passed) VALUES
  ('capacity 3 -> 5 promotes first 2 in order', EXISTS (SELECT 1 FROM enrollments WHERE student_id = 12 AND section_id = 14)
                                                AND EXISTS (SELECT 1 FROM enrollments WHERE student_id = 13 AND section_id = 14)),
  ('third waitlisted student still waiting',    (SELECT GROUP_CONCAT(student_id) FROM waitlist WHERE section_id = 14) = '14'),
  ('view shows 5/5, 1 waiting',                 (SELECT CONCAT(enrolled, '/', capacity, ' ', waitlist_len)
                                                 FROM v_section_seats WHERE section_id = 14) = '5/5 1');

CALL test_expect_error('capacity below enrolled -> error', 'CALL sp_set_capacity(14, 2)');
CALL test_expect_error('capacity 0 -> CHECK constraint',   'CALL sp_set_capacity(4, 0)');

-- Triggers ---------------------------------------------------------------------------------------
CALL test_expect_error('waitlist trigger blocks enrolled course',
                       'INSERT INTO waitlist (student_id, section_id) VALUES (3, 14)');
INSERT INTO test_results (name, passed) VALUES
  ('ENROLL and WAITLIST audited', EXISTS (SELECT 1 FROM audit_log WHERE action = 'ENROLL' AND student_id = 1 AND section_id = 5)
                                  AND EXISTS (SELECT 1 FROM audit_log WHERE action = 'WAITLIST' AND student_id = 2 AND section_id = 5));

-- sp_register_cart (savepoints) -----------------------------------------------------------------
-- Diya: CS301-A rejected (missing MA201), CS302-A waitlisted (Aarav took the seat above),
-- MA102-A enrolled, PH102-A fails after its insert and is rolled back to its savepoint.
CALL sp_register_cart(2, '[11, 4, 8, 5]', 11, @cart);
INSERT INTO test_results (name, passed) VALUES
  ('cart: one result per section, in section_id order',
     JSON_EXTRACT(@cart, '$[*].section_id') = JSON_ARRAY(4, 5, 8, 11)),
  ('cart: statuses REJECTED, WAITLISTED, ENROLLED, REJECTED',
     JSON_EXTRACT(@cart, '$[*].status') = JSON_ARRAY('REJECTED', 'WAITLISTED', 'ENROLLED', 'REJECTED')),
  ('cart: good sections kept',
     EXISTS (SELECT 1 FROM enrollments WHERE student_id = 2 AND section_id = 8)
     AND EXISTS (SELECT 1 FROM waitlist WHERE student_id = 2 AND section_id = 5)),
  ('cart: failed section rolled back to savepoint',
     NOT EXISTS (SELECT 1 FROM enrollments WHERE student_id = 2 AND section_id = 11)
     AND NOT EXISTS (SELECT 1 FROM audit_log WHERE action = 'ENROLL' AND student_id = 2 AND section_id = 11)
     AND EXISTS (SELECT 1 FROM audit_log WHERE action = 'REJECT' AND student_id = 2 AND section_id = 11
                 AND details LIKE 'Rolled back to savepoint%'));

-- sp_expire_waitlist / event --------------------------------------------------------------------
INSERT INTO waitlist (student_id, section_id, requested_at) VALUES (15, 12, NOW() - INTERVAL 40 DAY);
SET @waiting_before = (SELECT COUNT(*) FROM waitlist);
CALL sp_expire_waitlist(30);
INSERT INTO test_results (name, passed) VALUES
  ('expiry: only the 40-day-old entry removed',
     (SELECT COUNT(*) FROM waitlist) = @waiting_before - 1
     AND NOT EXISTS (SELECT 1 FROM waitlist WHERE student_id = 15 AND section_id = 12)),
  ('expiry: EXPIRE audited',
     EXISTS (SELECT 1 FROM audit_log WHERE action = 'EXPIRE' AND student_id = 15 AND section_id = 12)),
  ('event ev_expire_waitlist is enabled',
     EXISTS (SELECT 1 FROM information_schema.events
             WHERE event_schema = 'course_reg' AND event_name = 'ev_expire_waitlist' AND status = 'ENABLED'));

-- Results ----------------------------------------------------------------------------------------
SELECT test_no, IF(passed, 'PASS', 'FAIL') AS result, name FROM test_results ORDER BY test_no;
SELECT SUM(passed) AS passed, COUNT(*) - SUM(passed) AS failed FROM test_results;

CALL test_finish();
DROP PROCEDURE test_expect_error;
DROP PROCEDURE test_finish;
