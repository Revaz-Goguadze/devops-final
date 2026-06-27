"""Minimal instrumented web app for the observability lab.

Exposes Prometheus metrics, emits structured JSON logs to stdout, and provides
an /error endpoint used to drive the error rate above the alert threshold.
"""
import logging
import random
import sys

from flask import Flask, Response, jsonify
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


if __name__ == "__main__":
    logger.info("starting app", extra={"port": 8000})
    app.run(host="0.0.0.0", port=8000)
