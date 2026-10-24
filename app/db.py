"""Database connection handling. All app database access goes through this module."""
import os

import mysql.connector
from dotenv import load_dotenv

load_dotenv()


def get_connection():
    return mysql.connector.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        database=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        # Procedures manage their own transactions. Without autocommit, writes made outside one
        # (like the REJECT audit row) would wait for a commit that never comes.
        autocommit=True,
    )


def query(sql, params=()):
    """Run a parameterized SELECT and return the rows as dicts."""
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params)
        return cur.fetchall()
    finally:
        conn.close()


def call(proc, args=(), conn=None):
    """CALL a stored procedure. Returns (args with OUT values filled in, result sets as lists of dicts).

    Pass conn to run on a specific connection (the race needs one per student); otherwise a new
    connection is opened and closed.
    """
    own_conn = conn is None
    conn = conn or get_connection()
    try:
        cur = conn.cursor()
        out = cur.callproc(proc, args)
        result_sets = [[dict(zip(rs.column_names, row)) for row in rs.fetchall()]
                       for rs in cur.stored_results()]
        return out, result_sets
    finally:
        if own_conn:
            conn.close()
