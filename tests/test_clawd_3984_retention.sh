#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
compose_file=${COMPOSE_FILE:-"$repo_root/docker-compose.yml"}
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT

cp "$compose_file" "$fixture_dir/docker-compose.yml"
mkdir -p "$fixture_dir/apps/api"
: >"$fixture_dir/.env"
: >"$fixture_dir/apps/api/.env"

compose_json=$(
  LISTEN_HTTP_PORT=3000 \
  RABBITMQ_USER=test \
  RABBITMQ_PASSWORD=test \
  RABBITMQ_VHOST=test \
    docker compose -f "$fixture_dir/docker-compose.yml" config --format json
)

python - "$compose_json" <<'PY'
import json
import sys

services = json.loads(sys.argv[1])["services"]
expected = {"api", "worker", "beat-worker"}
actual = {
    name
    for name, config in services.items()
    if config.get("environment", {}).get("API_ACTIVITY_LOG_RETENTION_DAYS") == "1"
}
if actual != expected:
    raise SystemExit(
        "API activity retention consumers mismatch: "
        f"expected={sorted(expected)} actual={sorted(actual)}"
    )
PY

echo "PASS: API activity retention is one day for api, worker, and beat-worker"
