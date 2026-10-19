from flask import Flask, jsonify

import db

app = Flask(__name__)


@app.route("/")
def health():
    """Day 0 check: proves Flask can read from MySQL on this machine."""
    server = db.query("SELECT VERSION() AS version, DATABASE() AS db, CURRENT_USER() AS user")[0]
    tables = db.query(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = %s ORDER BY table_name",
        (server["db"],),
    )
    return jsonify(server=server, tables=[t["table_name"] for t in tables])
