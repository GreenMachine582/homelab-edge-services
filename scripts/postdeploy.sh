#!/usr/bin/env bash
set -euo pipefail

# Pi-hole v6 ignores WEBPASSWORD env var; set the password via the CLI.
docker exec pihole pihole setpassword "${PIHOLE_WEB_PASSWORD}"
