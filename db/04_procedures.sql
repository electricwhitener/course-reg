-- 04_procedures.sql: registration, drop and capacity change, each as one transaction.
-- Every procedure locks the sections row first, so two transactions on the same section queue up.
-- Promotion (sp_drop, sp_set_capacity) inserts the enrollment BEFORE deleting the waitlist row,
-- which is how trg_enrollments_after_insert tells a PROMOTE apart from a normal ENROLL.

DELIMITER $$

CREATE PROCEDURE sp_register(
  IN  p_student_id INT,
  IN  p_section_id INT,
  IN  p_safe       BOOLEAN,       -- FALSE skips FOR UPDATE (race demo only)
  IN  p_delay      DECIMAL(4,1),  -- seconds to sleep between counting seats and inserting
  IN  p_fail       BOOLEAN,       -- TRUE raises an error after the insert to show ROLLBACK
  OUT p_status     VARCHAR(20),   -- ENROLLED | WAITLISTED | REJECTED
  OUT p_msg        VARCHAR(255)
)
BEGIN
  DECLARE l_capacity INT;
  DECLARE l_enrolled INT;
  DECLARE l_label    VARCHAR(20);
  DECLARE l_reject   VARCHAR(255);
  DECLARE l_error    VARCHAR(255);
  -- Timeline for the Race Arena. SYSDATE(6) is the real clock time (NOW() would be frozen per statement).
  DECLARE l_t_begin, l_t_locked, l_t_counted, l_t_written, l_t_end DATETIME(6);

  -- Any SQL error (or the simulated failure) undoes the whole transaction, is logged, and is re-raised.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 l_error = MESSAGE_TEXT;
    ROLLBACK;
    INSERT INTO audit_log (action, student_id, section_id, details)
    VALUES ('REJECT', p_student_id, p_section_id, CONCAT('Rolled back: ', l_error));
    RESIGNAL;
  END;

  SET l_t_begin = SYSDATE(6);
  START TRANSACTION;

  -- Safe mode takes an exclusive (X) lock on the section row: a second registration for the same
  -- section blocks here until this transaction ends. The locking read must be the transaction's
  -- first read, because REPEATABLE READ fixes its snapshot at the first plain read. Every read below
  -- then happens after the lock, so it sees the other transaction's committed insert.
  IF p_safe THEN
    SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_section_id FOR UPDATE;
  ELSE
    SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_section_id;
  END IF;
  SET l_t_locked = SYSDATE(6);

  SELECT CONCAT(c.code, '-', s.section_code) INTO l_label
  FROM sections s JOIN courses c ON c.course_id = s.course_id
  WHERE s.section_id = p_section_id;

  SET l_reject = fn_registration_error(p_student_id, p_section_id);

  IF l_reject IS NOT NULL THEN
    ROLLBACK;
    INSERT INTO audit_log (action, student_id, section_id, details)
    VALUES ('REJECT', p_student_id, p_section_id, l_reject);  -- autocommits: outside the transaction
    SET p_status = 'REJECTED', p_msg = l_reject;
  ELSE
    SELECT COUNT(*) INTO l_enrolled FROM enrollments WHERE section_id = p_section_id;
    SET l_t_counted = SYSDATE(6);

    -- The race window. In unsafe mode both transactions have counted the same free seat by now.
    IF p_delay > 0 THEN
      DO SLEEP(p_delay);
    END IF;

    IF l_enrolled < l_capacity THEN
      INSERT INTO enrollments (student_id, section_id) VALUES (p_student_id, p_section_id);
      SET p_status = 'ENROLLED', p_msg = CONCAT('Enrolled in ', l_label, '.');
    ELSE
      INSERT INTO waitlist (student_id, section_id) VALUES (p_student_id, p_section_id);
      SET p_status = 'WAITLISTED',
          p_msg = CONCAT(l_label, ' is full. You are #',
                         (SELECT COUNT(*) FROM waitlist WHERE section_id = p_section_id),
                         ' on the waitlist.');
    END IF;
    SET l_t_written = SYSDATE(6);

    IF p_fail THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Simulated failure after insert.';
    END IF;

    COMMIT;
  END IF;
  SET l_t_end = SYSDATE(6);

  -- One result row with the step timestamps (NULL for steps that did not happen).
  SELECT l_t_begin   AS t_begin,
         l_t_locked  AS t_locked,
         l_t_counted AS t_counted,
         l_t_written AS t_written,
         l_t_end     AS t_end;
END$$


