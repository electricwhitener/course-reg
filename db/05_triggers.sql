-- 05_triggers.sql: audit logging and a waitlist guard, enforced on every write no matter who makes it,
-- plus the scheduled event that expires old waitlist entries.
-- Audit rows written by a trigger are part of the same transaction, so a ROLLBACK removes them too.

DELIMITER $$

-- ENROLL, or PROMOTE when the student is still on this section's waitlist (procedures insert the
-- enrollment before deleting the waitlist row). Uses enrolled_at so seed data keeps its own dates.
CREATE TRIGGER trg_enrollments_after_insert
AFTER INSERT ON enrollments
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1 FROM waitlist WHERE student_id = NEW.student_id AND section_id = NEW.section_id) THEN
    INSERT INTO audit_log (action, student_id, section_id, details, logged_at)
    VALUES ('PROMOTE', NEW.student_id, NEW.section_id, 'Promoted from waitlist.', NEW.enrolled_at);
  ELSE
    INSERT INTO audit_log (action, student_id, section_id, logged_at)
    VALUES ('ENROLL', NEW.student_id, NEW.section_id, NEW.enrolled_at);
  END IF;
END$$

CREATE TRIGGER trg_enrollments_after_delete
AFTER DELETE ON enrollments
FOR EACH ROW
BEGIN
  INSERT INTO audit_log (action, student_id, section_id)
  VALUES ('DROP', OLD.student_id, OLD.section_id);
END$$

-- A student cannot wait for a course they are already enrolled in (any section of it).
CREATE TRIGGER trg_waitlist_before_insert
BEFORE INSERT ON waitlist
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1
             FROM enrollments e
             JOIN sections s_enrolled ON s_enrolled.section_id = e.section_id
             JOIN sections s_wanted   ON s_wanted.section_id = NEW.section_id
             WHERE e.student_id = NEW.student_id
               AND s_enrolled.course_id = s_wanted.course_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Already enrolled in this course; cannot join its waitlist.';
  END IF;
END$$

CREATE TRIGGER trg_waitlist_after_insert
AFTER INSERT ON waitlist
FOR EACH ROW
BEGIN
  INSERT INTO audit_log (action, student_id, section_id, logged_at)
  VALUES ('WAITLIST', NEW.student_id, NEW.section_id, NEW.requested_at);
END$$

DELIMITER ;

-- Every night at midnight, drop waitlist entries that have waited more than 30 days.
-- Needs the event scheduler, which is ON by default in MySQL 8.0 (SHOW VARIABLES LIKE 'event_scheduler').
CREATE EVENT ev_expire_waitlist
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY
DO CALL sp_expire_waitlist(30);
