Add Chapter 3 below, starting on a new page after Chapter 2. Follow the layout rules from my first message. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

---

## 3. Database Normalization

### 3.1 Functional Dependencies

Table 3.1 lists the candidate keys and the non-trivial functional dependencies of each relation.

**Table 3.1: Functional dependencies and candidate keys**

| Relation | Candidate keys | Functional dependencies |
|---|---|---|
| departments | {dept_id}, {name} | dept_id → name; name → dept_id |
| students | {student_id}, {email} | student_id → name, email, dept_id, max_credits; email → student_id |
| instructors | {instructor_id} | instructor_id → name, dept_id |
| courses | {course_id}, {code} | course_id → code, title, credits, dept_id; code → course_id |
| prerequisites | {course_id, prereq_course_id} | none (all-key relation) |
| completed_courses | {student_id, course_id} | student_id, course_id → grade |
| sections | {section_id}, {course_id, section_code} | section_id → course_id, instructor_id, section_code, room, capacity; course_id, section_code → section_id |
| section_meetings | {meeting_id} | meeting_id → section_id, day, start_time, end_time |
| enrollments | {student_id, section_id} | student_id, section_id → enrolled_at |
| waitlist | {waitlist_id}, {student_id, section_id} | waitlist_id → student_id, section_id, requested_at; student_id, section_id → waitlist_id |
| audit_log | {log_id} | log_id → action, student_id, section_id, details, logged_at |

In every relation, the left side of every non-trivial dependency is a candidate key, so all eleven
relations are in Boyce-Codd normal form, and therefore also in 3NF.

### 3.2 Normalization Steps

We started from a single flat "registration sheet", the kind of table a spreadsheet would hold, with
one row per student per section:

REG(student_id, student_name, email, student_dept, course_code, course_title, credits, course_dept,
section_code, room, instructor_name, instructor_dept, {day, start_time, end_time}, {prereq_codes},
enrolled_at)

The braces mark repeating groups: a section meets several times a week and a course can have several
prerequisites. Table 3.2 shows how the sheet was decomposed [7].

**Table 3.2: Normalization stages**

| Stage | Problem removed | Result |
|---|---|---|
| UNF → 1NF | Repeating groups (several meetings per section, several prerequisites per course) | Meetings and prerequisites moved to their own relations; every cell holds one value. Key of the rest: {student_id, course_code, section_code} |
| 1NF → 2NF | Partial dependencies: student_id → student details; course_code → course details; (course_code, section_code) → room, instructor | STUDENT, COURSE and SECTION split out. ENROLLMENT(student_id, section, enrolled_at) keeps only what depends on the whole key |
| 2NF → 3NF | Transitive dependencies: instructor_name → instructor_dept; department names repeated as text | INSTRUCTOR and DEPARTMENT split out; other relations refer to them by id |
| 3NF → BCNF check | Every determinant must be a candidate key | Already satisfied (Table 3.1). Surrogate keys added for sections and meetings, with the natural key kept as a UNIQUE constraint |

The decomposition removes the three classic anomalies. Renaming a course now changes one row in
`courses` instead of every enrolled student's row (update anomaly). A new section can be stored before
anyone joins it (insert anomaly). When the last student drops a section, its room and instructor are
not lost (delete anomaly).

One design decision follows directly from normalization: **the number of seats taken is never
stored.** It can be derived as `COUNT(*)` from `enrollments`, so storing it would duplicate data that
could drift out of step. The same applies to a student's current credits and waitlist position, which
are computed when needed.