-- Drops an enrollment (and promotes the first eligible waitlisted student), or leaves the waitlist.
CREATE PROCEDURE sp_drop(IN p_student_id INT, IN p_section_id INT)
BEGIN
  DECLARE l_capacity INT;
  DECLARE l_credits  INT;
  DECLARE l_enrolled INT;
  DECLARE l_next     INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_section_id FOR UPDATE;
  SELECT c.credits INTO l_credits
  FROM sections s JOIN courses c ON c.course_id = s.course_id
  WHERE s.section_id = p_section_id;

  DELETE FROM enrollments WHERE student_id = p_student_id AND section_id = p_section_id;

  IF ROW_COUNT() = 0 THEN
    DELETE FROM waitlist WHERE student_id = p_student_id AND section_id = p_section_id;
    IF ROW_COUNT() = 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not enrolled or waitlisted in this section.';
    END IF;
  ELSE
    SELECT COUNT(*) INTO l_enrolled FROM enrollments WHERE section_id = p_section_id;

    IF l_enrolled < l_capacity THEN
      -- Earliest waitlisted student who still fits (no clash, within credit limit).
      SELECT w.student_id INTO l_next
      FROM waitlist w JOIN students st ON st.student_id = w.student_id
      WHERE w.section_id = p_section_id
        AND NOT fn_has_clash(w.student_id, p_section_id)
        AND fn_current_credits(w.student_id) + l_credits <= st.max_credits
      ORDER BY w.requested_at
      LIMIT 1
      FOR UPDATE OF w;

      IF l_next IS NOT NULL THEN
        INSERT INTO enrollments (student_id, section_id) VALUES (l_next, p_section_id);
        DELETE FROM waitlist WHERE student_id = l_next AND section_id = p_section_id;
      END IF;
    END IF;
  END IF;

  COMMIT;
END$$


-- Changes a section's capacity, then a cursor walks the waitlist in order and promotes each
-- eligible student while seats remain.
CREATE PROCEDURE sp_set_capacity(IN p_section_id INT, IN p_new_capacity INT)
BEGIN
  DECLARE l_capacity INT;
  DECLARE l_credits  INT;
  DECLARE l_enrolled INT;
  DECLARE l_student  INT;
  DECLARE l_done     BOOLEAN DEFAULT FALSE;

  DECLARE cur_waitlist CURSOR FOR
    SELECT student_id FROM waitlist WHERE section_id = p_section_id ORDER BY requested_at;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET l_done = TRUE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_section_id FOR UPDATE;
  SELECT c.credits INTO l_credits
  FROM sections s JOIN courses c ON c.course_id = s.course_id
  WHERE s.section_id = p_section_id;

  IF l_capacity IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section not found.';
  END IF;

  SELECT COUNT(*) INTO l_enrolled FROM enrollments WHERE section_id = p_section_id;
  IF p_new_capacity < l_enrolled THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New capacity is below the number of students already enrolled.';
  END IF;

  UPDATE sections SET capacity = p_new_capacity WHERE section_id = p_section_id;

  SET l_done = FALSE;
  OPEN cur_waitlist;
  promote_loop: LOOP
    FETCH cur_waitlist INTO l_student;
    IF l_done OR l_enrolled >= p_new_capacity THEN
      LEAVE promote_loop;
    END IF;

    IF NOT fn_has_clash(l_student, p_section_id)
       AND fn_current_credits(l_student) + l_credits
           <= (SELECT max_credits FROM students WHERE student_id = l_student) THEN
      INSERT INTO enrollments (student_id, section_id) VALUES (l_student, p_section_id);
      DELETE FROM waitlist WHERE student_id = l_student AND section_id = p_section_id;
      SET l_enrolled = l_enrolled + 1;
    END IF;
  END LOOP;
  CLOSE cur_waitlist;

  COMMIT;
END$$



