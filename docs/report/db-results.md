# Database results (raw material for the report)

Measured on WSL2, Ubuntu 24.04, MySQL 8.0.46, starting from a fresh `bash db/reset.sh` each time.
Every result here can be reproduced with the command shown next to it.

## 1. SQL tests (`db/tests.sql`)
`bash db/reset.sh && mysql -u coursereg_dev -p course_reg < db/tests.sql`

**41 passed, 0 failed.** They cover the three functions, every `sp_register` rule (free seat, full
section, duplicate, same course, prerequisite, credit limit, clash), atomicity (`p_fail`), drop and
promotion, the capacity cursor, the waitlist trigger, audit rows, the savepoint cart, waitlist expiry
and the analytics views.

## 2. The race (`demo/race.py`)
| Mode | Command | Result |
|---|---|---|
| Unsafe (plain `SELECT`) | `python demo/race.py` | both students ENROLLED, **2/1 overbooked** |
| Safe (`SELECT ... FOR UPDATE`) | `python demo/race.py --safe --runs 10` | **10/10 runs**: 1 enrolled, 1 waitlisted |

In safe mode, the second transaction waits about 2.0 s for the lock (the length of the first one's
`SLEEP`), then sees the seat is gone and joins the waitlist.

Halfway through a safe race, `SELECT * FROM v_lock_monitor` shows:

| thread_id | table_name | lock_mode | lock_status | lock_data | blocked_by_thread_id |
|---|---|---|---|---|---|
| 160 | sections | X,REC_NOT_GAP | GRANTED | 5 | |
| 159 | sections | X,REC_NOT_GAP | WAITING | 5 | 160 |

`lock_data = 5` is the primary key of the locked row (CS302-A). `REC_NOT_GAP` means a lock on that
one record only, with no gap lock.

## 3. Isolation levels (`demo/isolation.py`)
What session B read at each step. A is the other session. BLOCKED means A's write waited for B's lock
and timed out.

**Dirty read**: A updates capacity to 99 without committing, B reads, A rolls back, B reads again.

| Level | B's 1st read | B's 2nd read |
|---|---|---|
| READ UNCOMMITTED | **99** (dirty) | 4 |
| READ COMMITTED | 4 | 4 |
| REPEATABLE READ | 4 | 4 |
| SERIALIZABLE | 4 | 4 |

**Non-repeatable read**: B reads, A commits an update to 10, B reads again in the same transaction.

| Level | B's 1st read | A's update | B's 2nd read |
|---|---|---|---|
| READ UNCOMMITTED | 4 | ok | **10** (changed) |
| READ COMMITTED | 4 | ok | **10** (changed) |
| REPEATABLE READ | 4 | ok | 4 (snapshot) |
| SERIALIZABLE | 4 | BLOCKED | 4 |

**Phantom read**: B counts a section's enrollments, A inserts one, B counts again (plain read, then `FOR SHARE`).

| Level | B's 1st count | A's insert | B's 2nd count | B's `FOR SHARE` count |
|---|---|---|---|---|
| READ UNCOMMITTED | 0 | ok | **1** (phantom) | 1 |
| READ COMMITTED | 0 | ok | **1** (phantom) | 1 |
| REPEATABLE READ | 0 | ok | 0 (snapshot) | **1** |
| SERIALIZABLE | 0 | BLOCKED | 0 | 0 |

Two InnoDB details worth mentioning:
- Under REPEATABLE READ, plain reads use the transaction's snapshot, so they never see the phantom.
  A locking read (`FOR SHARE` / `FOR UPDATE`) always reads the latest committed data, so it does.
  That is exactly why `sp_register` uses `FOR UPDATE`.
- Under SERIALIZABLE, InnoDB turns plain `SELECT`s inside a transaction into `FOR SHARE` reads. B's
  shared locks block A's write, so the anomaly can't happen at all. (With autocommit, a lone `SELECT`
  is still a non-locking read, which is why SERIALIZABLE looks like REPEATABLE READ in the dirty-read
  case.)

## 4. Deadlock (`demo/deadlock.py`)
Transaction 1 locks section 6 and then 7. Transaction 2 locks 7 and then 6, with a 1 s pause between
the two locks. Each one ends up holding one lock and waiting for the other's, so neither can continue.
InnoDB detects the cycle straight away, rolls one back with **error 1213** ("Deadlock found when
trying to get lock; try restarting transaction"), and the other commits. The victim retries and
succeeds.

Shortened `SHOW ENGINE INNODB STATUS` output (InnoDB numbers the transactions its own way):
```
LATEST DETECTED DEADLOCK
*** (1) TRANSACTION:  ... SELECT capacity INTO l_capacity FROM sections WHERE section_id = p_second_section FOR UPDATE
*** (1) HOLDS THE LOCK(S):             index PRIMARY of table `course_reg`.`sections` lock_mode X locks rec but not gap   (section 7)
*** (1) WAITING FOR THIS LOCK TO BE GRANTED:  ... lock_mode X locks rec but not gap waiting                            (section 6)
*** (2) TRANSACTION:  ... same statement
*** (2) HOLDS THE LOCK(S):             ... lock_mode X locks rec but not gap                                         (section 6)
*** (2) WAITING FOR THIS LOCK TO BE GRANTED:  ... lock_mode X locks rec but not gap waiting                            (section 7)
*** WE ROLL BACK TRANSACTION (2)
```
**Prevention:** `sp_register_cart` locks its sections in `section_id` order. If every transaction
takes its locks in the same order, a waiting cycle can't form.

## 5. Indexes and EXPLAIN (`demo/explain_indexes.sql`)
`bash db/reset.sh && mysql -u coursereg_dev -p course_reg -t < demo/explain_indexes.sql`

**Clash detection** (the join inside `fn_has_clash`), index `idx_section_meetings_day_start (day, start_time)`:

| | table `old_m` access | key | rows examined |
|---|---|---|---|
| Before | `ALL` (full table scan) | none | 24 (every meeting in the week) |
| After | `ref` (index lookup on `day`) | `idx_section_meetings_day_start` | 4 (only that day's meetings) |

**Admin audit feed** (`SELECT * FROM audit_log ORDER BY logged_at DESC LIMIT 20`) on 100,000 rows,
index `idx_audit_log_logged_at (logged_at)`:

| | Plan | Rows read | Actual time |
|---|---|---|---|
| Before | `ALL` + `Using filesort` (read and sort everything) | 100,029 | **22.6 ms** |
| After | `index`, `Backward index scan` (read the 20 newest from the B+ tree) | 20 | **0.04 ms** |

The index already keeps the rows sorted by `logged_at`, so MySQL reads the last 20 entries and stops.
Nothing needs sorting.

The other indexes are the primary keys, the `UNIQUE` constraints, and the indexes InnoDB creates
automatically for each foreign key. `idx_waitlist_section_requested (section_id, requested_at)` finds
who is first in line. It can't be dropped for a before/after test, because the `fk_waitlist_section`
foreign key needs an index that starts with `section_id`.
