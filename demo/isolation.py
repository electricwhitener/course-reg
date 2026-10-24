"""Runs every Isolation Lab scenario at every isolation level and prints what session B saw.
The resulting table goes in the report's isolation-levels section.

    python demo/isolation.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
from isolation import LEVELS, SCENARIOS, IsolationLab  # noqa: E402


def describe(result):
    if result["error"]:
        return "BLOCKED" if "Lock wait timeout" in result["error"] else f"ERROR {result['error']}"
    if result["rows"] is not None:
        return ", ".join(str(v) for row in result["rows"] for v in row.values())
    return "ok"


for key, scenario in SCENARIOS.items():
    print(f"\n== {scenario['title']} ==   ({scenario['expect']})")
    for level in LEVELS:
        lab = IsolationLab(level)
        try:
            outcomes = [describe(lab.step(key, i)) for i in range(len(scenario["steps"]))]
        finally:
            lab.close()
        shown = [f"{s}:{o}" for (s, sql), o in zip(scenario["steps"], outcomes)
                 if sql.startswith(("SELECT", "UPDATE", "INSERT"))]
        print(f"  {level:<17} " + "  |  ".join(shown))
