#!/usr/bin/env bash
# Rollback procedure: restore the app to the last known-good image
# (final-app:previous), recreate the container, and re-verify.
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="final-app"

if ! docker image inspect "${IMAGE}:previous" >/dev/null 2>&1; then
  echo "ERROR: no rollback image (${IMAGE}:previous) exists. Nothing to roll back to."
  exit 1
fi

echo "==> Restoring ${IMAGE}:previous -> ${IMAGE}:latest"
docker tag "${IMAGE}:previous" "${IMAGE}:latest"

echo "==> Recreating app container from rolled-back image"
docker compose up -d --no-build app

echo "==> Verifying rollback"
./scripts/verify.sh
echo "==> Rollback complete."
