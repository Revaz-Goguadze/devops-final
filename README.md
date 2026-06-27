# DevOps Final Project — Production-Ready Observability Stack

A containerized web application with a complete DevOps lifecycle: **CI/CD,
security automation, full observability (metrics, logs, alerting), health
checks, reliability automation (deploy / verify / rollback), and one-command
environment setup.**

This project extends the semester's earlier assignments. Every previously
implemented capability remains operational; the final adds the topics from the
last weeks of the course (security automation, reliability, environment
automation, and improved CI/CD).

The entire system runs **locally with Docker Compose** — no paid cloud services,
no commercial subscriptions, only free and open tools.

---

## Table of contents

- [Quick start](#quick-start)
- [Architecture](#architecture)
- [Existing functionality (carried forward)](#existing-functionality-carried-forward)
- [1. Environment automation](#1-environment-automation)
- [2. Security automation](#2-security-automation)
- [3. Reliability improvements](#3-reliability-improvements)
- [4. Automation & CI/CD](#4-automation--cicd)
- [Monitoring, logging & observability](#monitoring-logging--observability)
- [Command reference](#command-reference)
- [Repository layout](#repository-layout)
- [Screenshots / evidence](#screenshots--evidence)

---

## Quick start

One command prepares config, builds images, starts the stack, and verifies it:

```bash
make setup          # or: ./scripts/setup.sh
```

| Service | URL | Notes |
| --- | --- | --- |
| Application | http://localhost:8001 | `/`, `/work`, `/error`, `/health`, `/metrics` |
| Prometheus | http://localhost:9090 | targets, alert rules, `/alerts` |
| Grafana | http://localhost:3001 | login `admin` / `admin` |
| Loki | http://localhost:3100 | queried through Grafana |

Tear down with `make down` (keep data) or `make clean` (remove volumes).

> Ports and Grafana credentials are configurable via `.env`
> (see [`.env.example`](.env.example)); every value has a safe default, so the
> stack also runs with no `.env` at all.

---

## Architecture

A Flask application is instrumented for Prometheus and emits structured JSON
logs. Metrics flow on a pull path; logs flow on a push path; both converge in
Grafana. Health checks, alerting, and CI/CD automation wrap the whole thing.

```mermaid
flowchart LR
    subgraph app_box["Application container (non-root, healthcheck)"]
        APP["Flask app<br/>/health · /metrics<br/>JSON logs → stdout"]
    end

    APP -- "HTTP pull /metrics (5s)" --> PROM["Prometheus<br/>TSDB + alert rules"]
    APP -. "stdout via Docker logs" .-> PT["Promtail"]
    PT -- "push" --> LOKI["Loki"]

    PROM -- "PromQL / alerts" --> GRAF["Grafana<br/>dashboards + Alerting"]
    LOKI -- "LogQL" --> GRAF

    subgraph cicd["CI/CD (GitHub Actions) + local automation"]
        CI["lint · test · security scans<br/>build · image scan · deploy-verify"]
    end
    CI -- "make deploy / verify / rollback" --> app_box
```

Two data paths:

```
Flask app ──/metrics (scrape)──▶ Prometheus ──PromQL──▶ Grafana (dashboards)
    │                                  │
    │                                  └──alert rules──▶ Grafana (Alerting tab)
    └──stdout (JSON)──▶ Promtail ──push──▶ Loki ──LogQL──▶ Grafana (logs)
```

---

## Existing functionality (carried forward)

All capabilities from earlier assignments remain operational in this project:

| Capability | Where it lives |
| --- | --- |
| Version control (Git) | this repository, conventional commits |
| Branching strategy | `main` (release) + `develop` (integration) + `feature/*` |
| Continuous Integration | `.github/workflows/ci.yml` (lint, test) |
| Continuous Deployment | `scripts/deploy.sh` + CI `build-verify` job |
| Infrastructure as Code / automation | `docker-compose.yml`, `scripts/*.sh`, `Makefile` |
| Docker / Docker Compose | `app/Dockerfile`, `docker-compose.yml` |
| Monitoring | Prometheus + Grafana dashboard |
| Logging | structured JSON → Promtail → Loki |
| Observability | metrics + logs + alerts correlated in Grafana |
| Alerting | `prometheus/alert.rules.yml` |
| Health checks | `/health` endpoint + Docker + compose healthchecks |

---

## 1. Environment automation

The whole environment is reproducible from a single command on any machine with
Docker + Docker Compose.

- **`make setup`** (`scripts/setup.sh`) — checks prerequisites, creates `.env`
  from `.env.example` if missing, builds images, starts every service, then runs
  the verification suite. No manual configuration.
- **`.env.example`** documents every configurable value (ports, Grafana
  credentials); defaults are baked into `docker-compose.yml`.
- **`scripts/verify.sh`** asserts the environment is actually healthy (all
  services reachable + Prometheus scraping the app), failing visibly otherwise.

---

## 2. Security automation

Security is integrated into both the local workflow and CI. Run everything
locally with:

```bash
make security        # scripts/security-scan.sh
```

| Check | Tool | Scope |
| --- | --- | --- |
| Dependency vulnerabilities | **Trivy** (`fs`) + **pip-audit** | Python packages & CVEs |
| Container image scanning | **Trivy** (`image`) | built `final-app:latest` |
| Secrets scanning | **gitleaks** | git history & working tree |
| IaC / Docker / config validation | **Trivy** (`misconfig`) + **hadolint** | Dockerfile, compose, configs |
| CI/CD integration | GitHub Actions `security` job | runs on every push/PR |

All scanners run from their official Docker images (nothing to install) and the
same checks run in CI (`.github/workflows/ci.yml`), so findings are reproducible
locally. Scans fail the pipeline on **HIGH/CRITICAL fixable** findings.

**Hardening applied:** the app image runs as a **non-root user**, a
`.dockerignore` keeps test/dev artifacts out of the image, dependencies were
upgraded to patched versions (e.g. Flask 3.1.3, gunicorn 23), secrets are kept
in a gitignored `.env`, and Grafana credentials default only for local use.

> Note: the `python:3.12-slim` base image carries some OS-level CVEs with no
> upstream fix yet (`fix_deferred`/`affected`). These are excluded with
> `--ignore-unfixed` since they are not introduced by the application and cannot
> be remediated by us; they are picked up automatically when the base image
> publishes fixes.

---

## 3. Reliability improvements

| Improvement | Implementation |
| --- | --- |
| **Health monitoring** | `/health` endpoint, Docker `HEALTHCHECK`, compose healthchecks with `service_healthy` ordering |
| **Rollback procedure** | `make rollback` — restores the last known-good image (`final-app:previous`) and re-verifies |
| **Failure recovery automation** | `restart: unless-stopped` on all services + auto-rollback on failed deploy verification |
| **Improved alerting** | added `ServiceDown` (target down) and `AvailabilityBelowSLO` alerts alongside `HighErrorRate` |
| **Service availability objectives** | [`docs/SLO.md`](docs/SLO.md) — 99% availability SLO with error budget policy |
| **Incident response** | [`docs/INCIDENT-RESPONSE.md`](docs/INCIDENT-RESPONSE.md) — detection → triage → recover → post-incident runbook |

Deployments are self-protecting: `scripts/deploy.sh` snapshots the current image,
releases the new one, runs `verify.sh`, and **automatically rolls back** if
verification fails.

---

## 4. Automation & CI/CD

The pipeline (`.github/workflows/ci.yml`) runs on every push/PR to `main`/`develop`:

```
lint-test ─┐
           ├──▶ build-verify  (build → Trivy image scan → start stack → verify → teardown)
security ──┘
```

1. **`lint-test`** — `ruff` lint + `pytest` unit tests (`app/test_app.py`).
2. **`security`** — hadolint, gitleaks, Trivy filesystem scan, pip-audit.
3. **`build-verify`** — builds the image, scans it with Trivy, starts the full
   stack, runs `scripts/verify.sh` as a **post-deployment check**, and tears
   down. This gives automated **deployment verification** end to end.

Local automation mirrors CI through the `Makefile`, so the same lint, test,
security, deploy, verify, and rollback steps are runnable on any machine.

---

## Monitoring, logging & observability

### Instrumentation
`app/app.py` exposes `app_requests_total{endpoint}` and `app_errors_total`, plus
`/health` and `/metrics`. Prometheus scrapes `/metrics` every 5s.

### Logging
The app logs **structured JSON to stdout** (12-factor). **Promtail** discovers
containers via the Docker socket, parses the JSON, promotes `level` to a Loki
label, and **pushes** to **Loki**. Query in Grafana Explore:

```logql
{container="app"} | json | level="ERROR"
```

### Alerting
`prometheus/alert.rules.yml` defines three alerts:

- **HighErrorRate** (critical) — `increase(app_errors_total[1m]) > 5`
- **ServiceDown** (critical) — `up == 0` for 30s
- **AvailabilityBelowSLO** (warning) — 5m success ratio `< 0.99`

Fire the critical alert on demand:

```bash
make alert            # sends 12 errors; watch Prometheus /alerts or Grafana Alerting
```

---

## Command reference

```text
make help        # list all commands
make setup       # one-command bootstrap: config + build + start + verify
make up / down   # start / stop the stack
make deploy      # deploy a new build with verification + auto-rollback
make verify      # post-deployment health/validation checks
make rollback    # roll back to the last known-good image
make security    # full security scan suite
make test        # run unit tests
make lint        # lint the Dockerfile
make alert       # fire the CRITICAL alert
make logs        # tail all service logs
make clean       # stop and remove data volumes
```

---

## Repository layout

```
.
├── Makefile                        # single entry point for every operation
├── docker-compose.yml              # 5 services + healthchecks + env config
├── .env.example                    # documented, reproducible configuration
├── app/
│   ├── app.py                      # Flask app: /health, /metrics, JSON logs
│   ├── test_app.py                 # pytest unit tests (run in CI)
│   ├── requirements.txt            # runtime deps (patched versions)
│   ├── requirements-dev.txt        # test/lint deps
│   ├── Dockerfile                  # non-root, HEALTHCHECK, hardened
│   └── .dockerignore
├── prometheus/
│   ├── prometheus.yml              # scrape config
│   └── alert.rules.yml             # HighErrorRate + ServiceDown + SLO alerts
├── loki/loki-config.yml
├── promtail/promtail-config.yml
├── grafana/provisioning/           # auto-wired datasources + dashboard
├── scripts/
│   ├── setup.sh                    # one-command environment bootstrap
│   ├── deploy.sh                   # deploy + verify + auto-rollback
│   ├── verify.sh                   # post-deploy health/validation checks
│   ├── rollback.sh                 # rollback procedure
│   ├── security-scan.sh            # Trivy + gitleaks + hadolint + pip-audit
│   └── trigger-alert.sh            # fires the CRITICAL alert
├── .github/workflows/ci.yml        # CI/CD: lint, test, security, build-verify
└── docs/
    ├── SLO.md                      # service level objectives + error budget
    ├── INCIDENT-RESPONSE.md        # incident runbook
    └── screenshots / evidence (*.png)
```

---

## Screenshots / evidence

### Carried-forward observability evidence

| Evidence | Image |
| --- | --- |
| Grafana dashboard (custom metrics) | ![dashboard](docs/dashboard.png) |
| Loki filtered JSON error logs | ![logs](docs/logs.png) |
| Grafana Alerting — HighErrorRate firing | ![alert](docs/alert.png) |
| Prometheus Alerts — HighErrorRate firing | ![prometheus alert](docs/prometheus-alert-firing.png) |
| Application `/metrics` endpoint | ![metrics](docs/app-metrics.png) |
| Application JSON response | ![response](docs/app-response.png) |

### Final-project evidence (new)

These demonstrate the newly added functionality.

#### Environment automation & health checks
`make verify` — every service reachable and Prometheus scraping the app:

![verification all OK](docs/setup-verify.png)

`docker compose ps` — every container reports `healthy`:

![containers healthy](docs/compose-healthy.png)

#### Reliability — deploy & rollback
`make deploy` snapshots the current image, releases the new one, and verifies it;
`make rollback` restores the last known-good image and re-verifies:

![deploy start: snapshot rollback point](docs/deploy-rollback-1.png)
![deploy succeeded then rollback complete](docs/deploy-rollback-2.png)

#### Improved alerting (three rules)
Prometheus — `HighErrorRate` **FIRING**, `ServiceDown` and `AvailabilityBelowSLO` registered:

![Prometheus alerts firing](docs/alert-firing-1.png)

Grafana Alerting — `HighErrorRate` firing detail and all three rules grouped:

![Grafana alert firing detail](docs/alert-firing-2.png)
![Grafana alert rules grouped](docs/alert-firing-3.png)

#### Security automation (`make security`)
The full suite — hadolint, Trivy filesystem (deps + misconfig + secrets), Trivy
image, gitleaks, and pip-audit:

![hadolint + Trivy filesystem scan starting](docs/security-scan-1.png)
![Trivy clean, gitleaks no leaks, pip-audit clean — scan PASSED](docs/security-scan-2.png)

#### CI/CD pipeline
GitHub Actions — all three jobs green. Run summary (Status **Success**, gitleaks
"No leaks detected"):

![CI pipeline summary — success](docs/ci-pipeline-1.png)

`Lint & Test` job — ruff + pytest:

![CI Lint & Test job](docs/ci-pipeline-2.png)

`Security scans` job — hadolint, gitleaks, Trivy filesystem, pip-audit all pass:

![CI Security scans job](docs/ci-pipeline-3.png)

`Build, scan image & verify deployment` job — Trivy image scan + post-deploy
verification on the runner:

![CI build, scan image & verify job](docs/ci-pipeline-4.png)
