#!/usr/bin/env bash
# Local security scan suite. Every tool runs from a pinned official Docker image,
# so nothing has to be installed on the host and results are reproducible. These
# pins match the versions used in CI (.github/workflows/ci.yml).
#
#   1. hadolint    - Dockerfile best-practice / security linting
#   2. Trivy fs    - dependency CVEs + IaC/Docker misconfig + secrets
#   3. Trivy image - vulnerabilities in the built container image
#   4. gitleaks    - hard-coded secrets in the git history / tree
#   5. pip-audit   - Python dependency vulnerability audit (runtime + dev)
#
# Exit code is non-zero if any scanner reports a problem.
set -uo pipefail

# Pinned tool versions (keep in sync with .github/workflows/ci.yml).
TRIVY="aquasec/trivy:0.65.0"
GITLEAKS="ghcr.io/gitleaks/gitleaks:v8.21.2"
HADOLINT="hadolint/hadolint:v2.12.0"

cd "$(dirname "$0")/.."
fail=0
hr() { printf '\n=== %s ===\n' "$1"; }

hr "1/5 hadolint — Dockerfile lint"
docker run --rm -i "$HADOLINT" hadolint - < app/Dockerfile || fail=1

hr "2/5 Trivy — filesystem (deps + misconfig + secrets)"
docker run --rm -v "$PWD:/src" "$TRIVY" fs \
  --scanners vuln,misconfig,secret \
  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress /src || fail=1

hr "3/5 Trivy — container image"
# Ensure the image exists so image scanning is never silently skipped.
if ! docker image inspect final-app:latest >/dev/null 2>&1; then
  echo "final-app:latest not present — building it for the scan..."
  docker compose build app
fi
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock "$TRIVY" image \
  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress final-app:latest || fail=1

hr "4/5 gitleaks — secret scanning"
docker run --rm -v "$PWD:/repo" "$GITLEAKS" detect \
  --source /repo --no-banner --redact || fail=1

hr "5/5 pip-audit — Python dependency audit (runtime + dev)"
if command -v pip-audit >/dev/null 2>&1; then
  pip-audit -r app/requirements.txt -r app/requirements-dev.txt || fail=1
else
  docker run --rm -v "$PWD/app:/app" python:3.12-slim \
    sh -c "pip install -q pip-audit && pip-audit -r /app/requirements.txt -r /app/requirements-dev.txt" || fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "Security scan: PASSED (no HIGH/CRITICAL findings)."
else
  echo "Security scan: FINDINGS DETECTED — review output above."
fi
exit "$fail"
