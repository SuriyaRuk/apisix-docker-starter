# shellcheck shell=bash
# Shared helpers for scripts/*.sh (sourced, not executed).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
ENV_FILE="${ENV_FILE:-.env}"
[ -f "$ENV_FILE" ] || { echo "missing ${ENV_FILE} — run ./scripts/gen-secrets.sh first"; exit 1; }
set -a; # shellcheck disable=SC1090
. "$ENV_FILE"; set +a

# All compose calls go through this so a non-default ENV_FILE is honoured.
dc() { docker compose --env-file "$ENV_FILE" "$@"; }

ADMIN_URL="http://127.0.0.1:${APISIX_ADMIN_PORT:-9180}/apisix/admin"

# admin_api METHOD PATH [JSON_BODY]
admin_api() {
  local method=$1 path=$2 body=${3:-}
  if [ -n "$body" ]; then
    curl -fsS -X "$method" "${ADMIN_URL}${path}" \
      -H "X-API-KEY: ${APISIX_ADMIN_KEY}" -H 'Content-Type: application/json' -d "$body"
  else
    curl -fsS -X "$method" "${ADMIN_URL}${path}" -H "X-API-KEY: ${APISIX_ADMIN_KEY}"
  fi
}
