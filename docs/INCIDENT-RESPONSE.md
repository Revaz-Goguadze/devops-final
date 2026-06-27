# Incident Response Runbook

A lightweight, practical runbook for operating this stack. It covers detection,
triage, recovery, and prevention for the failure modes the monitoring can see.

## 1. Detection

Incidents surface through the alerting and health tooling already in place:

| Signal | Where | Means |
| --- | --- | --- |
| `HighErrorRate` firing | Prometheus `/alerts`, Grafana Alerting | > 5 errors/min |
| `ServiceDown` firing | Prometheus `/alerts` | a target stopped responding |
| `AvailabilityBelowSLO` firing | Prometheus `/alerts` | success rate < 99% |
| `make verify` fails | terminal / CI | a service is unhealthy |
| container `unhealthy` | `docker compose ps` | failed Docker healthcheck |

## 2. Triage (severity)

- **SEV1 (critical):** app down (`ServiceDown` for `job="app"`) or sustained
  `HighErrorRate`. User-facing. Act immediately.
- **SEV2 (warning):** `AvailabilityBelowSLO`, or a non-app component degraded.
  Investigate before the error budget is exhausted.

## 3. Diagnose

```bash
docker compose ps                 # which container is unhealthy / restarting?
docker compose logs --tail=100 app
# Grafana -> Explore -> Loki:
#   {container="app"} | json | level="ERROR"
# Prometheus:
#   rate(app_errors_total[1m])      # error trend
#   up                              # which targets are down
```

## 4. Recover

| Situation | Action |
| --- | --- |
| Bad deploy / regression | `make rollback` (restores `final-app:previous`, re-verifies) |
| Single crashed container | `docker compose restart <service>` (also auto-restarts via `restart: unless-stopped`) |
| Config broken / corrupt state | `make down && make up` |
| App healthy but alert stuck | confirm error source, then let `increase()` window clear |

After any recovery action, **always run `make verify`** to confirm the system is
healthy and Prometheus is scraping the app again.

## 5. Post-incident

1. Confirm all alerts cleared and `make verify` passes.
2. Note what failed, how it was detected, and time-to-recovery.
3. If a deploy caused it, add/extend a test or a CI check so the same class of
   failure is caught before release.
4. Review whether SLO thresholds or alert timings need tuning.
