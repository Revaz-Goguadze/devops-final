#!/usr/bin/env bash
# Convenience entry point: start the whole stack locally with one command.
# This is a thin alias for the real bootstrap in scripts/setup.sh (which also
# backs `make setup`) — prereq check, .env from .env.example, build, start, and
# post-deploy verification. Everything runs on Docker Compose; nothing else is
# needed.
#
#   ./run.sh            # start + verify everything
#   make down           # stop (keep data)   |   make clean = stop + wipe volumes
set -euo pipefail
cd "$(dirname "$0")"
exec ./scripts/setup.sh
