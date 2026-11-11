"""Deliberately vulnerable demo app. DO NOT DEPLOY.

Six flaws are seeded on purpose so that Semgrep (reading this file) and ZAP (attacking
the running app) both have something to report. app/expected.txt lists them.
"""
import sqlite3
import subprocess

from flask import Flask, make_response, request

app = Flask(__name__)

# FLAW 1 - hard-coded credential: a (fake) database password written in the source code.
DATABASE_URL = "postgresql://shop_admin:Demo-Passw0rd@db.internal:5432/shop"

db = sqlite3.connect(":memory:", check_same_thread=False)
db.execute("CREATE TABLE products (name TEXT, price REAL)")
db.executemany("INSERT INTO products VALUES (?, ?)", [("apple", 1.0), ("pear", 1.5)])


@app.route("/")
def index():
    return """<html><head><title>Demo shop</title></head><body>
<h1>Demo shop</h1>
<ul>
  <li><a href="/hello?name=guest">Say hello</a></li>
  <li><a href="/search?q=apple">Search products</a></li>
  <li><a href="/lookup?host=localhost">Look up a host</a></li>
  <li><a href="/login">Log in</a></li>
</ul>
<form action="/search" method="get"><input name="q"><button>Search</button></form>
</body></html>"""


@app.route("/hello")
def hello():
    name = request.args.get("name", "guest")
    # FLAW 2 - reflected XSS: user input goes into HTML without escaping.
    return "<h1>Hello " + name + "</h1>"


@app.route("/search")
def search():
    q = request.args.get("q", "")
    # FLAW 3 - SQL injection: user input is concatenated into the query.
    rows = db.execute("SELECT name, price FROM products WHERE name = '" + q + "'").fetchall()
    return {"results": rows}


@app.route("/lookup")
def lookup():
    host = request.args.get("host", "localhost")
    # FLAW 4 - command injection: user input goes to a shell.
    out = subprocess.run("getent hosts " + host, shell=True, capture_output=True, text=True)
    return "<pre>" + out.stdout + "</pre>"


@app.route("/login")
def login():
    resp = make_response("<p>Logged in as demo.</p>")
    # FLAW 5 - session cookie without the Secure, HttpOnly and SameSite flags.
    resp.set_cookie("session_id", "demo-session")
    return resp


if __name__ == "__main__":
    # FLAW 6 - debug mode on, listening on all interfaces.
    app.run(host="0.0.0.0", port=5000, debug=True)
