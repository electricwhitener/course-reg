# How to capture every figure

Screenshots must be real captures from your own screen. Take them with **Win + Shift + S** (Snipping
Tool), then paste each one into Claude Design at its `[Insert Fig …]` marker.

Before taking terminal screenshots, make the terminal **wide and the font large** (Ctrl + plus) so
the text is readable on a printed page.

## Setup (run once per terminal, in WSL)
```bash
cd ~/projects/course-reg
source .venv/bin/activate
export MYSQL_PWD=devpass      # dev password, so mysql doesn't ask every time
bash db/reset.sh              # fresh data before each figure unless told otherwise
```

## Chapter 2

**Fig. 2.1, ER diagram:** paste the Part C prompt from `claude-design-pack.md` into Claude Design.
Check that every relationship and cardinality matches the prompt before using it.

**Fig. 2.2, relational schema diagram: teammate's job** (MySQL Workbench is on their Windows machine):
1. Run `bash db/reset.sh` on their machine so the database is current.
2. Workbench → **Database → Reverse Engineer…** → connection `localhost:3306`, user `coursereg_dev`.
3. Select the schema `course_reg` → Next until Finish.
4. Drag the tables so no lines cross badly. **Arrange → Autolayout** is a good start.
5. **File → Export → Export as PNG**.

## Chapter 5.1: GUI screenshots
Start the app: `flask --app app/app.py run --debug`, then open http://localhost:5000 in the Windows browser.

| Fig. | What to capture |
|---|---|
| 5.1 | The catalog page, full width, with the student menu visible |
| 5.2 | Two messages: as **14. Nikhil Bose** register for **CS302-A** (green "Enrolled"); as **4. Ananya Gupta** register for **CS201-A** (red "Missing prerequisite: CS101."). Messages stay for 4 seconds, so have the Snipping Tool ready. Run `bash db/reset.sh` afterwards |
| 5.3–5.5 | Timetable, admin and Race Arena pages: **teammate**, once those pages exist |

## Chapter 5.2: query output snapshots

**Fig. 5.6, test results:**
```bash
bash db/reset.sh && mysql -u coursereg_dev course_reg -t < db/tests.sql | tail -52
```
This shows the PASS table and "43 | 0". If it's too tall for one capture, take two and put them side by side.

**Fig. 5.7 (a), race without locking:**
```bash
bash db/reset.sh && python demo/race.py
```
**Fig. 5.7 (b), race with locking:** (takes about 40 seconds)
```bash
python demo/race.py --safe --runs 10
```
Capture from the first run to the "10/10 runs" line. If it's too long, capture runs 1–2 and the final line.

**Fig. 5.8, live lock monitor:** uses **two terminals** (do the setup in both).
- Terminal 1: `python demo/race.py --safe --delay 15` (the first student holds the lock for 15 s)
- Terminal 2, within 15 seconds:
  ```bash
  mysql -u coursereg_report course_reg -t -e "SELECT * FROM v_lock_monitor WHERE table_name = 'sections' AND lock_type = 'RECORD'"
  ```
Capture terminal 2. It shows one row `GRANTED` and one `WAITING` with `blocked_by_thread_id` filled in.
This also shows that the read-only report user can watch locks.

**Fig. 5.9, deadlock:**
```bash
bash db/reset.sh && python demo/deadlock.py | grep -E "^Transaction|error:|\*\*\*|lock_mode" | cut -c1-150
```

**Fig. 5.10, isolation levels:** (takes about 30 seconds; the blocked steps wait 3 s each)
```bash
bash db/reset.sh && python demo/isolation.py
```

**Fig. 5.11, EXPLAIN before and after:**
```bash
bash db/reset.sh && mysql -u coursereg_dev course_reg -t < demo/explain_indexes.sql
bash db/reset.sh       # the script adds 100,000 rows, so reset afterwards
```
Capture the "Audit feed BEFORE" and "Audit feed AFTER" blocks (both `EXPLAIN` tables and the
`EXPLAIN ANALYZE` timings). Shrink the font if they're too wide.

**Fig. 5.12, roles:**
```bash
bash db/reset.sh
mysql -u coursereg_student course_reg -e "INSERT INTO enrollments (student_id, section_id) VALUES (1, 5)"
mysql -u coursereg_student course_reg -t -e "CALL sp_register(1, 5, TRUE, 0, FALSE, @s, @m); SELECT @s AS status, @m AS message"
```
The first command is denied (`INSERT command denied`). The second works, through the procedure.
The second command also prints a timeline table first; capture the status row below it.

**Fig. 5.13, course demand ranking:**
```bash
bash db/reset.sh
mysql -u coursereg_dev course_reg -t -e "SELECT dept_name, course_code, course_title, capacity, enrolled, waitlisted, demand, dept_rank FROM v_course_demand ORDER BY dept_name, dept_rank"
```

When you're done: `bash db/reset.sh` to leave the database clean.
