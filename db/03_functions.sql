-- 03_functions.sql: the registration rules, as reusable stored functions.

DELIMITER $$

-- TRUE if any meeting of p_section_id overlaps a meeting of a section the student is enrolled in.
-- Two intervals overlap when each one starts before the other ends (touching end-to-start is fine).
CREATE FUNCTION fn_has_clash(p_student_id INT, p_section_id INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM section_meetings new_m
    JOIN section_meetings old_m ON old_m.day = new_m.day
                               AND new_m.start_time < old_m.end_time
                               AND old_m.start_time < new_m.end_time
    JOIN enrollments e          ON e.section_id = old_m.section_id
    WHERE new_m.section_id = p_section_id
      AND e.student_id = p_student_id
      AND old_m.section_id <> p_section_id
  );
END$$

-- TRUE if the student has completed every prerequisite of the course (relational division:
-- there is no prerequisite that the student has NOT completed).
CREATE FUNCTION fn_prereqs_met(p_student_id INT, p_course_id INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM prerequisites p
    WHERE p.course_id = p_course_id
      AND NOT EXISTS (SELECT 1
                      FROM completed_courses cc
                      WHERE cc.student_id = p_student_id
                        AND cc.course_id = p.prereq_course_id)
  );
END$$

-- Total credits of the sections the student is currently enrolled in (waitlist not counted).
CREATE FUNCTION fn_current_credits(p_student_id INT)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE l_total INT;
  SELECT COALESCE(SUM(c.credits), 0) INTO l_total
  FROM enrollments e
  JOIN sections s ON s.section_id = e.section_id
  JOIN courses c  ON c.course_id = s.course_id
  WHERE e.student_id = p_student_id;
  RETURN l_total;
END$$

DELIMITER ;
