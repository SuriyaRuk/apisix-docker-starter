#!/usr/bin/env bash
# Create the env file (default .env) from env.example and replace every
# __GENERATE__ placeholder with a random secret. Existing values are kept.
#   ENV_FILE=/path/to/other.env ./scripts/gen-secrets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${ENV_FILE:-.env}"

command -v openssl >/dev/null || { echo "openssl is required"; exit 1; }
[ -f "$ENV_FILE" ] || cp env.example "$ENV_FILE"

tmp="$(mktemp)"
while IFS= read -r line; do
  if [[ "$line" =~ ^([A-Z0-9_]+)=__GENERATE__$ ]]; then
    # 32 hex chars = 128-bit secret; also the exact length AES-256 needs.
    line="${BASH_REMATCH[1]}=$(openssl rand -hex 16)"
    echo "generated ${BASH_REMATCH[1]}" >&2
  fi
  printf '%s\n' "$line"
done < "$ENV_FILE" > "$tmp"
mv "$tmp" "$ENV_FILE"
chmod 600 "$ENV_FILE"
echo "${ENV_FILE} ready (mode 600). Back up APISIX_ENCRYPTION_KEY and ETCD_ROOT_PASSWORD securely."
