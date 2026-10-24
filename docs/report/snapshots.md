# Screenshot guide

Every `[Insert Fig. …]` box in the report needs a real screenshot from your own screen. This guide
covers how to take them, which ones to take, and how to put them into Claude Design.

**Where they go:** save every screenshot in `C:\Users\amulb\Downloads\course-reg-report\screenshots\`,
named after its figure (`fig-5-06.png`, `fig-5-07a.png`, …).

## A. How to take a screenshot (Windows Snipping Tool)
1. Get the screen ready, so the output you want is visible.
2. Press **Win + Shift + S**. The screen dims and freezes, so take your time.
3. Drag a rectangle around exactly what you want.
4. A small notification "Snip copied to clipboard" pops up at the bottom right. **Click it.**
   The Snipping Tool opens with your picture.
5. Press **Ctrl + S**, go to `Downloads\course-reg-report\screenshots`, type the file name
   (e.g. `fig-5-06`) and click **Save**.

If you miss the notification, Windows 11 usually also saves the snip in `Pictures\Screenshots`.

## B. Get the terminal ready (do this once, before the terminal screenshots)
In VS Code:
1. Press **Ctrl + B** to hide the file sidebar, so the terminal is as wide as possible.
2. Press **Ctrl + `** to open the terminal. Click the **^** (Maximize Panel Size) button at the
   top-right of the terminal panel so it fills the window.
3. Run these four lines. They're needed in every new terminal:
   ```bash
   cd ~/projects/course-reg
   source .venv/bin/activate
   export MYSQL_PWD=devpass
   bash db/reset.sh
   ```
   The last line should print `Reset complete: course_reg`.
4. Before each figure, type `clear` and press Enter, so the screenshot shows only that output.

**Readability:** if a table's lines wrap onto the next line and look broken, press **Ctrl + −** to
zoom VS Code out until each line fits. If the text is small but fits, that's fine; it's sharper in
print than it looks.

## C. Terminal screenshots (you can do all of these now)

### Fig. 5.6: SQL test results → `fig-5-06.png`
```bash
clear
bash db/reset.sh && mysql -u coursereg_dev course_reg -t < db/tests.sql | tail -52
```
**You should see:** a table of 43 rows that all say `PASS`, then a small table `passed 43 | failed 0`.
**Capture:** from the `test_no | result | name` header down to the `43 | 0` table. If it doesn't fit
on screen, zoom out (Ctrl + −). If it still doesn't fit, take two screenshots (`fig-5-06a`,
`fig-5-06b`): rows 1–22, then rows 23–43 with the totals.

### Fig. 5.7 (a): race without locking → `fig-5-07a.png`
```bash
clear
bash db/reset.sh && python demo/race.py
```
**You should see:** both students `ENROLLED`, then `result: 2/1 enrolled ... <-- OVERBOOKED`.
**Capture:** everything from `Run 1 (UNSAFE…` to the last line.

### Fig. 5.7 (b): race with locking → `fig-5-07b.png`
```bash
clear
python demo/race.py --safe --runs 10 | tail -10
```
**Wait about 40 seconds**; nothing appears until it finishes.
**You should see:** runs 9 and 10, each with one student `ENROLLED` and one `WAITLISTED` (the second
one `waited 2.0s for lock`), then `10/10 runs ended with exactly 1 enrolled and 1 waitlisted.`
**Capture:** all of it.

### Fig. 5.8: live lock monitor → `fig-5-08.png`
This needs **two terminals side by side**, because the lock only exists while the race is running.

1. In your terminal, run `bash db/reset.sh`.
2. Split the terminal: press **Ctrl + Shift + 5**, or click the split icon (two boxes side by side)
   at the top right of the terminal panel. A second terminal opens on the right.
3. Click in the **right** terminal and run `export MYSQL_PWD=devpass`, then `clear`.
4. Still in the right terminal, paste this command but **don't press Enter yet**:
   ```bash
   mysql -u coursereg_report course_reg -t -e "SELECT * FROM v_lock_monitor WHERE table_name = 'sections' AND lock_type = 'RECORD'"
   ```
5. Click in the **left** terminal, run `clear`, then run:
   ```bash
   python demo/race.py --safe --delay 15
   ```
   It prints `Run 1 (SAFE, delay 15.0s)` and then seems to hang. That's the race in progress.
6. **Within 15 seconds**, click in the right terminal and press **Enter**.

**You should see three rows:**
- `X,REC_NOT_GAP | GRANTED | 5`: the first student holds the exclusive lock on section 5 (CS302-A).
- `X,REC_NOT_GAP | WAITING | 5`: the second student is waiting for that same lock. Its
  `blocked_by_thread_id` equals the first row's `thread_id`.
- `S,REC_NOT_GAP | GRANTED | 9`: a shared lock on section 9 (MA201-A), taken when the procedure read
  the student's other class during the rule checks. It's normal; leave it in the screenshot.

**Capture:** in the right terminal, the command line and the table under it.

**If there's no `WAITING` row**, you pressed Enter after the first 15 seconds, when the second student
already had the lock. The left terminal finishes after about 30 seconds in total. When it does, repeat
from step 5. There's no need to reset, because each race clears the section first.

Afterwards, close the right terminal (trash-can icon) and run `bash db/reset.sh` in the left one.

