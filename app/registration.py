"""Python wrappers around the stored procedures (see the procedure contract in CLAUDE.md).

The rules all live in MySQL: these functions only call procedures and reshape the results into
dicts that routes can pass to a template or jsonify(). Business-rule rejections come back as
status REJECTED. Real errors (including the simulated failure) raise mysql.connector.Error, and
err.msg is the message to show.
"""
import json
import threading

import mysql.connector

import db

ER_LOCK_DEADLOCK = 1213

# Connection id -> student id for the race in progress, so lock_snapshot() can say whose lock is
# whose. Module state: fine for the single-process Flask dev server this project runs on.
_race_connections = {}


def register(student_id, section_id, safe=True, delay=0, fail=False, conn=None):
    """Returns {student_id, section_id, status, msg, timeline}. timeline holds the step timestamps
    t_begin, t_locked, t_counted, t_written, t_end (None for steps that didn't happen)."""
    out, result_sets = db.call("sp_register", (student_id, section_id, safe, delay, fail, None, None), conn)
    return {"student_id": student_id, "section_id": section_id,
            "status": out[5], "msg": out[6], "timeline": result_sets[0][0]}


def register_cart(student_id, section_ids, fail_section=None):
    """Registers for several sections in one transaction (one savepoint each).
    Returns a list of {section_id, status, msg}, one per section."""
    out, _ = db.call("sp_register_cart", (student_id, json.dumps(section_ids), fail_section, None))
    return json.loads(out[3])


def drop(student_id, section_id):
    """Drops an enrollment (promoting the next waitlisted student) or leaves a waitlist."""
    db.call("sp_drop", (student_id, section_id))


def set_capacity(section_id, new_capacity):
    """Changes capacity; waitlisted students are promoted into any new seats."""
    db.call("sp_set_capacity", (section_id, new_capacity))


# Race Arena ------------------------------------------------------------------------------------

def run_race(section_id, student_ids, safe, delay=2.0):
    """Registers every student for the same section at the same moment, each on its own connection,
    and waits for all of them. Returns one register() dict per student, plus connection_id. A call
    that raised gets status ERROR and the error message instead."""
    conns = [db.get_connection() for _ in student_ids]
    results = [None] * len(student_ids)

    def worker(i):
        try:
            results[i] = register(student_ids[i], section_id, safe, delay, conn=conns[i])
        except mysql.connector.Error as err:
            results[i] = {"student_id": student_ids[i], "section_id": section_id,
                          "status": "ERROR", "msg": err.msg, "timeline": None}
        results[i]["connection_id"] = conns[i].connection_id

    try:
        for conn, student_id in zip(conns, student_ids):
            _race_connections[conn.connection_id] = student_id
        threads = [threading.Thread(target=worker, args=(i,)) for i in range(len(student_ids))]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
    finally:
        _race_connections.clear()
        for conn in conns:
            conn.close()
    return results


def lock_snapshot():
    """Current row locks in the database (v_lock_monitor), each labelled with the racing student
    that holds or waits for it. Poll this while run_race() is running."""
    rows = db.query("SELECT * FROM v_lock_monitor WHERE lock_type = 'RECORD' ORDER BY thread_id")
    for row in rows:
        row["student_id"] = _race_connections.get(row["thread_id"])
        row["blocked_by_student_id"] = _race_connections.get(row["blocked_by_thread_id"])
    return rows


def clear_section(section_id):
    """Demo reset for the Race Arena: empties a section's enrollments and waitlist so the race can
    be run again. Bypasses the procedures on purpose; never use it for real registrations."""
    conn = db.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("DELETE FROM waitlist WHERE section_id = %s", (section_id,))
        cur.execute("DELETE FROM enrollments WHERE section_id = %s", (section_id,))
    finally:
        conn.close()


# Deadlock demo ---------------------------------------------------------------------------------

def run_deadlock(first_section, second_section, delay=1.0):
    """Two transactions lock the same two sections in opposite order, so they deadlock. MySQL
    rolls one back (the victim, error 1213), which then retries and succeeds.
    Returns [{locks, victim, error, retried}] for each transaction, plus the InnoDB report."""
    orders = [(first_section, second_section), (second_section, first_section)]
    results = [None, None]

    def worker(i):
        first, second = orders[i]
        result = {"locks": [first, second], "victim": False, "error": None, "retried": False}
        try:
            db.call("sp_demo_deadlock", (first, second, delay))
        except mysql.connector.Error as err:
            if err.errno != ER_LOCK_DEADLOCK:
                result["error"] = err.msg
            else:
                result.update(victim=True, error=err.msg)
                db.call("sp_demo_deadlock", (first, second, 0))   # the winner has finished: retry
                result["retried"] = True
        results[i] = result

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    return {"transactions": results, "innodb_report": latest_deadlock_report()}


def latest_deadlock_report():
    """The LATEST DETECTED DEADLOCK section of SHOW ENGINE INNODB STATUS (needs PROCESS)."""
    status = db.query("SHOW ENGINE INNODB STATUS")[0]["Status"]
    start = status.find("LATEST DETECTED DEADLOCK")
    if start == -1:
        return None
    end = status.find("\nTRANSACTIONS\n", start)
    return status[start:end].rsplit("\n", 1)[0].strip()
