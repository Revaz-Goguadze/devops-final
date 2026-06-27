#!/usr/bin/env sh
# Sends enough errors to push app_errors_total above 5/min and fire the
# HighErrorRate CRITICAL alert. Adjust APP_URL if you remapped the host port.
APP_URL="${APP_URL:-http://localhost:8001}"
COUNT="${1:-12}"

echo "Sending $COUNT errors to $APP_URL/error ..."
i=1
while [ "$i" -le "$COUNT" ]; do
  curl -s "$APP_URL/error" >/dev/null
  i=$((i + 1))
done
echo "Done. Watch the alert at http://localhost:9090/alerts or Grafana's Alerting tab."
