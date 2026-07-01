#!/usr/bin/env bash
# End-to-end alert notification-path check.
# Proves the full chain works: app error -> Prometheus alert -> Alertmanager ->
# SMTP -> Mailpit inbox. Fires the HighErrorRate alert, then polls the Mailpit
# API until a matching alert email is delivered. Fails visibly if it never lands.
set -uo pipefail

cd "$(dirname "$0")/.."

APP_PORT="${APP_PORT:-8001}"
MAILPIT_UI_PORT="${MAILPIT_UI_PORT:-8025}"
MAILPIT_API="http://localhost:${MAILPIT_UI_PORT}/api/v1"
MATCH="HighErrorRate"

echo "==> Baseline Mailpit inbox count"
before="$(curl -fsS --max-time 5 "${MAILPIT_API}/messages?limit=1" 2>/dev/null | grep -o '"total":[0-9]*' | head -1 | cut -d: -f2)"
before="${before:-0}"
echo "    messages before: ${before}"

echo "==> Firing HighErrorRate alert (sending errors)"
./scripts/trigger-alert.sh 12 >/dev/null

echo "==> Waiting for the alert email to reach Mailpit (up to ~120s)"
for _ in $(seq 1 40); do
  # Search the inbox for a message mentioning the alert name.
  hits="$(curl -fsS --max-time 5 "${MAILPIT_API}/search?query=${MATCH}" 2>/dev/null | grep -o '"total":[0-9]*' | head -1 | cut -d: -f2)"
  if [ -n "${hits:-}" ] && [ "$hits" -ge 1 ]; then
    echo "    delivered: ${hits} email(s) matching '${MATCH}' in Mailpit."
    echo
    echo "Notification path OK (app -> Prometheus -> Alertmanager -> Mailpit)."
    exit 0
  fi
  sleep 3
done

echo
echo "FAILED: no '${MATCH}' email arrived in Mailpit within the timeout."
echo "Check: docker compose logs alertmanager | tail; Mailpit at http://localhost:${MAILPIT_UI_PORT}"
exit 1
