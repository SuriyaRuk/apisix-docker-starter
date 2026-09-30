#!/usr/bin/env bash
# Upload/replace a TLS certificate in APISIX (private key is stored encrypted in etcd).
#   ./scripts/upload-ssl.sh <id> <fullchain.pem> <privkey.pem> <sni> [<sni> ...]
#   e.g. ./scripts/upload-ssl.sh api-example-com fullchain.pem privkey.pem api.example.com '*.api.example.com'
source "$(dirname "$0")/lib.sh"
command -v jq >/dev/null || { echo "jq is required"; exit 1; }
[ $# -ge 4 ] || { sed -n 2,4p "$0"; exit 1; }

id=$1 cert=$2 key=$3; shift 3
body=$(jq -n --rawfile cert "$cert" --rawfile key "$key" \
  --argjson snis "$(printf '%s\n' "$@" | jq -R . | jq -s .)" \
  '{type:"server", cert:$cert, key:$key, snis:$snis}')
admin_api PUT "/ssls/${id}" "$body" | jq '{key: .key, snis: .value.snis, validity_end: .value.validity_end}'
