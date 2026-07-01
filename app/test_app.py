"""Unit tests for the instrumented Flask app (run in CI before any deploy)."""
import app as app_module


def client():
    app_module.app.config.update(TESTING=True)
    return app_module.app.test_client()


def test_index_ok():
    resp = client().get("/")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_health_ok():
    resp = client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "healthy"


def test_error_returns_500():
    resp = client().get("/error")
    assert resp.status_code == 500
    assert resp.get_json()["status"] == "error"


def test_metrics_exposes_counters():
    body = client().get("/metrics").get_data(as_text=True)
    assert "app_requests_total" in body
    assert "app_errors_total" in body


def test_ui_renders_form():
    resp = client().get("/ui")
    assert resp.status_code == 200
    assert "<form" in resp.get_data(as_text=True)


def test_simulate_generates_errors_and_redirects():
    resp = client().post("/simulate", data={"count": "3", "kind": "error"})
    assert resp.status_code == 302
    assert "/ui" in resp.headers["Location"]
