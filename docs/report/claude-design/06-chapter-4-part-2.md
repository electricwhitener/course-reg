Continue Chapter 4 with section 4.5 below, directly after section 4.4 (no new page needed). Put every SQL code block in Courier New 10 pt inside a light grey box. Follow the layout rules from my first message. Text in backticks is code: show it in Courier New 11 pt without the backticks, as in the abstract. Use the text below exactly as written: do not rewrite, shorten, summarise or add anything. Keep every table complete, with its caption above it. Render each "[Insert Fig. X.Y]" line as an empty light-grey box, full text width and about 7 cm tall, with the figure caption centred on the line below it. I will add the images later.

---

### 4.5 PL/SQL Components

PL/SQL is Oracle's procedural language. MySQL's equivalent is *stored programs*: stored procedures,
stored functions, triggers and events, written in SQL/PSM [9]. Table 4.4 lists the ones in this
project.

**Table 4.4: Stored programs**

| Object | Type | What it does | Concepts shown |
|---|---|---|---|
| `sp_register` | Procedure | One complete registration as a single transaction | Transactions, locking, handlers, SIGNAL |
| `sp_drop` | Procedure | Drop a seat and promote the first eligible waitlisted student | Transactions, `ORDER BY … LIMIT 1 FOR UPDATE` |
| `sp_set_capacity` | Procedure | Change capacity; a cursor promotes students into new seats | Cursor, loop, CONTINUE handler |
| `sp_register_cart` | Procedure | Register for several sections; failures undo only their own part | SAVEPOINT, `JSON_TABLE` |
| `sp_expire_waitlist` | Procedure | Remove waitlist entries older than N days | INSERT … SELECT, transaction |
| `sp_demo_deadlock` | Procedure | Lock two sections in a given order (deadlock demo) | Deadlock detection |
| `fn_registration_error` | Function | Returns the first rule a registration breaks, or NULL | Shared business rules |
| `fn_has_clash` | Function | Timetable clash check | EXISTS, interval overlap |
| `fn_prereqs_met` | Function | Prerequisite check | NOT EXISTS (division) |
| `fn_current_credits` | Function | Credits currently enrolled | Aggregate |
| `trg_enrollments_after_insert` / `_after_delete` | Triggers | Write ENROLL, PROMOTE or DROP to the audit log | AFTER triggers |
| `trg_waitlist_before_insert` | Trigger | Block waitlisting for a course already taken | BEFORE trigger, SIGNAL |
| `trg_waitlist_after_insert` | Trigger | Write WAITLIST to the audit log | AFTER trigger |
| `ev_expire_waitlist` | Event | Runs `sp_expire_waitlist(30)` every night | Event scheduler [10] |

**The registration transaction.** `sp_register` takes the student, the section and three demo
switches (safe mode, a delay, and a simulated failure), and returns a status of ENROLLED, WAITLISTED
or REJECTED with a message. Its steps are:

1. Start a transaction and lock the section row with `SELECT … FOR UPDATE` (safe mode).
2. Check the rules through `fn_registration_error`. If one fails, roll back, log a REJECT row and
   return the reason, for example "Missing prerequisite: CS101."
3. Count the enrolled students. If a seat is free, insert into `enrollments`; otherwise insert into
   `waitlist`.
4. Commit. Any SQL error on the way triggers the exit handler, which rolls everything back, logs the
   error and re-raises it.

```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
  GET DIAGNOSTICS CONDITION 1 l_error = MESSAGE_TEXT;
  ROLLBACK;
  INSERT INTO audit_log (action, student_id, section_id, details)
  VALUES ('REJECT', p_student_id, p_section_id, CONCAT('Rolled back: ', l_error));
  RESIGNAL;
END;

START TRANSACTION;
IF p_safe THEN
  SELECT capacity INTO l_capacity FROM sections
  WHERE section_id = p_section_id FOR UPDATE;      -- exclusive row lock
ELSE
  SELECT capacity INTO l_capacity FROM sections
  WHERE section_id = p_section_id;                 -- no lock (demo only)
END IF;
```

**Why locking is needed.** InnoDB runs at REPEATABLE READ by default, and a plain `SELECT` reads from
a snapshot without locking [11]. Table 4.5 shows what happens when two students, A and B, both ask for
the last seat of CS302-A without a lock. The 2-second delay only widens the window so the problem
shows every time.

**Table 4.5: Schedule without locking (lost update)**

| Time | Transaction A (student 1) | Transaction B (student 2) |
|---|---|---|
| t1 | START TRANSACTION; read section (no lock) | |
| t2 | COUNT enrolled = 0 → seat free | START TRANSACTION; read section (no lock) |
| t3 | sleeping | COUNT enrolled = 0 → seat free |
| t4 | INSERT enrollment; COMMIT | sleeping |
| t5 | | INSERT enrollment; COMMIT |
| Result | **2 students in a 1-seat section** | |

