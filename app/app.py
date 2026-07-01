"""Minimal instrumented web app for the observability lab.

Exposes Prometheus metrics, emits structured JSON logs to stdout, and provides
an /error endpoint used to drive the error rate above the alert threshold.
"""
import logging
import random
import sys

from flask import Flask, Response, jsonify, redirect, render_template_string, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest
from pythonjsonlogger import jsonlogger

# --- Structured JSON logging to stdout (collected by Promtail -> Loki) ---
logger = logging.getLogger("app")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(
    jsonlogger.JsonFormatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s",
        rename_fields={"asctime": "timestamp", "levelname": "level"},
    )
)
logger.addHandler(handler)
logger.propagate = False

# --- Prometheus metrics ---
REQUESTS = Counter("app_requests_total", "Total number of HTTP requests", ["endpoint"])
ERRORS = Counter("app_errors_total", "Total number of application errors")

app = Flask(__name__)


@app.route("/")
def index():
    REQUESTS.labels(endpoint="/").inc()
    logger.info("handled request", extra={"endpoint": "/", "status": 200})
    return jsonify(status="ok", service="observability-lab")


@app.route("/health")
def health():
    """Liveness/readiness probe used by Docker, deploy verification, and uptime alerting."""
    REQUESTS.labels(endpoint="/health").inc()
    return jsonify(status="healthy", service="observability-lab"), 200


@app.route("/work")
def work():
    """Simulates real traffic; ~10% of calls fail to produce a low baseline error rate."""
    REQUESTS.labels(endpoint="/work").inc()
    if random.random() < 0.1:
        ERRORS.inc()
        logger.error("work failed", extra={"endpoint": "/work", "status": 500})
        return jsonify(status="error", message="work failed"), 500
    logger.info("work done", extra={"endpoint": "/work", "status": 200})
    return jsonify(status="ok")


@app.route("/error")
def error():
    """Always errors. Hit this repeatedly to push the error rate above 5/min."""
    REQUESTS.labels(endpoint="/error").inc()
    ERRORS.inc()
    logger.error("simulated error", extra={"endpoint": "/error", "status": 500})
    return jsonify(status="error", message="simulated error"), 500


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


# --- Dynamic control panel -------------------------------------------------
# An HTML form that lets a user drive the observability stack from the browser:
# submitting it generates traffic server-side, which moves the Prometheus
# counters, emits JSON logs to Loki, and (with enough errors) fires the
# HighErrorRate alert. This is the project's "dynamic web application + input
# form" surface, wired into the metrics/logging/alerting it already exposes.
UI_TEMPLATE = """<!doctype html>
<title>Observability control panel</title>
<h1>Observability control panel</h1>
<p>Generate traffic to drive metrics, logs, and alerts.</p>
<form method="post" action="/simulate">
  <label>Requests: <input type="number" name="count" value="10" min="1" max="200"></label>
  <label>Type:
    <select name="kind">
      <option value="work">work (~10% fail)</option>
      <option value="error">error (always fail)</option>
    </select>
  </label>
  <button type="submit">Send</button>
</form>
{% if msg %}<p><strong>{{ msg }}</strong></p>{% endif %}
<p>See: <a href="/metrics">/metrics</a> · Prometheus /alerts · Grafana dashboards.</p>
"""


@app.route("/ui")
def ui():
    """Dynamic HTML page with the traffic-generation form."""
    REQUESTS.labels(endpoint="/ui").inc()
    return render_template_string(UI_TEMPLATE, msg=request.args.get("msg", ""))


@app.route("/simulate", methods=["POST"])
def simulate():
    """Handle the form POST: generate N requests server-side and report results."""
    REQUESTS.labels(endpoint="/simulate").inc()
    try:
        count = max(1, min(200, int(request.form.get("count", 10))))
    except (TypeError, ValueError):
        count = 10
    kind = request.form.get("kind", "work")

    errors = 0
    for _ in range(count):
        REQUESTS.labels(endpoint=f"/simulate:{kind}").inc()
        if kind == "error" or random.random() < 0.1:
            ERRORS.inc()
            errors += 1
            logger.error("simulated traffic error", extra={"endpoint": "/simulate", "status": 500})
        else:
            logger.info("simulated traffic ok", extra={"endpoint": "/simulate", "status": 200})

    logger.info("simulate batch done", extra={"count": count, "kind": kind, "errors": errors})
    return redirect(f"/ui?msg=Sent {count} '{kind}' requests ({errors} errors).")


if __name__ == "__main__":
    logger.info("starting app", extra={"port": 8000})
    app.run(host="0.0.0.0", port=8000)
