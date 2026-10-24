Add Chapter 2 below, starting on a new page after Chapter 1. Underline the words between <u> and </u> instead of showing the tags. Follow the layout rules from my first message. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

---

## 2. Database Design & Modeling

### 2.1 Entity-Relationship (ER) Diagram

The design has eight entities. A **Department** offers courses and employs instructors, and every
student belongs to one department. A **Course** (for example CS302, Database Systems) is the subject;
a **Section** is one actual class of that course with its own instructor, room and seat capacity, so
one course can have several sections. Each section meets at one or more weekly **Meeting** times.
Students register for sections, not courses, because seats and times belong to sections.

Three relationships between students and the rest are many-to-many: a student *enrolls in* many
sections and a section has many students; a student *waits for* sections that are full; and a student
has *completed* many courses, with a grade. Courses are also related to themselves: a course
*requires* other courses as prerequisites. The **Audit Log** records events about students and
sections but is deliberately not tied to them by foreign keys, so its history survives deletions.

[Insert Fig. 2.1]

**Fig. 2.1: ER diagram of the course registration system**

### 2.2 Relational Schema / Mapping

The ER diagram was mapped to relations using the standard rules of the relational model [6]. Strong
entities became tables with a surrogate primary key. Each one-to-many relationship became a foreign
key on the "many" side. Each many-to-many relationship became its own table whose key combines the
two participating keys. The weekly meeting times, a multi-valued attribute of a section, became a
separate table.

**Table 2.1: Mapping of ER constructs to relations**

| ER construct | Type | Relation(s) |
|---|---|---|
| Department, Student, Instructor, Course, Section | Strong entities | `departments`, `students`, `instructors`, `courses`, `sections` |
| Department–Student, Department–Instructor, Department–Course | 1 : N | foreign key `dept_id` in `students`, `instructors`, `courses` |
| Course–Section, Instructor–Section | 1 : N | foreign keys `course_id`, `instructor_id` in `sections` |
| Section meets at times | Multi-valued attribute | `section_meetings(section_id, day, start_time, end_time)` |
| Student enrolls in Section | M : N with attribute | `enrollments(student_id, section_id, enrolled_at)` |
| Student waits for Section | M : N with attribute | `waitlist(student_id, section_id, requested_at)` |
| Student completed Course | M : N with attribute | `completed_courses(student_id, course_id, grade)` |
| Course requires Course | Recursive M : N | `prerequisites(course_id, prereq_course_id)` |
| Audit Log | Independent entity | `audit_log` (no foreign keys) |

The resulting schema (primary keys underlined, foreign keys marked *):

- DEPARTMENTS(<u>dept_id</u>, name)
- STUDENTS(<u>student_id</u>, name, email, dept_id*, max_credits)
- INSTRUCTORS(<u>instructor_id</u>, name, dept_id*)
- COURSES(<u>course_id</u>, code, title, credits, dept_id*)
- PREREQUISITES(<u>course_id*, prereq_course_id*</u>)
- COMPLETED_COURSES(<u>student_id*, course_id*</u>, grade)
- SECTIONS(<u>section_id</u>, course_id*, instructor_id*, section_code, room, capacity)
- SECTION_MEETINGS(<u>meeting_id</u>, section_id*, day, start_time, end_time)
- ENROLLMENTS(<u>student_id*, section_id*</u>, enrolled_at)
- WAITLIST(<u>waitlist_id</u>, student_id*, section_id*, requested_at)
- AUDIT_LOG(<u>log_id</u>, action, student_id, section_id, details, logged_at)

[Insert Fig. 2.2]

**Fig. 2.2: Relational schema diagram**

### 2.3 Data Dictionary

Table 2.2 lists every column. All constraints are named in the DDL (for example
`chk_courses_credits`), so an error message from MySQL names the exact rule that failed.

**Table 2.2: Data dictionary**

