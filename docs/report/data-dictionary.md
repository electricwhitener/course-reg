# Data dictionary (report section 2.3)

Generated from MySQL's `information_schema`, so it matches `db/01_schema.sql` exactly. Regenerate it if the schema changes: `python docs/report/data_dictionary.py > docs/report/data-dictionary.md`.

## Table 2.1: `departments`

Academic departments.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `dept_id` | INT | No | PK | AUTO_INCREMENT | Department identifier |
| `name` | VARCHAR(100) | No | UNIQUE |  | Department name |

## Table 2.2: `students`

Students who register for sections.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `student_id` | INT | No | PK | AUTO_INCREMENT | Student identifier |
| `name` | VARCHAR(100) | No |  |  | Full name |
| `email` | VARCHAR(255) | No | UNIQUE |  | College e-mail address |
| `dept_id` | INT | No | FK → departments.dept_id |  | Home department |
| `max_credits` | TINYINT | No |  | 20 | Most credits the student may take per semester |

Check constraints: `chk_students_max_credits`: `(max_credits > 0)`

## Table 2.3: `instructors`

Teaching staff.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `instructor_id` | INT | No | PK | AUTO_INCREMENT | Instructor identifier |
| `name` | VARCHAR(100) | No |  |  | Full name |
| `dept_id` | INT | No | FK → departments.dept_id |  | Department the instructor belongs to |

## Table 2.4: `courses`

Courses in the catalogue.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `course_id` | INT | No | PK | AUTO_INCREMENT | Course identifier |
| `code` | VARCHAR(10) | No | UNIQUE |  | Course code, e.g. CS101 |
| `title` | VARCHAR(150) | No |  |  | Course title |
| `credits` | TINYINT | No |  |  | Credit value (1 to 6) |
| `dept_id` | INT | No | FK → departments.dept_id |  | Department offering the course |

Check constraints: `chk_courses_credits`: `(credits between 1 and 6)`

## Table 2.5: `prerequisites`

Course requires another course (self-referencing many-to-many).

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `course_id` | INT | No | part of PK, FK → courses.course_id |  | Course that has the prerequisite |
| `prereq_course_id` | INT | No | part of PK, FK → courses.course_id |  | Course that must be completed first |

Composite keys: PRIMARY KEY (course_id, prereq_course_id)

Check constraints: `chk_prerequisites_not_self`: `(course_id <> prereq_course_id)`

## Table 2.6: `completed_courses`

Courses a student has already passed.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `student_id` | INT | No | part of PK, FK → students.student_id |  | Student |
| `course_id` | INT | No | part of PK, FK → courses.course_id |  | Course passed |
| `grade` | VARCHAR(2) | No |  |  | Letter grade, e.g. A, B+ |

Composite keys: PRIMARY KEY (student_id, course_id)

## Table 2.7: `sections`

A teaching group of a course with its own instructor, room and seat limit. The row locked by FOR UPDATE.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `section_id` | INT | No | PK | AUTO_INCREMENT | Section identifier |
| `course_id` | INT | No | part of UNIQUE, FK → courses.course_id |  | Course taught |
| `instructor_id` | INT | No | FK → instructors.instructor_id |  | Instructor teaching it |
| `section_code` | VARCHAR(5) | No | part of UNIQUE |  | Section letter within the course (A, B, ...) |
| `room` | VARCHAR(20) | No |  |  | Classroom |
| `capacity` | INT | No |  |  | Number of seats |

Composite keys: UNIQUE `uq_sections_course_code` (course_id, section_code)

Check constraints: `chk_sections_capacity`: `(capacity > 0)`

## Table 2.8: `section_meetings`

Weekly class times of each section.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `meeting_id` | INT | No | PK | AUTO_INCREMENT | Meeting identifier |
| `section_id` | INT | No | FK → sections.section_id |  | Section that meets |
| `day` | ENUM('MON','TUE','WED','THU','FRI','SAT') | No |  |  | Day of the week |
| `start_time` | TIME | No |  |  | Start time |
| `end_time` | TIME | No |  |  | End time |

Check constraints: `chk_section_meetings_times`: `(start_time < end_time)`

## Table 2.9: `enrollments`

A student holds a seat in a section. Seats taken = COUNT(*) per section.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `student_id` | INT | No | part of PK, FK → students.student_id |  | Enrolled student |
| `section_id` | INT | No | part of PK, FK → sections.section_id |  | Section |
| `enrolled_at` | DATETIME(6) | No |  | CURRENT_TIMESTAMP(6) | When the seat was taken |

Composite keys: PRIMARY KEY (student_id, section_id)

## Table 2.10: `waitlist`

Students waiting for a seat in a full section, first come first served.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `waitlist_id` | INT | No | PK | AUTO_INCREMENT | Waitlist entry identifier |
| `student_id` | INT | No | part of UNIQUE, FK → students.student_id |  | Waiting student |
| `section_id` | INT | No | part of UNIQUE, FK → sections.section_id |  | Section waited for |
| `requested_at` | DATETIME(6) | No |  | CURRENT_TIMESTAMP(6) | When the student joined the waitlist (decides the order) |

Composite keys: UNIQUE `uq_waitlist_student_section` (student_id, section_id)

## Table 2.11: `audit_log`

History of every registration event, written by triggers and procedures. No foreign keys, so history survives deletions.

| Column | Data type | Null? | Key | Default | Description |
|---|---|---|---|---|---|
| `log_id` | INT | No | PK | AUTO_INCREMENT | Log entry identifier |
| `action` | ENUM('ENROLL','DROP','WAITLIST','PROMOTE','REJECT','EXPIRE') | No |  |  | ENROLL, DROP, WAITLIST, PROMOTE, REJECT or EXPIRE |
| `student_id` | INT | Yes |  |  | Student involved |
| `section_id` | INT | Yes |  |  | Section involved |
| `details` | VARCHAR(255) | Yes |  |  | Reason or message |
| `logged_at` | DATETIME(6) | No |  | CURRENT_TIMESTAMP(6) | When it happened |

