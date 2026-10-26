-- 07_seed.sql: demo data. IDs are explicit so the demo scenarios below stay stable.
--
-- Demo scenarios ready after a reset:
--   Race:          CS302-A (section 5) has 1 seat and is empty. Aarav (1) and Diya (2) both qualify.
--   Clash:         Kabir (3) is in MA102-A (8). PH101-A (10) overlaps it on MON/WED 15:00-15:30.
--   Prerequisite:  Ananya (4) has completed nothing, so CS201 (needs CS101) is rejected.
--   Credit limit:  Vihaan (5) has max_credits 8 and 7 enrolled, so any 2+ credit course is rejected.
--   Drop promote:  PH201-A (12) is full (2/2). Arjun (8) and Meera (9) are waitlisted, in that order.
--   Cursor:        MA102-B (14) is full (3/3) with 3 waitlisted, so raising capacity promotes them.
--   Back-to-back:  CS101-A ends MON 10:00 and CS201-A starts MON 10:00. Touching is not a clash.

INSERT INTO departments (dept_id, name) VALUES
  (1, 'Computer Science'),
  (2, 'Mathematics'),
  (3, 'Physics');

INSERT INTO instructors (instructor_id, name, dept_id) VALUES
  (1, 'Dr. Anil Mehta',   1),
  (2, 'Dr. Kavita Rao',   1),
  (3, 'Dr. Suresh Iyer',  2),
  (4, 'Dr. Neha Kapoor',  2),
  (5, 'Dr. Rajiv Menon',  3),
  (6, 'Dr. Pooja Verma',  3);

INSERT INTO courses (course_id, code, title, credits, dept_id) VALUES
  (1,  'CS101', 'Introduction to Programming', 4, 1),
  (2,  'CS201', 'Data Structures',             4, 1),
  (3,  'CS301', 'Algorithms',                  4, 1),
  (4,  'CS302', 'Database Systems',            4, 1),
  (5,  'MA101', 'Calculus I',                  4, 2),
  (6,  'MA102', 'Calculus II',                 4, 2),
  (7,  'MA201', 'Discrete Mathematics',        3, 2),
  (8,  'PH101', 'Physics I',                   4, 3),
  (9,  'PH102', 'Physics II',                  4, 3),
  (10, 'PH201', 'Electronics Lab',             2, 3);

-- (course, requires): CS101 -> CS201 -> CS301 (+ MA201), CS201 -> CS302, MA101 -> MA102 / MA201 / PH102
INSERT INTO prerequisites (course_id, prereq_course_id) VALUES
  (2, 1),
  (3, 2), (3, 7),
  (4, 2),
  (6, 5),
  (7, 5),
  (9, 8), (9, 5),
  (10, 8);

INSERT INTO students (student_id, name, email, dept_id, max_credits) VALUES
  (1,  'Aarav Sharma',     'aarav.sharma@muj.manipal.edu',     1, 20),
  (2,  'Diya Patel',       'diya.patel@muj.manipal.edu',       1, 20),
  (3,  'Kabir Singh',      'kabir.singh@muj.manipal.edu',      1, 20),
  (4,  'Ananya Gupta',     'ananya.gupta@muj.manipal.edu',     2, 20),
  (5,  'Vihaan Reddy',     'vihaan.reddy@muj.manipal.edu',     1, 8),
  (6,  'Ishaan Nair',      'ishaan.nair@muj.manipal.edu',      3, 20),
  (7,  'Saanvi Joshi',     'saanvi.joshi@muj.manipal.edu',     3, 20),
  (8,  'Arjun Malhotra',   'arjun.malhotra@muj.manipal.edu',   3, 20),
  (9,  'Meera Iyer',       'meera.iyer@muj.manipal.edu',       2, 20),
  (10, 'Rohan Das',        'rohan.das@muj.manipal.edu',        2, 20),
  (11, 'Tara Menon',       'tara.menon@muj.manipal.edu',       2, 20),
  (12, 'Advik Kulkarni',   'advik.kulkarni@muj.manipal.edu',   1, 20),
  (13, 'Zara Khan',        'zara.khan@muj.manipal.edu',        2, 20),
  (14, 'Nikhil Bose',      'nikhil.bose@muj.manipal.edu',      3, 20),
  (15, 'Priya Chatterjee', 'priya.chatterjee@muj.manipal.edu', 1, 20);

-- Only passed courses are stored, so a row here means the prerequisite is met.
INSERT INTO completed_courses (student_id, course_id, grade) VALUES
  (1, 1, 'A'),  (1, 5, 'B+'), (1, 8, 'A-'), (1, 2, 'A'),
  (2, 1, 'A-'), (2, 5, 'A'),  (2, 8, 'B'),  (2, 2, 'B+'),
  (3, 1, 'B'),  (3, 5, 'B+'),
  (5, 1, 'B+'), (5, 5, 'B'),
  (6, 8, 'A'),  (6, 5, 'B+'),
  (7, 8, 'B+'), (7, 5, 'A-'),
  (8, 8, 'B'),
  (9, 5, 'A'),  (9, 8, 'A-'),
  (10, 5, 'B'),
  (11, 5, 'A-'),
  (12, 1, 'A'), (12, 5, 'B'),
  (13, 5, 'B+'),
  (14, 5, 'C');

