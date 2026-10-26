Create Fig. 2.1 from the description below, and place it inside the empty "Fig. 2.1" box in Chapter 2, scaled to fit the text width. Keep the caption below it.

---

Draw an ER diagram in Chen notation on a white background, black lines, readable when printed at
page width. Entities as rectangles, relationships as diamonds, attributes as ovals, key attributes
underlined, cardinality written on each line (1, N, M). Double lines mean total participation.

Entities and attributes:
- DEPARTMENT: <u>dept_id</u>, name
- STUDENT: <u>student_id</u>, name, email, max_credits
- INSTRUCTOR: <u>instructor_id</u>, name
- COURSE: <u>course_id</u>, code, title, credits
- SECTION: <u>section_id</u>, section_code, room, capacity
- MEETING: <u>meeting_id</u>, day, start_time, end_time
- AUDIT_LOG: <u>log_id</u>, action, details, logged_at (draw it apart, connected to nothing)

Relationships:
- DEPARTMENT —1— BELONGS_TO —N— STUDENT (student side total)
- DEPARTMENT —1— EMPLOYS —N— INSTRUCTOR (instructor side total)
- DEPARTMENT —1— OFFERS —N— COURSE (course side total)
- COURSE —1— HAS —N— SECTION (section side total)
- INSTRUCTOR —1— TEACHES —N— SECTION (section side total)
- SECTION —1— MEETS_AT —N— MEETING (meeting side total)
- STUDENT —M— ENROLLS_IN —N— SECTION, relationship attribute: enrolled_at
- STUDENT —M— WAITS_FOR —N— SECTION, relationship attribute: requested_at
- STUDENT —M— COMPLETED —N— COURSE, relationship attribute: grade
- COURSE —M— REQUIRES —N— COURSE (recursive; label the two lines "course" and "prerequisite")