| Table | Column | Data type | Constraints | Description |
|---|---|---|---|---|
| departments | dept_id | INT | PK; AUTO_INCREMENT | Department identifier |
|  | name | VARCHAR(100) | UNIQUE; NOT NULL | Department name |
| students | student_id | INT | PK; AUTO_INCREMENT | Student identifier |
|  | name | VARCHAR(100) | NOT NULL | Full name |
|  | email | VARCHAR(255) | UNIQUE; NOT NULL | College e-mail address |
|  | dept_id | INT | FK → departments.dept_id; NOT NULL | Home department |
|  | max_credits | TINYINT | NOT NULL; DEFAULT 20; CHECK (max_credits > 0) | Most credits the student may take per semester |
| instructors | instructor_id | INT | PK; AUTO_INCREMENT | Instructor identifier |
|  | name | VARCHAR(100) | NOT NULL | Full name |
|  | dept_id | INT | FK → departments.dept_id; NOT NULL | Department the instructor belongs to |
| courses | course_id | INT | PK; AUTO_INCREMENT | Course identifier |
|  | code | VARCHAR(10) | UNIQUE; NOT NULL | Course code, e.g. CS101 |
|  | title | VARCHAR(150) | NOT NULL | Course title |
|  | credits | TINYINT | NOT NULL; CHECK (credits between 1 and 6) | Credit value (1 to 6) |
|  | dept_id | INT | FK → departments.dept_id; NOT NULL | Department offering the course |
| prerequisites | course_id | INT | part of PK, FK → courses.course_id; CHECK (course_id <> prereq_course_id) | Course that has the prerequisite |
|  | prereq_course_id | INT | part of PK, FK → courses.course_id; CHECK (course_id <> prereq_course_id) | Course that must be completed first |
| completed_courses | student_id | INT | part of PK, FK → students.student_id | Student |
|  | course_id | INT | part of PK, FK → courses.course_id | Course passed |
|  | grade | VARCHAR(2) | NOT NULL | Letter grade, e.g. A, B+ |
| sections | section_id | INT | PK; AUTO_INCREMENT | Section identifier |
|  | course_id | INT | part of UNIQUE, FK → courses.course_id; NOT NULL | Course taught |
|  | instructor_id | INT | FK → instructors.instructor_id; NOT NULL | Instructor teaching it |
|  | section_code | VARCHAR(5) | part of UNIQUE; NOT NULL | Section letter within the course (A, B, ...) |
|  | room | VARCHAR(20) | NOT NULL | Classroom |
|  | capacity | INT | NOT NULL; CHECK (capacity > 0) | Number of seats |
| section_meetings | meeting_id | INT | PK; AUTO_INCREMENT | Meeting identifier |
|  | section_id | INT | FK → sections.section_id; NOT NULL | Section that meets |
|  | day | ENUM('MON','TUE','WED','THU','FRI','SAT') | NOT NULL | Day of the week |
|  | start_time | TIME | NOT NULL; CHECK (start_time < end_time) | Start time |
|  | end_time | TIME | NOT NULL; CHECK (start_time < end_time) | End time |
| enrollments | student_id | INT | part of PK, FK → students.student_id | Enrolled student |
|  | section_id | INT | part of PK, FK → sections.section_id | Section |
|  | enrolled_at | DATETIME(6) | NOT NULL; DEFAULT CURRENT_TIMESTAMP(6) | When the seat was taken |
| waitlist | waitlist_id | INT | PK; AUTO_INCREMENT | Waitlist entry identifier |
|  | student_id | INT | part of UNIQUE, FK → students.student_id; NOT NULL | Waiting student |
|  | section_id | INT | part of UNIQUE, FK → sections.section_id; NOT NULL | Section waited for |
|  | requested_at | DATETIME(6) | NOT NULL; DEFAULT CURRENT_TIMESTAMP(6) | When the student joined the waitlist (decides the order) |
| audit_log | log_id | INT | PK; AUTO_INCREMENT | Log entry identifier |
|  | action | ENUM('ENROLL','DROP','WAITLIST','PROMOTE','REJECT','EXPIRE') | NOT NULL | ENROLL, DROP, WAITLIST, PROMOTE, REJECT or EXPIRE |
|  | student_id | INT |  | Student involved |
|  | section_id | INT |  | Section involved |
|  | details | VARCHAR(255) |  | Reason or message |
|  | logged_at | DATETIME(6) | NOT NULL; DEFAULT CURRENT_TIMESTAMP(6) | When it happened |