INSERT INTO sections (section_id, course_id, instructor_id, section_code, room, capacity) VALUES
  (1,  1,  1, 'A', 'AB1-101', 4),
  (2,  1,  2, 'B', 'AB1-102', 3),
  (3,  2,  1, 'A', 'AB1-201', 3),
  (4,  3,  2, 'A', 'AB1-202', 4),
  (5,  4,  2, 'A', 'AB1-301', 1),   -- race demo
  (6,  5,  3, 'A', 'AB2-101', 4),
  (7,  5,  4, 'B', 'AB2-102', 3),
  (8,  6,  3, 'A', 'AB2-201', 3),
  (9,  7,  4, 'A', 'AB2-202', 5),
  (10, 8,  5, 'A', 'AB3-101', 4),
  (11, 9,  6, 'A', 'AB3-201', 3),
  (12, 10, 6, 'A', 'AB3-LAB', 2),   -- drop-promotion demo
  (13, 2,  2, 'B', 'AB1-203', 4),
  (14, 6,  4, 'B', 'AB2-203', 3);   -- cursor demo

-- Only MA102-A (8) and PH101-A (10) overlap. Every other pair of sections is clash-free.
INSERT INTO section_meetings (section_id, day, start_time, end_time) VALUES
  (1,  'MON', '09:00', '10:00'), (1,  'WED', '09:00', '10:00'),
  (2,  'TUE', '09:00', '10:00'), (2,  'THU', '09:00', '10:00'),
  (3,  'MON', '10:00', '11:00'), (3,  'WED', '10:00', '11:00'),
  (4,  'TUE', '11:00', '12:30'), (4,  'THU', '11:00', '12:30'),
  (5,  'FRI', '09:00', '11:00'),
  (6,  'MON', '11:00', '12:00'), (6,  'WED', '11:00', '12:00'),
  (7,  'TUE', '14:00', '15:00'), (7,  'THU', '14:00', '15:00'),
  (8,  'MON', '14:00', '15:30'), (8,  'WED', '14:00', '15:30'),
  (9,  'TUE', '10:00', '11:00'), (9,  'THU', '10:00', '11:00'),
  (10, 'MON', '15:00', '16:30'), (10, 'WED', '15:00', '16:30'),
  (11, 'FRI', '14:00', '15:30'),
  (12, 'FRI', '11:30', '13:30'),
  (13, 'TUE', '15:00', '16:00'), (13, 'THU', '15:00', '16:00'),
  (14, 'SAT', '10:00', '11:30');

-- Explicit timestamps: rows in one INSERT would otherwise all get the same CURRENT_TIMESTAMP.
INSERT INTO enrollments (student_id, section_id, enrolled_at) VALUES
  (1,  9,  '2026-10-12 09:05:00'),
  (2,  9,  '2026-10-12 09:20:00'),
  (3,  8,  '2026-10-12 10:00:00'), (3, 3, '2026-10-12 10:02:00'),
  (4,  1,  '2026-10-12 11:15:00'), (4, 6, '2026-10-12 11:18:00'),
  (5,  3,  '2026-10-13 09:00:00'), (5, 9, '2026-10-13 09:03:00'),
  (6,  12, '2026-10-13 10:30:00'), (6, 11, '2026-10-13 10:31:00'),
  (7,  12, '2026-10-13 10:45:00'), (7, 8, '2026-10-13 10:47:00'),
  (8,  7,  '2026-10-14 14:00:00'),
  (9,  14, '2026-10-14 15:10:00'), (9, 2, '2026-10-14 15:12:00'),
  (10, 14, '2026-10-14 15:30:00'), (10, 9, '2026-10-14 15:32:00'),
  (11, 14, '2026-10-15 08:50:00'), (11, 1, '2026-10-15 08:52:00'),
  (12, 13, '2026-10-15 12:00:00'),
  (13, 10, '2026-10-16 09:40:00'),
  (14, 10, '2026-10-16 09:55:00'),
  (15, 2,  '2026-10-16 16:20:00'), (15, 7, '2026-10-16 16:22:00');

-- Order of requested_at = order of promotion (first come, first served).
INSERT INTO waitlist (student_id, section_id, requested_at) VALUES
  (8,  12, '2026-10-14 14:05:00'),
  (9,  12, '2026-10-14 15:15:00'),
  (12, 14, '2026-10-15 12:05:00'),
  (13, 14, '2026-10-16 09:45:00'),
  (14, 14, '2026-10-16 10:00:00');
