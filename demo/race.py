"""Two students race for the last seat of CS302-A, each on their own connection.

    python demo/race.py            # unsafe: no lock, both get in (overbooked)
    python demo/race.py --safe     # FOR UPDATE: one enrolled, one waitlisted
    python demo/race.py --safe --runs 10

Each run first empties the race section, so it can be repeated without a reset.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
import db  # noqa: E402
import registration  # noqa: E402

SECTION = 5          # CS302-A, capacity 1
STUDENTS = [1, 2]    # Aarav and Diya, both eligible


def race(safe, delay):
    registration.clear_section(SECTION)
    results = registration.run_race(SECTION, STUDENTS, safe, delay)
    seats = db.query("SELECT enrolled, capacity, waitlist_len FROM v_section_seats WHERE section_id = %s",
                     (SECTION,))[0]

    start = min(r["timeline"]["t_begin"] for r in results)
    for r in results:
        t = r["timeline"]
        waited = (t["t_locked"] - t["t_begin"]).total_seconds()
        finished = (t["t_end"] - start).total_seconds()
        print(f"  student {r['student_id']}: {r['status']:<10} waited {waited:4.1f}s for lock, "
              f"done at +{finished:4.1f}s  ({r['msg']})")
    overbooked = seats["enrolled"] > seats["capacity"]
    print(f"  result: {seats['enrolled']}/{seats['capacity']} enrolled, {seats['waitlist_len']} waitlisted"
          + ("   <-- OVERBOOKED" if overbooked else ""))
    return seats["enrolled"], seats["waitlist_len"]


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
