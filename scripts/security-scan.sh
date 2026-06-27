#!/usr/bin/env bash
# Local security scan suite. Every tool runs from its official Docker image, so
# nothing has to be installed on the host. Mirrors the checks in CI
# (.github/workflows/ci.yml) so failures can be reproduced locally.
#
#   1. hadolint    - Dockerfile best-practice / security linting
#   2. Trivy fs    - dependency CVEs + IaC/Docker misconfig + secrets
#   3. Trivy image - vulnerabilities in the built container image
#   4. gitleaks    - hard-coded secrets in the git history / tree
#   5. pip-audit   - Python dependency vulnerability audit
#
# Exit code is non-zero if any scanner reports a problem.
set -uo pipefail

cd "$(dirname "$0")/.."
fail=0
hr() { printf '\n=== %s ===\n' "$1"; }

hr "1/5 hadolint — Dockerfile lint"
docker run --rm -i hadolint/hadolint hadolint - < app/Dockerfile || fail=1

hr "2/5 Trivy — filesystem (deps + misconfig + secrets)"
docker run --rm -v "$PWD:/src" aquasec/trivy:latest fs \
  --scanners vuln,misconfig,secret \
  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress /src || fail=1

hr "3/5 Trivy — container image"
if docker image inspect final-app:latest >/dev/null 2>&1; then
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image \
    --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress final-app:latest || fail=1
else
  echo "SKIPPED: final-app:latest not built yet (run 'make up' first)."
fi

hr "4/5 gitleaks — secret scanning"
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect \
  --source /repo --no-banner --redact || fail=1

hr "5/5 pip-audit — Python dependency audit"
if command -v pip-audit >/dev/null 2>&1; then
  pip-audit -r app/requirements.txt || fail=1
else
  docker run --rm -v "$PWD/app:/app" python:3.12-slim \
    sh -c "pip install -q pip-audit && pip-audit -r /app/requirements.txt" || fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "Security scan: PASSED (no HIGH/CRITICAL findings)."
else
  echo "Security scan: FINDINGS DETECTED — review output above."
fi
exit "$fail"
