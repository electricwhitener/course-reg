# Functional dependencies and normalization (report chapter 3)

Facts and worked material for sections 3.1 and 3.2. Write the report text in your own words; this
file only holds the facts to build it from.

## 3.1 Functional dependencies

Notation: `X → Y` means "X determines Y". Every candidate key is listed. Trivial dependencies and
ones implied by the keys are left out.

| Relation | Candidate keys | Functional dependencies |
|---|---|---|
| departments | {dept_id}, {name} | dept_id → name; name → dept_id |
| students | {student_id}, {email} | student_id → name, email, dept_id, max_credits; email → student_id |
| instructors | {instructor_id} | instructor_id → name, dept_id |
| courses | {course_id}, {code} | course_id → code, title, credits, dept_id; code → course_id |
| prerequisites | {course_id, prereq_course_id} | none besides the key (all-key relation) |
| completed_courses | {student_id, course_id} | student_id, course_id → grade |
| sections | {section_id}, {course_id, section_code} | section_id → course_id, instructor_id, section_code, room, capacity; course_id, section_code → section_id |
| section_meetings | {meeting_id} | meeting_id → section_id, day, start_time, end_time |
| enrollments | {student_id, section_id} | student_id, section_id → enrolled_at |
| waitlist | {waitlist_id}, {student_id, section_id} | waitlist_id → student_id, section_id, requested_at; student_id, section_id → waitlist_id |
| audit_log | {log_id} | log_id → action, student_id, section_id, details, logged_at |

**Result:** in every relation, the left side of every non-trivial dependency is a candidate key. So
every relation is in **BCNF**, and therefore also in 3NF.

**Dependencies that were removed on purpose:**
- `section_id → seats_taken`. This value is computable as `COUNT(*)` from `enrollments`. Storing it
  would duplicate data, and a stored counter could drift out of step with the real rows (an update
  anomaly). It is computed on demand in `v_section_seats`.
- `student_id → current_credits`. This is computable with `SUM(credits)` over the student's
  enrollments, and is computed by `fn_current_credits`.
- A student's waitlist position. It comes from the order of `requested_at` (computed by
  `ROW_NUMBER()` in `v_waitlist_positions`), so it's never stored and never needs renumbering when
  someone leaves the queue.

## 3.2 Normalization steps (worked example)

**Starting point (unnormalized):** one flat "registration sheet" with a row per student per
section, the way a spreadsheet might hold it:

`REG(student_id, student_name, email, student_dept, course_code, course_title, credits, course_dept,
section_code, room, instructor_name, instructor_dept, {day, start_time, end_time}, {prereq_codes}, enrolled_at)`

`{...}` marks repeating groups: a section meets several times a week, and a course has several prerequisites.

**1NF: remove repeating groups.** Every attribute must hold one atomic value.
- Move the meetings out to `MEETING(section_key, day, start_time, end_time)`.
- Move the prerequisites out to `PREREQ(course_code, prereq_code)`.
- What's left: `REG1(student_id, course_code, section_code, student_name, email, student_dept,
  course_title, credits, course_dept, room, instructor_name, instructor_dept, enrolled_at)`, with
  key {student_id, course_code, section_code}.

**2NF: remove partial dependencies.** No non-key attribute may depend on only part of the key.
- `student_id → student_name, email, student_dept` depends on part of the key, so it becomes `STUDENT`.
- `course_code → course_title, credits, course_dept` depends on part of the key, so it becomes `COURSE`.
- `course_code, section_code → room, instructor_name, instructor_dept` depends on part of the key, so it becomes `SECTION`.
- What's left: `ENROLLMENT(student_id, course_code, section_code, enrolled_at)`, where `enrolled_at`
  depends on the whole key.

**3NF: remove transitive dependencies.** No non-key attribute may depend on another non-key attribute.
- In `SECTION`, `instructor_name → instructor_dept` is transitive, so it becomes `INSTRUCTOR(instructor_id, name, dept)`.
- In `STUDENT`, `COURSE` and `INSTRUCTOR`, the department name is repeated text, so it becomes
  `DEPARTMENT(dept_id, name)` and the others refer to `dept_id`.
- Surrogate keys (`section_id`, `meeting_id`) replace the long composite keys. The old natural key is
  kept as a `UNIQUE` constraint (`uq_sections_course_code`).

**Final schema:** the 11 tables in `db/01_schema.sql` (see `data-dictionary.md`).

**Anomalies this prevents (good viva examples):**
- *Update anomaly:* in the flat sheet, renaming a course means changing every student's row. Now it's one row in `courses`.
- *Insert anomaly:* in the flat sheet, a new section with no students yet can't be recorded. Now it's a row in `sections`.
- *Delete anomaly:* in the flat sheet, when the last student drops a section, the section's room and
  instructor are lost. Now they stay in `sections`.
