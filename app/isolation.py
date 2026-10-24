"""Isolation Lab: two sessions (A and B) step through a scripted scenario at a chosen isolation
level, so you can watch an anomaly appear at one level and disappear at another.

    lab = IsolationLab("READ COMMITTED")
    for i in range(len(SCENARIOS["non_repeatable_read"]["steps"])):
        print(lab.step("non_repeatable_read", i))
    lab.close()

Each session holds one persistent connection, so a lab only works in a single process (the Flask
dev server). Scenarios use section 4 (CS301-A, empty after a reset) and put it back at the end.
"""
import time

import mysql.connector

import db

LEVELS = ("READ UNCOMMITTED", "READ COMMITTED", "REPEATABLE READ", "SERIALIZABLE")
LOCK_WAIT_SECONDS = 3   # a blocked step gives up after this long instead of hanging the page

READ_CAPACITY = "SELECT capacity FROM sections WHERE section_id = 4"
COUNT_ENROLLED = "SELECT COUNT(*) AS enrolled FROM enrollments WHERE section_id = 4"

SCENARIOS = {
    "dirty_read": {
        "title": "Dirty read",
        "expect": "B sees A's uncommitted 99 only under READ UNCOMMITTED.",
        "steps": [
            ("A", "START TRANSACTION"),
            ("A", "UPDATE sections SET capacity = 99 WHERE section_id = 4"),
            ("B", READ_CAPACITY),
            ("A", "ROLLBACK"),
            ("B", READ_CAPACITY),
        ],
    },
    "non_repeatable_read": {
        "title": "Non-repeatable read",
        "expect": "B's second read changes under READ UNCOMMITTED and READ COMMITTED. "
                  "REPEATABLE READ keeps its snapshot. SERIALIZABLE blocks A's update instead.",
        "steps": [
            ("B", "START TRANSACTION"),
            ("B", READ_CAPACITY),
            ("A", "UPDATE sections SET capacity = 10 WHERE section_id = 4"),
            ("B", READ_CAPACITY),
            ("B", "COMMIT"),
            ("A", "UPDATE sections SET capacity = 4 WHERE section_id = 4"),
        ],
    },
    "phantom": {
        "title": "Phantom read",
        "expect": "A new row appears in B's count under READ UNCOMMITTED and READ COMMITTED. "
                  "REPEATABLE READ hides it from plain reads, but a locking read (FOR SHARE) sees it. "
                  "SERIALIZABLE blocks A's insert instead.",
        "steps": [
            ("B", "START TRANSACTION"),
            ("B", COUNT_ENROLLED),
            ("A", "INSERT INTO enrollments (student_id, section_id) VALUES (3, 4)"),
            ("B", COUNT_ENROLLED),
            ("B", COUNT_ENROLLED + " FOR SHARE"),
            ("B", "COMMIT"),
            ("A", "DELETE FROM enrollments WHERE student_id = 3 AND section_id = 4"),
        ],
    },
}


class IsolationLab:
    def __init__(self, level):
        if level not in LEVELS:   # SQL keywords can't be bound as parameters, so allowlist them
            raise ValueError(f"Unknown isolation level: {level}")
        self.level = level
        self.sessions = {}
        for name in ("A", "B"):
            conn = db.get_connection()
            cur = conn.cursor()
            cur.execute(f"SET SESSION TRANSACTION ISOLATION LEVEL {level}")
            cur.execute("SET SESSION innodb_lock_wait_timeout = %s", (LOCK_WAIT_SECONDS,))
            self.sessions[name] = conn

    def step(self, scenario, index):
        """Runs one step. Returns {session, sql, rows, rowcount, error, ms}."""
        session, sql = SCENARIOS[scenario]["steps"][index]
        result = {"session": session, "sql": sql, "rows": None, "rowcount": None, "error": None}
        cur = self.sessions[session].cursor(dictionary=True)
        started = time.perf_counter()
        try:
            cur.execute(sql)
            if cur.with_rows:
                result["rows"] = cur.fetchall()
            else:
                result["rowcount"] = cur.rowcount
        except mysql.connector.Error as err:
            result["error"] = err.msg     # e.g. lock wait timeout: the step was blocked
        result["ms"] = round((time.perf_counter() - started) * 1000)
        return result

    def close(self):
        for conn in self.sessions.values():
            conn.rollback()
            conn.close()
