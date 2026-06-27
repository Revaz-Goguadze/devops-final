# Single entry point for every common operation. Run `make help` for the list.
.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help setup up down deploy verify rollback security test lint logs alert clean

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

setup: ## One-command bootstrap: config + build + start + verify
	./scripts/setup.sh

up: ## Build and start the full stack
	docker compose up -d --build

down: ## Stop the stack (keep data volumes)
	docker compose down

deploy: ## Deploy a new build with post-deploy verification (auto-rollback on failure)
	./scripts/deploy.sh

verify: ## Run post-deployment health/validation checks
	./scripts/verify.sh

rollback: ## Roll the app back to the last known-good image
	./scripts/rollback.sh

security: ## Run the full security scan suite (Trivy, gitleaks, hadolint, pip-audit)
	./scripts/security-scan.sh

test: ## Run application unit tests
	cd app && pip install -q -r requirements.txt -r requirements-dev.txt && pytest -q

lint: ## Lint the Dockerfile and Python app
	docker run --rm -i hadolint/hadolint < app/Dockerfile

logs: ## Tail logs from all services
	docker compose logs -f

alert: ## Fire the CRITICAL HighErrorRate alert (sends 12 errors)
	./scripts/trigger-alert.sh

clean: ## Stop the stack and remove data volumes
	docker compose down -v
