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

-- Why the student cannot register for the section, or NULL if every rule passes. Rules are checked
-- in order and the first failure becomes the message. Shared by sp_register and sp_register_cart,
-- so both always apply exactly the same rules.
CREATE FUNCTION fn_registration_error(p_student_id INT, p_section_id INT)
RETURNS VARCHAR(255)
READS SQL DATA
BEGIN
  DECLARE l_course_id   INT;
  DECLARE l_credits     INT;
  DECLARE l_max_credits INT;
  DECLARE l_label       VARCHAR(20);
  DECLARE l_missing     VARCHAR(255);

  SELECT s.course_id, c.credits, CONCAT(c.code, '-', s.section_code)
    INTO l_course_id, l_credits, l_label
  FROM sections s JOIN courses c ON c.course_id = s.course_id
  WHERE s.section_id = p_section_id;

  SELECT max_credits INTO l_max_credits FROM students WHERE student_id = p_student_id;

  IF l_course_id IS NULL THEN
    RETURN 'Section not found.';
  ELSEIF l_max_credits IS NULL THEN
    RETURN 'Student not found.';
  ELSEIF EXISTS (SELECT 1 FROM enrollments WHERE student_id = p_student_id AND section_id = p_section_id) THEN
    RETURN CONCAT('You are already enrolled in ', l_label, '.');
  ELSEIF EXISTS (SELECT 1 FROM waitlist WHERE student_id = p_student_id AND section_id = p_section_id) THEN
    RETURN CONCAT('You are already on the waitlist for ', l_label, '.');
  ELSEIF EXISTS (SELECT 1 FROM enrollments e JOIN sections s ON s.section_id = e.section_id
                 WHERE e.student_id = p_student_id AND s.course_id = l_course_id
                 UNION ALL
                 SELECT 1 FROM waitlist w JOIN sections s ON s.section_id = w.section_id
                 WHERE w.student_id = p_student_id AND s.course_id = l_course_id) THEN
    RETURN 'You are already registered in another section of this course.';
  ELSEIF NOT fn_prereqs_met(p_student_id, l_course_id) THEN
    SELECT GROUP_CONCAT(c.code ORDER BY c.code SEPARATOR ', ') INTO l_missing
    FROM prerequisites p JOIN courses c ON c.course_id = p.prereq_course_id
    WHERE p.course_id = l_course_id
      AND NOT EXISTS (SELECT 1 FROM completed_courses cc
                      WHERE cc.student_id = p_student_id AND cc.course_id = p.prereq_course_id);
    RETURN CONCAT('Missing prerequisite: ', l_missing, '.');
  ELSEIF fn_current_credits(p_student_id) + l_credits > l_max_credits THEN
    RETURN CONCAT('Credit limit exceeded: ', fn_current_credits(p_student_id), ' enrolled + ',
                  l_credits, ' would be over your limit of ', l_max_credits, '.');
  ELSEIF fn_has_clash(p_student_id, p_section_id) THEN
    RETURN CONCAT(l_label, ' clashes with a class already in your timetable.');
  END IF;
  RETURN NULL;
END$$

DELIMITER ;