With `FOR UPDATE`, the first transaction takes an exclusive (X) lock on the section row. The second
must wait for that lock, and when it gets it, its reads see the committed insert [12]:

**Table 4.6: Schedule with FOR UPDATE**

| Time | Transaction A (student 1) | Transaction B (student 2) |
|---|---|---|
| t1 | START; `SELECT … FOR UPDATE` → X lock on section 5 | |
| t2 | COUNT enrolled = 0 → seat free | START; `SELECT … FOR UPDATE` → **waits** |
| t3 | INSERT enrollment; COMMIT → lock released | waiting (about 2 s) |
| t4 | | lock granted; COUNT enrolled = 1 → full |
| t5 | | INSERT into waitlist; COMMIT |
| Result | **1 enrolled, 1 waitlisted** | |

The locking read must be the first read in the transaction. Under REPEATABLE READ the snapshot is
fixed at the first plain read, and a snapshot taken before the lock would miss A's insert. The live
lock monitor (Fig. 5.8) reads `performance_schema.data_locks` through the view `v_lock_monitor` and
shows the waiting lock while the race runs. Its third row, a shared (S) lock on section 9, comes from the
first transaction reading the student's other class (MA201-A) during its rule checks.

**Isolation levels.** We ran three scripted experiments with two sessions at each of the four
isolation levels (Table 4.7).

**Table 4.7: Isolation levels and observed anomalies**

| Isolation level | Dirty read | Non-repeatable read | Phantom (plain read) |
|---|---|---|---|
| READ UNCOMMITTED | Occurred (read 99 before rollback) | Occurred (4 → 10) | Occurred (0 → 1) |
| READ COMMITTED | Prevented | Occurred (4 → 10) | Occurred (0 → 1) |
| REPEATABLE READ | Prevented | Prevented (snapshot) | Prevented for plain reads; a `FOR SHARE` read saw the new row |
| SERIALIZABLE | Prevented | Prevented (writer blocked) | Prevented (writer blocked) |

**Deadlock.** When two transactions lock sections 6 and 7 in opposite order, each holds one lock and
waits for the other. InnoDB detects the cycle at once and rolls one transaction back with error 1213;
the other then completes [13]. In our test, the victim retried and succeeded (Fig. 5.9).
`sp_register_cart` avoids this by always locking sections in `section_id` order.

**Cursor.** When an admin raises a section's capacity, `sp_set_capacity` walks the waitlist in request
order with a cursor and promotes each student who still fits, until the new seats are used up:

```sql
DECLARE cur_waitlist CURSOR FOR
  SELECT student_id FROM waitlist WHERE section_id = p_section_id ORDER BY requested_at;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET l_done = TRUE;
...
OPEN cur_waitlist;
promote_loop: LOOP
  FETCH cur_waitlist INTO l_student;
  IF l_done OR l_enrolled >= p_new_capacity THEN LEAVE promote_loop; END IF;
  IF NOT fn_has_clash(l_student, p_section_id) THEN   -- credit check omitted here
    INSERT INTO enrollments (student_id, section_id) VALUES (l_student, p_section_id);
    DELETE FROM waitlist WHERE student_id = l_student AND section_id = p_section_id;
    SET l_enrolled = l_enrolled + 1;
  END IF;
END LOOP;
CLOSE cur_waitlist;
```

**Triggers and savepoints.** The audit log is written only by triggers, so no code path can forget
it. An audit row written by a trigger belongs to the same transaction, so a rollback removes it too.
`sp_register_cart` sets a `SAVEPOINT` before each section in a multi-section request. If one section
fails, `ROLLBACK TO SAVEPOINT` undoes only that section and the rest of the cart is still committed.

**Roles (DCL).** Three roles follow the principle of least privilege [14] (Table 4.8). Procedures run
with their definer's rights, so `app_student` can call `sp_register` without any privilege on the
tables it writes to.

**Table 4.8: Role privileges**

| Role (login user) | Can do | Cannot do |
|---|---|---|
| `app_student` (`coursereg_student`) | EXECUTE `sp_register`, `sp_drop`, `sp_register_cart`; SELECT on three views | Read or write any table directly |
| `app_report` (`coursereg_report`) | SELECT on every table and view | Any write |
| `app_admin` (`coursereg_admin`) | Everything both roles above can do, plus EXECUTE `sp_set_capacity` | Change the schema |

```sql
CREATE ROLE app_student, app_admin, app_report;
GRANT EXECUTE ON PROCEDURE course_reg.sp_register TO app_student;
GRANT SELECT ON course_reg.* TO app_report;
GRANT app_student, app_report TO app_admin;   -- a role can hold other roles
```
