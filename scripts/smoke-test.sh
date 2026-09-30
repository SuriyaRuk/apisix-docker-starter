#!/usr/bin/env bash
# End-to-end check: Admin API -> etcd -> route -> upstream -> response -> metrics.
# Needs the demo upstream:  docker compose --profile demo up -d demo-upstream
#   KEEP=1 ./scripts/smoke-test.sh   keeps the demo route afterwards
source "$(dirname "$0")/lib.sh"
GW="http://127.0.0.1:${APISIX_HTTP_PORT:-80}"
pass() { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; exit 1; }

echo "==> Admin API auth"
code=$(curl -s -o /dev/null -w '%{http_code}' "${ADMIN_URL}/routes")
[ "$code" = 401 ] && pass "no key -> 401" || fail "expected 401 without key, got $code"
admin_api GET /routes >/dev/null && pass "admin key accepted"
code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "${ADMIN_URL}/routes/x" \
  -H "X-API-KEY: ${APISIX_VIEWER_KEY}" -H 'Content-Type: application/json' -d '{"uri":"/x","upstream":{"nodes":{"127.0.0.1:1":1}}}')
if [ "$code" = 401 ] || [ "$code" = 403 ]; then pass "viewer key cannot write ($code)"; else fail "viewer write returned $code"; fi

echo "==> create demo upstream + route"
admin_api PUT /upstreams/smoke-demo '{
  "name": "smoke-demo", "type": "roundrobin", "scheme": "http",
  "nodes": { "demo-upstream:80": 1 },
  "timeout": { "connect": 3, "send": 10, "read": 10 },
  "checks": { "active": { "type": "http", "http_path": "/",
    "healthy": { "interval": 5, "successes": 1 },
    "unhealthy": { "interval": 5, "http_failures": 2 } } }
}' >/dev/null && pass "upstream"
admin_api PUT /routes/smoke-demo '{
  "name": "smoke-demo", "uri": "/smoke/*",
  "plugins": {
    "proxy-rewrite": { "regex_uri": ["^/smoke/(.*)", "/$1"] },
    "limit-count": { "count": 100, "time_window": 60, "rejected_code": 429, "key_type": "var", "key": "remote_addr" }
  },
  "upstream_id": "smoke-demo"
}' >/dev/null && pass "route"

echo "==> proxy traffic"
code=000
for _ in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "${GW}/smoke/")
  [ "$code" = 200 ] && break; sleep 0.5
done
[ "$code" = 200 ] && pass "GET /smoke/ -> 200" || fail "GET /smoke/ -> $code"
code=$(curl -s -o /dev/null -w '%{http_code}' "${GW}/no-such-route")
[ "$code" = 404 ] && pass "unknown route -> 404" || fail "unknown route -> $code"

echo "==> metrics (exporter caches for plugin_attr.prometheus.refresh_interval = 15s)"
metrics() {
  dc exec -T apisix bash -c 'exec 3<>/dev/tcp/127.0.0.1/9091; printf "GET /apisix/prometheus/metrics HTTP/1.0\r\n\r\n" >&3; cat <&3'
}
found=0
for _ in $(seq 1 15); do
  if metrics | grep -q '^apisix_http_status{.*route="smoke-demo"'; then found=1; break; fi
  sleep 2
done
[ "$found" = 1 ] && pass "apisix_http_status{route=smoke-demo} exported" \
  || fail "no apisix_http_status metric for smoke-demo (did you run scripts/bootstrap.sh?)"
metrics | grep -q '^apisix_etcd_reachable 1' && pass "apisix_etcd_reachable = 1" || fail "APISIX reports etcd unreachable"

if [ "${KEEP:-0}" != 1 ]; then
  echo "==> cleanup"
  admin_api DELETE /routes/smoke-demo >/dev/null
  admin_api DELETE /upstreams/smoke-demo >/dev/null
  pass "demo route/upstream removed"
fi
echo "ALL CHECKS PASSED"
