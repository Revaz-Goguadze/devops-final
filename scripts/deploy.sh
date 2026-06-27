#!/usr/bin/env bash
# Deployment automation with built-in verification and automatic rollback.
#   1. snapshots the current image as the rollback point (final-app:previous)
#   2. builds and releases the new image (final-app:latest)
#   3. verifies the deployment; if verification fails, rolls back automatically
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="final-app"

echo "==> Snapshotting current image as rollback point"
if docker image inspect "${IMAGE}:latest" >/dev/null 2>&1; then
  docker tag "${IMAGE}:latest" "${IMAGE}:previous"
  echo "    ${IMAGE}:latest -> ${IMAGE}:previous"
else
  echo "    no existing ${IMAGE}:latest (first deploy, nothing to snapshot)"
fi

echo "==> Building and releasing new image"
docker compose build app
docker compose up -d app

echo "==> Verifying new deployment"
if ./scripts/verify.sh; then
  echo "==> Deploy succeeded."
else
  echo "==> Deploy verification FAILED — rolling back automatically."
  ./scripts/rollback.sh
  exit 1
fi