-- Registers for several sections in one transaction. Each section gets a SAVEPOINT: if a section
-- fails a rule, it is skipped; if an error happens while inserting it, ROLLBACK TO SAVEPOINT undoes
-- only that section's work and the rest of the cart is kept. Sections are locked in section_id order,
-- so two carts can never deadlock (compare sp_demo_deadlock).
--   p_section_ids:  JSON array of section ids, e.g. '[3, 9, 12]'
--   p_fail_section: simulate an error right after inserting this section (NULL = none)
--   p_results:      JSON array of {section_id, status, msg}, one per section, in locking order
CREATE PROCEDURE sp_register_cart(
  IN  p_student_id   INT,
  IN  p_section_ids  JSON,
  IN  p_fail_section INT,
  OUT p_results      JSON
)
BEGIN
  DECLARE l_section  INT;
  DECLARE l_capacity INT;
  DECLARE l_enrolled INT;
  DECLARE l_label    VARCHAR(20);
  DECLARE l_status   VARCHAR(20);
  DECLARE l_msg      VARCHAR(255);
  DECLARE l_done     BOOLEAN DEFAULT FALSE;

  DECLARE cur_cart CURSOR FOR
    SELECT DISTINCT section_id
    FROM JSON_TABLE(p_section_ids, '$[*]' COLUMNS (section_id INT PATH '$')) AS cart
    ORDER BY section_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET l_done = TRUE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET p_results = JSON_ARRAY();
  START TRANSACTION;
  OPEN cur_cart;

  cart_loop: LOOP
    FETCH cur_cart INTO l_section;
    IF l_done THEN
      LEAVE cart_loop;
    END IF;

    SAVEPOINT cart_item;
    cart_item: BEGIN
      -- An error inside this block undoes only this section, then the loop carries on.
      DECLARE EXIT HANDLER FOR SQLEXCEPTION
      BEGIN
        GET DIAGNOSTICS CONDITION 1 l_msg = MESSAGE_TEXT;
        ROLLBACK TO SAVEPOINT cart_item;
        SET l_status = 'REJECTED', l_msg = CONCAT('Rolled back to savepoint: ', l_msg);
        INSERT INTO audit_log (action, student_id, section_id, details)
        VALUES ('REJECT', p_student_id, l_section, l_msg);
      END;
      -- A SELECT ... INTO that finds no row must not end the outer cursor loop.
      DECLARE CONTINUE HANDLER FOR NOT FOUND BEGIN END;

      SET l_capacity = NULL, l_label = NULL;
      SELECT capacity INTO l_capacity FROM sections WHERE section_id = l_section FOR UPDATE;
      SET l_msg = fn_registration_error(p_student_id, l_section);

      IF l_msg IS NOT NULL THEN
        SET l_status = 'REJECTED';
        INSERT INTO audit_log (action, student_id, section_id, details)
        VALUES ('REJECT', p_student_id, l_section, l_msg);
      ELSE
        SELECT CONCAT(c.code, '-', s.section_code) INTO l_label
        FROM sections s JOIN courses c ON c.course_id = s.course_id
        WHERE s.section_id = l_section;
        SELECT COUNT(*) INTO l_enrolled FROM enrollments WHERE section_id = l_section;

        IF l_enrolled < l_capacity THEN
          INSERT INTO enrollments (student_id, section_id) VALUES (p_student_id, l_section);
          SET l_status = 'ENROLLED', l_msg = CONCAT('Enrolled in ', l_label, '.');
        ELSE
          INSERT INTO waitlist (student_id, section_id) VALUES (p_student_id, l_section);
          SET l_status = 'WAITLISTED', l_msg = CONCAT(l_label, ' is full. You are on the waitlist.');
        END IF;

        IF l_section = p_fail_section THEN
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Simulated failure after insert.';
        END IF;
      END IF;
    END cart_item;

    SET p_results = JSON_ARRAY_APPEND(p_results, '$',
                      JSON_OBJECT('section_id', l_section, 'status', l_status, 'msg', l_msg));
  END LOOP;

  CLOSE cur_cart;
  COMMIT;
END$$


-- Removes waitlist entries older than p_days, logging each one. Run daily by ev_expire_waitlist.
CREATE PROCEDURE sp_expire_waitlist(IN p_days INT)
BEGIN
  DECLARE l_cutoff DATETIME(6) DEFAULT NOW(6) - INTERVAL p_days DAY;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  INSERT INTO audit_log (action, student_id, section_id, details)
  SELECT 'EXPIRE', student_id, section_id, CONCAT('Waitlist entry older than ', p_days, ' days.')
  FROM waitlist
  WHERE requested_at < l_cutoff;

  DELETE FROM waitlist WHERE requested_at < l_cutoff;
  COMMIT;
END$$


-- Deadlock demo: locks two sections with a pause in between. Two calls with the sections in
-- opposite order each hold one lock and wait for the other's. InnoDB detects the cycle and rolls
-- one transaction back with error 1213 (the "victim"); the other then gets both locks.
CREATE PROCEDURE sp_demo_deadlock(IN p_first_section INT, IN p_second_section INT, IN p_delay DECIMAL(4,1))
BEGIN
  DECLARE l_capacity INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_first_section FOR UPDATE;
  DO SLEEP(p_delay);
  SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_second_section FOR UPDATE;
  COMMIT;
END$$

DELIMITER ;
