"""Flask app: page routes plus a JSON API over the stored procedures and views.

Routes stay thin (CLAUDE.md rule 1): they read a v_... view or call a registration.py wrapper,
and every rule lives in MySQL. Any MySQL error becomes {"error": msg} with status 400.
"""
from datetime import date, datetime, timedelta
from decimal import Decimal

import mysql.connector
from flask import Flask, jsonify, redirect, render_template, request, url_for
from flask.json.provider import DefaultJSONProvider

import db
import registration
from isolation import LEVELS, SCENARIOS, IsolationLab


class JSONProvider(DefaultJSONProvider):
    """ISO timestamps (with microseconds, for the race timeline), HH:MM for TIME, plain numbers for DECIMAL."""

    @staticmethod
    def default(o):
        if isinstance(o, (datetime, date)):
            return o.isoformat()
        if isinstance(o, timedelta):          # MySQL TIME columns arrive as timedelta
            minutes = int(o.total_seconds()) // 60
            return f"{minutes // 60:02d}:{minutes % 60:02d}"
        if isinstance(o, Decimal):            # SUM() returns DECIMAL: keep whole numbers whole
            return int(o) if o == o.to_integral_value() else float(o)
        return DefaultJSONProvider.default(o)


app = Flask(__name__)
app.json = JSONProvider(app)

# Isolation Lab sessions, keyed by isolation level. Single-process dev server only.
labs = {}

ANALYTICS_VIEWS = {
    "section_seats": "SELECT * FROM v_section_seats ORDER BY section_id",
    "course_demand": "SELECT * FROM v_course_demand ORDER BY dept_name, dept_rank",
    "oversubscribed": "SELECT * FROM v_oversubscribed_courses ORDER BY demand DESC",
    "daily_activity": "SELECT * FROM v_daily_activity ORDER BY activity_date",
}


@app.errorhandler(mysql.connector.Error)
def mysql_error(err):
    return jsonify(error=err.msg), 400


def body():
    return request.get_json(force=True)


# Pages -----------------------------------------------------------------------------------------

@app.route("/")
def index():
    return redirect(url_for("catalog"))


@app.route("/catalog")
def catalog():
    return render_template("catalog.html")


# Students, catalog, schedule -------------------------------------------------------------------

@app.get("/api/health")
def health():
    return jsonify(db.query("SELECT VERSION() AS version, DATABASE() AS db, CURRENT_USER() AS user")[0])


@app.get("/api/students")
def students():
    return jsonify(db.query("""
        SELECT st.student_id, st.name, st.email, d.name AS dept_name, st.max_credits
        FROM students st JOIN departments d ON d.dept_id = st.dept_id
        ORDER BY st.student_id"""))


@app.get("/api/sections")
def sections():
    return jsonify(db.query("SELECT * FROM v_section_seats ORDER BY course_code, section_code"))


@app.get("/api/students/<int:student_id>/timetable")
def timetable(student_id):
    return jsonify(db.query(
        "SELECT * FROM v_student_timetable WHERE student_id = %s ORDER BY day, start_time", (student_id,)))


@app.get("/api/students/<int:student_id>/waitlist")
def waitlist(student_id):
    return jsonify(db.query(
        "SELECT * FROM v_waitlist_positions WHERE student_id = %s ORDER BY requested_at", (student_id,)))


# Registration ----------------------------------------------------------------------------------

@app.post("/api/register")
def register():
    data = body()
    return jsonify(registration.register(data["student_id"], data["section_id"],
                                         fail=data.get("fail", False)))


@app.post("/api/cart")
def cart():
    data = body()
    return jsonify(registration.register_cart(data["student_id"], data["section_ids"],
                                              data.get("fail_section")))


@app.post("/api/drop")
def drop():
    data = body()
    registration.drop(data["student_id"], data["section_id"])
    return jsonify(ok=True)


# Admin -----------------------------------------------------------------------------------------

@app.post("/api/admin/capacity")
def set_capacity():
    data = body()
    registration.set_capacity(data["section_id"], data["capacity"])
    return jsonify(ok=True)


@app.get("/api/admin/audit")
def audit():
    limit = min(request.args.get("limit", 50, type=int), 500)
    return jsonify(db.query("SELECT * FROM v_audit_feed ORDER BY log_id DESC LIMIT %s", (limit,)))


@app.get("/api/analytics/<name>")
def analytics(name):
    if name not in ANALYTICS_VIEWS:
        return jsonify(error=f"Unknown chart: {name}"), 404
    return jsonify(db.query(ANALYTICS_VIEWS[name]))


# Race Arena and deadlock -----------------------------------------------------------------------

@app.post("/api/race")
def race():
    data = body()
    results = registration.run_race(data["section_id"], data["student_ids"],
                                    data.get("safe", True), data.get("delay", 2.0))
    seats = db.query("SELECT * FROM v_section_seats WHERE section_id = %s", (data["section_id"],))[0]
    return jsonify(results=results, seats=seats)


@app.post("/api/race/clear")
def race_clear():
    registration.clear_section(body()["section_id"])
    return jsonify(ok=True)


@app.get("/api/locks")
def locks():
    return jsonify(registration.lock_snapshot())


@app.post("/api/deadlock")
def deadlock():
    data = body()
    return jsonify(registration.run_deadlock(data.get("first_section", 6), data.get("second_section", 7)))


# Isolation Lab ---------------------------------------------------------------------------------

@app.get("/api/isolation/scenarios")
def isolation_scenarios():
    return jsonify(levels=LEVELS, scenarios=SCENARIOS)


@app.post("/api/isolation/start")
def isolation_start():
    level = body()["level"]
    if level in labs:
        labs.pop(level).close()
    labs[level] = IsolationLab(level)
    return jsonify(ok=True)


@app.post("/api/isolation/step")
def isolation_step():
    data = body()
    lab = labs.get(data["level"])
    if lab is None:
        return jsonify(error="Start a lab for this level first."), 400
    return jsonify(lab.step(data["scenario"], data["index"]))


@app.post("/api/isolation/stop")
def isolation_stop():
    lab = labs.pop(body()["level"], None)
    if lab:
        lab.close()
    return jsonify(ok=True)
