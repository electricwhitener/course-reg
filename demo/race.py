"""Two students race for the last seat of CS302-A, each on their own connection.

    python demo/race.py            # unsafe: no lock, both get in (overbooked)
    python demo/race.py --safe     # FOR UPDATE: one enrolled, one waitlisted
    python demo/race.py --safe --runs 10

Each run first empties the race section, so it can be repeated without a reset.
"""
import argparse
import sys
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
import db  # noqa: E402

SECTION = 5          # CS302-A, capacity 1
STUDENTS = (1, 2)    # Aarav and Diya, both eligible


def register(student_id, safe, delay, results):
    conn = db.get_connection()
    try:
        cur = conn.cursor()
        args = cur.callproc("sp_register", (student_id, SECTION, safe, delay, False, None, None))
        timeline = next(cur.stored_results()).fetchone()
        results[student_id] = (args[5], args[6], timeline)
    finally:
        conn.close()


def race(safe, delay):
    conn = db.get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM waitlist WHERE section_id = %s", (SECTION,))
    cur.execute("DELETE FROM enrollments WHERE section_id = %s", (SECTION,))

    results = {}
    threads = [threading.Thread(target=register, args=(s, safe, delay, results)) for s in STUDENTS]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    cur.execute("SELECT enrolled, capacity, waitlist_len FROM v_section_seats WHERE section_id = %s",
                (SECTION,))
    enrolled, capacity, waiting = cur.fetchone()
    conn.close()

    start = min(r[2][0] for r in results.values())
    for student_id, (status, msg, (t_begin, t_locked, *_rest, t_end)) in sorted(results.items()):
        waited = (t_locked - t_begin).total_seconds()
        finished = (t_end - start).total_seconds()
        print(f"  student {student_id}: {status:<10} waited {waited:4.1f}s for lock, "
              f"done at +{finished:4.1f}s  ({msg})")
    print(f"  result: {enrolled}/{capacity} enrolled, {waiting} waitlisted"
          + ("   <-- OVERBOOKED" if enrolled > capacity else ""))
    return enrolled, waiting


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--safe", action="store_true")
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--runs", type=int, default=1)
    opts = parser.parse_args()

    outcomes = []
    for n in range(1, opts.runs + 1):
        print(f"Run {n} ({'SAFE' if opts.safe else 'UNSAFE'}, delay {opts.delay}s)")
        outcomes.append(race(opts.safe, opts.delay))

    correct = sum(1 for enrolled, waiting in outcomes if (enrolled, waiting) == (1, 1))
    print(f"\n{correct}/{opts.runs} runs ended with exactly 1 enrolled and 1 waitlisted.")


if __name__ == "__main__":
    main()
