-- 01_schema.sql: tables, keys and constraints (3NF).
-- Seats taken is never stored: it is always COUNT(*) from enrollments.

CREATE TABLE departments (
  dept_id INT AUTO_INCREMENT PRIMARY KEY,
  name    VARCHAR(100) NOT NULL,
  CONSTRAINT uq_departments_name UNIQUE (name)
);

CREATE TABLE students (
  student_id  INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(255) NOT NULL,
  dept_id     INT NOT NULL,
  max_credits TINYINT NOT NULL DEFAULT 20,
  CONSTRAINT uq_students_email UNIQUE (email),
  CONSTRAINT chk_students_max_credits CHECK (max_credits > 0),
  CONSTRAINT fk_students_department FOREIGN KEY (dept_id) REFERENCES departments (dept_id)
);

CREATE TABLE instructors (
  instructor_id INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  dept_id       INT NOT NULL,
  CONSTRAINT fk_instructors_department FOREIGN KEY (dept_id) REFERENCES departments (dept_id)
);

CREATE TABLE courses (
  course_id INT AUTO_INCREMENT PRIMARY KEY,
  code      VARCHAR(10) NOT NULL,
  title     VARCHAR(150) NOT NULL,
  credits   TINYINT NOT NULL,
  dept_id   INT NOT NULL,
  CONSTRAINT uq_courses_code UNIQUE (code),
  CONSTRAINT chk_courses_credits CHECK (credits BETWEEN 1 AND 6),
  CONSTRAINT fk_courses_department FOREIGN KEY (dept_id) REFERENCES departments (dept_id)
);

-- Self-referencing many-to-many: course_id requires prereq_course_id.
CREATE TABLE prerequisites (
  course_id        INT NOT NULL,
  prereq_course_id INT NOT NULL,
  PRIMARY KEY (course_id, prereq_course_id),
  CONSTRAINT chk_prerequisites_not_self CHECK (course_id <> prereq_course_id),
  CONSTRAINT fk_prerequisites_course FOREIGN KEY (course_id) REFERENCES courses (course_id),
  CONSTRAINT fk_prerequisites_prereq FOREIGN KEY (prereq_course_id) REFERENCES courses (course_id)
);

CREATE TABLE completed_courses (
  student_id INT NOT NULL,
  course_id  INT NOT NULL,
  grade      VARCHAR(2) NOT NULL,
  PRIMARY KEY (student_id, course_id),
  CONSTRAINT fk_completed_courses_student FOREIGN KEY (student_id) REFERENCES students (student_id),
  CONSTRAINT fk_completed_courses_course FOREIGN KEY (course_id) REFERENCES courses (course_id)
);

-- The sections row is what sp_register locks with SELECT ... FOR UPDATE.
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

CREATE TABLE section_meetings (
  meeting_id INT AUTO_INCREMENT PRIMARY KEY,
  section_id INT NOT NULL,
  day        ENUM('MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT') NOT NULL,
  start_time TIME NOT NULL,
  end_time   TIME NOT NULL,
  CONSTRAINT chk_section_meetings_times CHECK (start_time < end_time),
  CONSTRAINT fk_section_meetings_section FOREIGN KEY (section_id) REFERENCES sections (section_id),
  INDEX idx_section_meetings_day_start (day, start_time)
);

CREATE TABLE enrollments (
  student_id  INT NOT NULL,
  section_id  INT NOT NULL,
  enrolled_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (student_id, section_id),
  CONSTRAINT fk_enrollments_student FOREIGN KEY (student_id) REFERENCES students (student_id),
  CONSTRAINT fk_enrollments_section FOREIGN KEY (section_id) REFERENCES sections (section_id)
);

CREATE TABLE waitlist (
  waitlist_id  INT AUTO_INCREMENT PRIMARY KEY,
  student_id   INT NOT NULL,
  section_id   INT NOT NULL,
  requested_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_waitlist_student_section UNIQUE (student_id, section_id),
  CONSTRAINT fk_waitlist_student FOREIGN KEY (student_id) REFERENCES students (student_id),
  CONSTRAINT fk_waitlist_section FOREIGN KEY (section_id) REFERENCES sections (section_id),
  INDEX idx_waitlist_section_requested (section_id, requested_at)  -- finds who is first in line
);

-- No foreign keys on purpose: the log must keep its history even if a student or section is removed.
CREATE TABLE audit_log (
  log_id     INT AUTO_INCREMENT PRIMARY KEY,
  action     ENUM('ENROLL', 'DROP', 'WAITLIST', 'PROMOTE', 'REJECT', 'EXPIRE') NOT NULL,
  student_id INT,
  section_id INT,
  details    VARCHAR(255),
  logged_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  INDEX idx_audit_log_logged_at (logged_at)
);
