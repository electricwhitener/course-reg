Create Fig. 2.2, a relational schema diagram, and place it inside the empty "Fig. 2.2" box in Chapter 2, scaled to fit the text width. Keep the caption below it.

---

Draw the 11 tables below in crow's-foot notation, in the style of a MySQL Workbench EER diagram: each table is a box with the table name in a header bar and one row per column showing the column name and data type. Mark primary key columns "PK" and foreign key columns "FK". Draw a line from each foreign key to the table it references, with a crow's foot (many) at the foreign-key end and a single bar (one) at the referenced end. Use a white background with black or dark grey lines, make it readable when printed at page width, and arrange the boxes so lines cross as little as possible.

- departments: dept_id INT PK, name VARCHAR(100)
- students: student_id INT PK, name VARCHAR(100), email VARCHAR(255), dept_id INT FK → departments, max_credits TINYINT
- instructors: instructor_id INT PK, name VARCHAR(100), dept_id INT FK → departments
- courses: course_id INT PK, code VARCHAR(10), title VARCHAR(150), credits TINYINT, dept_id INT FK → departments
- prerequisites: course_id INT PK + FK → courses, prereq_course_id INT PK + FK → courses (two separate lines to courses)
- completed_courses: student_id INT PK + FK → students, course_id INT PK + FK → courses, grade VARCHAR(2)
- sections: section_id INT PK, course_id INT FK → courses, instructor_id INT FK → instructors, section_code VARCHAR(5), room VARCHAR(20), capacity INT
- section_meetings: meeting_id INT PK, section_id INT FK → sections, day ENUM, start_time TIME, end_time TIME
- enrollments: student_id INT PK + FK → students, section_id INT PK + FK → sections, enrolled_at DATETIME(6)
- waitlist: waitlist_id INT PK, student_id INT FK → students, section_id INT FK → sections, requested_at DATETIME(6)
- audit_log: log_id INT PK, action ENUM, student_id INT, section_id INT, details VARCHAR(255), logged_at DATETIME(6). Draw no lines to or from audit_log: it deliberately has no foreign keys.
