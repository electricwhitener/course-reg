"""Generates docs/report/data-dictionary.md (report section 2.3) from information_schema, so it always
matches the real schema.

    python docs/report/data_dictionary.py > docs/report/data-dictionary.md
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "app"))
import db

DESC = {
 "departments": ("Academic departments.", {"dept_id": "Department identifier", "name": "Department name"}),
 "students": ("Students who register for sections.", {"student_id": "Student identifier", "name": "Full name", "email": "College e-mail address", "dept_id": "Home department", "max_credits": "Most credits the student may take per semester"}),
 "instructors": ("Teaching staff.", {"instructor_id": "Instructor identifier", "name": "Full name", "dept_id": "Department the instructor belongs to"}),
 "courses": ("Courses in the catalogue.", {"course_id": "Course identifier", "code": "Course code, e.g. CS101", "title": "Course title", "credits": "Credit value (1 to 6)", "dept_id": "Department offering the course"}),
 "prerequisites": ("Course requires another course (self-referencing many-to-many).", {"course_id": "Course that has the prerequisite", "prereq_course_id": "Course that must be completed first"}),
 "completed_courses": ("Courses a student has already passed.", {"student_id": "Student", "course_id": "Course passed", "grade": "Letter grade, e.g. A, B+"}),
 "sections": ("A teaching group of a course with its own instructor, room and seat limit. The row locked by FOR UPDATE.", {"section_id": "Section identifier", "course_id": "Course taught", "instructor_id": "Instructor teaching it", "section_code": "Section letter within the course (A, B, ...)", "room": "Classroom", "capacity": "Number of seats"}),
 "section_meetings": ("Weekly class times of each section.", {"meeting_id": "Meeting identifier", "section_id": "Section that meets", "day": "Day of the week", "start_time": "Start time", "end_time": "End time"}),
 "enrollments": ("A student holds a seat in a section. Seats taken = COUNT(*) per section.", {"student_id": "Enrolled student", "section_id": "Section", "enrolled_at": "When the seat was taken"}),
 "waitlist": ("Students waiting for a seat in a full section, first come first served.", {"waitlist_id": "Waitlist entry identifier", "student_id": "Waiting student", "section_id": "Section waited for", "requested_at": "When the student joined the waitlist (decides the order)"}),
 "audit_log": ("History of every registration event, written by triggers and procedures. No foreign keys, so history survives deletions.", {"log_id": "Log entry identifier", "action": "ENROLL, DROP, WAITLIST, PROMOTE, REJECT or EXPIRE", "student_id": "Student involved", "section_id": "Section involved", "details": "Reason or message", "logged_at": "When it happened"}),
}

cols = db.query("""SELECT table_name AS table_name, column_name AS column_name, column_type AS column_type,
                          is_nullable AS is_nullable, column_default AS column_default, extra AS extra
                   FROM information_schema.columns WHERE table_schema = 'course_reg'
                   ORDER BY 1, ordinal_position""")
keys = db.query("""SELECT k.table_name AS table_name, k.column_name AS column_name, c.constraint_type AS constraint_type,
                          k.constraint_name AS constraint_name, k.ordinal_position AS ordinal_position,
                          k.referenced_table_name AS referenced_table_name, k.referenced_column_name AS referenced_column_name
                   FROM information_schema.key_column_usage k
                   JOIN information_schema.table_constraints c
                     ON c.constraint_schema = k.constraint_schema AND c.table_name = k.table_name
                    AND c.constraint_name = k.constraint_name
                   WHERE k.table_schema = 'course_reg'""")
checks = db.query("""SELECT tc.table_name AS table_name, cc.constraint_name AS constraint_name, cc.check_clause AS check_clause
                     FROM information_schema.check_constraints cc
                     JOIN information_schema.table_constraints tc
                       ON tc.constraint_schema = cc.constraint_schema AND tc.constraint_name = cc.constraint_name
                     WHERE cc.constraint_schema = 'course_reg'""")

def key_columns(table, name):
    return [k["column_name"] for k in sorted(keys, key=lambda k: k["ordinal_position"])
            if k["table_name"] == table and k["constraint_name"] == name]

def key_text(table, col):
    out = []
    for k in keys:
        if k["table_name"] == table and k["column_name"] == col:
            part = "part of " if len(key_columns(table, k["constraint_name"])) > 1 else ""
            if k["constraint_type"] == "PRIMARY KEY": out.append(part + "PK")
            elif k["constraint_type"] == "UNIQUE": out.append(part + "UNIQUE")
            elif k["constraint_type"] == "FOREIGN KEY": out.append(f"FK → {k['referenced_table_name']}.{k['referenced_column_name']}")
    return ", ".join(dict.fromkeys(out))

def composite_keys(table):
    seen = {}
    for k in keys:
        if k["table_name"] == table and k["constraint_type"] in ("PRIMARY KEY", "UNIQUE"):
            seen[k["constraint_name"]] = k["constraint_type"]
    out = []
    for name, kind in seen.items():
        cols_ = key_columns(table, name)
        if len(cols_) > 1:
            label = "PRIMARY KEY" if kind == "PRIMARY KEY" else f"UNIQUE `{name}`"
            out.append(f"{label} ({', '.join(cols_)})")
    return out

print("# Data dictionary (report section 2.3)\n")
print("Generated from MySQL's `information_schema`, so it matches `db/01_schema.sql` exactly. "
      "Regenerate it if the schema changes: `python docs/report/data_dictionary.py > docs/report/data-dictionary.md`.\n")
n = 0
for table in DESC:
    n += 1
    print(f"## Table 2.{n}: `{table}`\n")
    print(DESC[table][0] + "\n")
    print("| Column | Data type | Null? | Key | Default | Description |")
    print("|---|---|---|---|---|---|")
    for c in cols:
        if c["table_name"] != table: continue
        default = c["column_default"] or ""
        if "auto_increment" in c["extra"]: default = "AUTO_INCREMENT"
        print(f"| `{c['column_name']}` | {c['column_type'].upper()} | {'Yes' if c['is_nullable'] == 'YES' else 'No'} "
              f"| {key_text(table, c['column_name'])} | {default} | {DESC[table][1][c['column_name']]} |")
    comp = composite_keys(table)
    if comp:
        print("\nComposite keys: " + "; ".join(comp))
    tchecks = [ch for ch in checks if ch["table_name"] == table]
    if tchecks:
        print("\nCheck constraints: " + "; ".join(f"`{ch['constraint_name']}`: `{ch['check_clause'].replace('`', '')}`" for ch in tchecks))
    print()