### Fig. 5.9: deadlock → `fig-5-09.png`
```bash
clear
bash db/reset.sh && python demo/deadlock.py | grep -E "^Transaction|error:|\*\*\*|lock_mode" | cut -c1-150
```
**You should see:** "Transaction 1 … VICTIM, rolled back, then retried OK", the error "Deadlock found
when trying to get lock", "Transaction 2 … committed", then InnoDB's report lines ending in
`*** WE ROLL BACK TRANSACTION`.
**Capture:** all of it.

### Fig. 5.10: isolation levels → `fig-5-10.png`
```bash
clear
bash db/reset.sh && python demo/isolation.py
```
**Wait about 30 seconds.** The two `BLOCKED` steps each wait 3 seconds on purpose.
**You should see:** three blocks (Dirty read, Non-repeatable read, Phantom read), each with four rows
for the four isolation levels.
**Capture:** all three blocks. Take two screenshots if needed (`fig-5-10a`, `fig-5-10b`).

### Fig. 5.11: EXPLAIN before and after → `fig-5-11.png`
```bash
clear
bash db/reset.sh && mysql -u coursereg_dev course_reg -t < demo/explain_indexes.sql
```
**Scroll up** to the box that says `Audit feed BEFORE idx_audit_log_logged_at`.
**Capture:** from that box down to the end. Before: `ALL … Using filesort`, and `actual time=` figures in the tens of milliseconds (for example
45.6). After: `Backward index scan`, and `actual time=` figures below 0.1. The times change from
run to run, so make sure Table 4.3 and the Conclusion quote the numbers in **your** screenshot. Take two screenshots if it doesn't fit (`fig-5-11a` = BEFORE,
`fig-5-11b` = AFTER).

**Then run `bash db/reset.sh`**, because this script adds 100,000 test rows.

### Fig. 5.12: roles → `fig-5-12.png`
```bash
clear
bash db/reset.sh
mysql -u coursereg_student course_reg -e "INSERT INTO enrollments (student_id, section_id) VALUES (1, 5)"
mysql -u coursereg_student course_reg -t -e "CALL sp_register(1, 5, TRUE, 0, FALSE, @s, @m); SELECT @s AS status, @m AS message"
```
**You should see:** first `ERROR 1142 … INSERT command denied to user 'coursereg_student'`, then (after
a small table of timestamps) `ENROLLED | Enrolled in CS302-A.`
**Capture:** the commands and both outputs. It shows the student account can't touch tables directly
but can register through the procedure.

### Fig. 5.13: demand ranking → `fig-5-13.png`
```bash
clear
bash db/reset.sh
mysql -u coursereg_dev course_reg -t -e "SELECT dept_name, course_code, course_title, capacity, enrolled, waitlisted, demand, dept_rank FROM v_course_demand ORDER BY dept_name, dept_rank"
```
**You should see:** 10 courses grouped by department, with ranks restarting at 1 for each department.
MA102 is rank 1 in Mathematics, and CS301 and CS302 share rank 3.
**Capture:** the whole table.

## D. Web page screenshots (you can do 5.1 and 5.2 now)
1. In the terminal: `bash db/reset.sh`, then `flask --app app/app.py run --debug`.
2. Open **http://localhost:5000** in your Windows browser. Press **Ctrl + −** once or twice so more
   cards fit on screen.

### Fig. 5.1: catalog → `fig-5-01.png`
**Capture:** the navigation bar (with "Login as") and the first two or three rows of section cards.

### Fig. 5.2 (a): success message → `fig-5-02a.png`
1. In **Login as**, choose **1. Aarav Sharma**.
2. Find the **CS302-A** card (Database Systems) and click **Register**.
3. **Immediately** press **Win + Shift + S**. The message disappears after 4 seconds, but the screen
   freezes the moment you press the keys.
4. Capture the green message "Enrolled in CS302-A." together with the CS302-A card, whose bar is now red (full).

### Fig. 5.2 (b): rejection message → `fig-5-02b.png`
1. Choose **4. Ananya Gupta** in **Login as**.
2. On the **CS201-A** card (Data Structures), click **Register**, then immediately **Win + Shift + S**.
3. Capture the red message "Missing prerequisite: CS101."

Then press **Ctrl + C** in the terminal to stop the server, and run `bash db/reset.sh`.

## E. Figures from other places
| Fig. | How |
|---|---|
| 2.1 ER diagram | Claude Design draws it from `claude-design/09-er-diagram.md` |
| 2.2 Schema diagram | Claude Design draws it from `claude-design/10-schema-diagram.md`. If Bhavya later exports one from MySQL Workbench (**Database → Reverse Engineer**, then **File → Export → Export as PNG**), you can swap it in |
| 5.3 Timetable, 5.4 Admin, 5.5 Race Arena | Bhavya's pages: capture them once they exist, the same way as 5.1 |

## F. Putting a screenshot into Claude Design
Attach the image file (the paperclip / attach button, or drag the file into the message box), and send:

> Put the attached image into the empty box for Fig. 5.6. Scale it to fit inside the page margins,
> keep its proportions, and keep the caption below it.

For a figure made of two screenshots (5.2, 5.7, or any you split in two), attach both and send:

> Put these two images into the box for Fig. 5.7, side by side if they fit, otherwise one above the
> other, labelled (a) and (b) under each image. Keep the caption below.
