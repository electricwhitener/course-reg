-- 06_security.sql: least-privilege roles (DCL). Roles and users are server-wide and survive
-- DROP DATABASE, so they are dropped and recreated on every reset.
--
-- Procedures run with their definer's rights (SQL SECURITY DEFINER, the default), so app_student
-- can CALL sp_register without having any privilege on the tables it writes to.

DROP USER IF EXISTS 'coursereg_student'@'localhost', 'coursereg_admin'@'localhost', 'coursereg_report'@'localhost';
DROP ROLE IF EXISTS app_student, app_admin, app_report;

CREATE ROLE app_student, app_admin, app_report;

-- Read-only access to everything, for analytics and reports.
GRANT SELECT ON course_reg.* TO app_report;

-- Students: register and drop through procedures only, and read the two views. No direct writes.
GRANT EXECUTE ON PROCEDURE course_reg.sp_register TO app_student;
GRANT EXECUTE ON PROCEDURE course_reg.sp_drop     TO app_student;
GRANT SELECT  ON course_reg.v_section_seats       TO app_student;
GRANT SELECT  ON course_reg.v_student_timetable   TO app_student;

-- Admins: everything a student and a reporter can do, plus changing capacity. Roles can hold roles.
GRANT app_student, app_report TO app_admin;
GRANT EXECUTE ON PROCEDURE course_reg.sp_set_capacity TO app_admin;

-- One login per role. Development passwords only.
CREATE USER 'coursereg_student'@'localhost' IDENTIFIED BY 'devpass';
CREATE USER 'coursereg_admin'@'localhost'   IDENTIFIED BY 'devpass';
CREATE USER 'coursereg_report'@'localhost'  IDENTIFIED BY 'devpass';

GRANT app_student TO 'coursereg_student'@'localhost';
GRANT app_admin   TO 'coursereg_admin'@'localhost';
GRANT app_report  TO 'coursereg_report'@'localhost';

SET DEFAULT ROLE app_student TO 'coursereg_student'@'localhost';
SET DEFAULT ROLE app_admin   TO 'coursereg_admin'@'localhost';
SET DEFAULT ROLE app_report  TO 'coursereg_report'@'localhost';
