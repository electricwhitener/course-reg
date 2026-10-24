Add Chapter 5 below, starting on a new page after Chapter 4. Follow the layout rules from my first message. Text in backticks is code: show it in Courier New 11 pt without the backticks, as in the abstract. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

---

## 5. System Interface

### 5.1 GUI Screenshots

The interface is a Flask web application with Bootstrap pages. Flask is kept thin: each page calls a
JSON route, and each route either reads a view or calls a stored procedure through a small Python
wrapper. No registration rule is written in Python, so the database gives the same answers whether
it is used from the web page, the command line or MySQL Workbench. A "Login as" menu in the navigation
bar switches between the 15 seeded students (there is no real authentication).

[Insert Fig. 5.1]

**Fig. 5.1: Course catalog page with live seat bars**

[Insert Fig. 5.2]

**Fig. 5.2: Registration messages returned by MySQL: (a) successful enrollment, (b) missing prerequisite**

[Insert Fig. 5.3]

**Fig. 5.3: Student weekly timetable**

[Insert Fig. 5.4]

**Fig. 5.4: Admin page with capacity change and audit log**

[Insert Fig. 5.5]

**Fig. 5.5: Race Arena showing the timelines of both transactions**

### 5.2 Query Output Snapshots

The SQL test script checks every rule against the seed data and prints PASS or FAIL for each case.
All 43 tests passed (Table 5.1, Fig. 5.6).

**Table 5.1: Test case summary**

| Group | Tests | Examples |
|---|---|---|
| Stored functions | 6 | Overlapping classes clash; back-to-back classes do not |
| Views | 5 | MA102 ranks first in Mathematics; waitlist positions 1, 2, 3 |
| Registration rules | 10 | Free seat → ENROLLED; full → WAITLISTED; clash, prerequisite and credit limit → REJECTED with no rows inserted |
| Atomicity | 3 | Simulated failure after insert → insert rolled back, audited |
| Drop and promotion | 5 | First waitlisted student promoted; dropping when not registered → error |
| Capacity change (cursor) | 5 | Capacity 3 → 5 promotes the first two in order |
| Triggers | 2 | Waitlisting an enrolled course is blocked; audit rows written |
| Cart (savepoints) | 4 | Failed section rolled back to its savepoint, others kept |
| Waitlist expiry (event) | 3 | Only the 40-day-old entry removed; event enabled |
| **Total** | **43** | **43 passed, 0 failed** |

[Insert Fig. 5.6]

**Fig. 5.6: SQL test results (43 passed, 0 failed)**

[Insert Fig. 5.7]

**Fig. 5.7: Race for the last seat: (a) without locking, 2/1 overbooked; (b) with FOR UPDATE, correct in 10 of 10 runs**

[Insert Fig. 5.8]

**Fig. 5.8: Live lock monitor during a safe race: one X lock granted, one waiting**

[Insert Fig. 5.9]

**Fig. 5.9: Deadlock detected by InnoDB (error 1213)**

[Insert Fig. 5.10]

**Fig. 5.10: Isolation level experiment output**

[Insert Fig. 5.11]

**Fig. 5.11: EXPLAIN output before and after adding the audit-log index**

[Insert Fig. 5.12]

**Fig. 5.12: Role-based access control: direct INSERT denied, procedure call allowed**

[Insert Fig. 5.13]

**Fig. 5.13: Course demand ranking using RANK() OVER (PARTITION BY department)**
