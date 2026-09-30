#!/usr/bin/env bash
# Apply baseline gateway-wide config through the Admin API (idempotent).
#   - global rule: prometheus metrics for every route
source "$(dirname "$0")/lib.sh"

echo "==> global rule 1: prometheus"
admin_api PUT /global_rules/1 '{
  "plugins": {
    "prometheus": { "prefer_name": true }
  }
}' >/dev/null
echo "done"
