#!/usr/bin/env bash
# Post-deployment verification / automated environment validation.
# Polls every service's health endpoint and asserts Prometheus is actually
# scraping the app. Exits non-zero (fails visibly) if anything is unhealthy.
set -uo pipefail

APP_PORT="${APP_PORT:-8001}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
LOKI_PORT="${LOKI_PORT:-3100}"

fail=0

# wait_for <name> <url> <expected-substring>
wait_for() {
  local name="$1" url="$2" expect="$3" tries=30
  printf "  %-12s " "$name"
  for _ in $(seq 1 "$tries"); do
    body="$(curl -fsS --max-time 3 "$url" 2>/dev/null || true)"
    if [ -n "$body" ] && printf '%s' "$body" | grep -Eq "$expect"; then
      echo "OK"
      return 0
    fi
    sleep 2
  done
  echo "FAILED ($url did not return '$expect')"
  fail=1
  return 1
}

echo "Verifying services:"
wait_for "app"        "http://localhost:${APP_PORT}/health"        '"status": ?"healthy"'
wait_for "app-metrics" "http://localhost:${APP_PORT}/metrics"      'app_requests_total'
wait_for "prometheus" "http://localhost:${PROMETHEUS_PORT}/-/healthy" 'Prometheus'
wait_for "grafana"    "http://localhost:${GRAFANA_PORT}/api/health"   'database'
wait_for "loki"       "http://localhost:${LOKI_PORT}/ready"           'ready'

# Assert Prometheus has the app target UP (deployment is truly observable).
printf "  %-12s " "scrape-up"
up="$(curl -fsS --max-time 3 "http://localhost:${PROMETHEUS_PORT}/api/v1/query?query=up%7Bjob%3D%22app%22%7D" 2>/dev/null || true)"
if printf '%s' "$up" | grep -q '"value":\[.*"1"\]'; then
  echo "OK"
else
  echo "FAILED (Prometheus target up{job=\"app\"} != 1)"
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks FAILED."
fi
exit "$fail"
