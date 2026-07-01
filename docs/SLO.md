# Service Level Objectives (SLOs)

These objectives define the reliability targets for the application service and
how they are measured from the existing Prometheus metrics.

| SLI (indicator) | Definition | SLO (objective) | Source |
| --- | --- | --- | --- |
| Availability | `up{job="app"}` scraped successfully | **99%** rolling | Prometheus `up` metric |
| Success rate | non-error responses / total requests | **≥ 99%** over 5m | `app_errors_total`, `app_requests_total` |
| Error budget | allowed failures within the window | **1%** of requests | derived |

## How each SLI is measured

- **Availability** — Prometheus scrapes `app:8000/metrics` every 5s. `up == 0`
  means the last scrape failed; the `ServiceDown` alert fires after 30s.
- **Success rate** — the rolling ratio
  `1 - increase(app_errors_total[5m]) / increase(app_requests_total{endpoint!="/metrics"}[5m])`
  (the `/metrics` scrape traffic is excluded so the ratio reflects real request
  outcomes). The `AvailabilityBelowSLO` alert fires when this drops below `0.99`,
  using the identical expression in `prometheus/alert.rules.yml`.

## Error budget policy

The 1% error budget is the allowed unreliability. While budget remains, normal
feature/deploy work continues. If the budget is exhausted (success rate stays
below 99%), the response is:

1. Freeze risky deploys; prioritise reliability fixes.
2. Follow [INCIDENT-RESPONSE.md](INCIDENT-RESPONSE.md).
3. Use rollback (`make rollback`) to return to the last known-good build.

## Why these targets

This is a demonstration stack, so 99% is a realistic, observable target that the
existing metrics already support — no new instrumentation is required. Alert
thresholds (`HighErrorRate`, `ServiceDown`, `AvailabilityBelowSLO`) are wired to
these same SLIs so the objectives are continuously enforced, not just documented.
