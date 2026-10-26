"""Two transactions lock sections 6 and 7 in opposite order. MySQL detects the deadlock, rolls one
back (error 1213), and that one retries. Prints the InnoDB deadlock report for the project report.

    python demo/deadlock.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
import registration  # noqa: E402

result = registration.run_deadlock(6, 7, delay=1.0)
for n, t in enumerate(result["transactions"], 1):
    outcome = "VICTIM, rolled back, then retried OK" if t["victim"] else "committed"
    print(f"Transaction {n}: locks section {t['locks'][0]} then {t['locks'][1]} -> {outcome}")
    if t["error"]:
        print(f"    error: {t['error']}")
print("\n" + (result["innodb_report"] or "No deadlock recorded."))
