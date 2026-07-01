#!/usr/bin/env bash
# One-command environment bootstrap.
# Prepares config, builds images, starts the full stack, and verifies it is
# healthy. Reproducible on any machine that has Docker + Docker Compose.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> [1/4] Checking prerequisites"
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: 'docker compose' plugin not available"; exit 1; }

echo "==> [2/4] Preparing configuration"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "    created .env from .env.example"
else
  echo "    .env already present, leaving it untouched"
fi

echo "==> [3/4] Building and starting the stack"
docker compose up -d --build

echo "==> [4/4] Verifying deployment"
./scripts/verify.sh

# Load .env so the summary below reflects the actual configured ports/credentials
# (compose already reads .env on its own; this is just for accurate output).
if [ -f .env ]; then set -a; . ./.env; set +a; fi

echo
echo "Environment ready."
echo "  App         http://localhost:${APP_PORT:-8001}        (/, /ui, /work, /error, /health, /metrics)"
echo "  Prometheus  http://localhost:${PROMETHEUS_PORT:-9090}"
echo "  Grafana     http://localhost:${GRAFANA_PORT:-3001}    (${GF_ADMIN_USER:-admin} / ${GF_ADMIN_PASSWORD:-admin})"
echo "  Loki        http://localhost:${LOKI_PORT:-3100}"
