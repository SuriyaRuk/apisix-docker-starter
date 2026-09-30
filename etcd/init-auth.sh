#!/bin/sh
# Bootstrap etcd RBAC for APISIX. Safe to run on every `docker compose up`.
#   - root user (cluster admin, used only for maintenance/backup)
#   - apisix user with readwrite on the APISIX prefix only (least privilege)
#   - healthcheck user with no roles (Docker healthcheck)
#   - auth enable
set -eu

: "${ETCDCTL_ENDPOINTS:?}" "${ETCD_ROOT_PASSWORD:?}" "${ETCD_APISIX_PASSWORD:?}"
APISIX_USER="${ETCD_APISIX_USER:-apisix}"
PREFIX="${ETCD_APISIX_PREFIX:-/apisix}"
export ETCDCTL_ENDPOINTS

log() { echo "[etcd-init] $*"; }

if etcdctl auth status 2>/dev/null | grep -q "Authentication Status: true"; then
  AUTH_ENABLED=true
  ROOT="--user=root:${ETCD_ROOT_PASSWORD}"
  etcdctl "$ROOT" user get root >/dev/null \
    || { log "ERROR: auth is enabled but ETCD_ROOT_PASSWORD is wrong"; exit 1; }
else
  AUTH_ENABLED=false
  ROOT=""
fi
ctl() { if [ -n "$ROOT" ]; then etcdctl "$ROOT" "$@"; else etcdctl "$@"; fi; }

log "auth enabled: ${AUTH_ENABLED}"

# root user + root role
if ! ctl user get root >/dev/null 2>&1; then
  log "creating root user"
  ctl user add root --interactive=false --new-user-password="${ETCD_ROOT_PASSWORD}" >/dev/null
fi
ctl user grant-role root root >/dev/null 2>&1 || true

# apisix role: readwrite on PREFIX only
if ! ctl role get "${APISIX_USER}" >/dev/null 2>&1; then
  log "creating role ${APISIX_USER}"
  ctl role add "${APISIX_USER}" >/dev/null
fi
ctl role grant-permission "${APISIX_USER}" --prefix=true readwrite "${PREFIX}" >/dev/null

# apisix user (password is re-synced from .env on every run)
if ctl user get "${APISIX_USER}" >/dev/null 2>&1; then
  # `user passwd` has no --new-user-password flag; with --interactive=false it reads stdin.
  printf '%s\n' "${ETCD_APISIX_PASSWORD}" | ctl user passwd "${APISIX_USER}" --interactive=false >/dev/null
else
  log "creating user ${APISIX_USER}"
  ctl user add "${APISIX_USER}" --interactive=false --new-user-password="${ETCD_APISIX_PASSWORD}" >/dev/null
fi
ctl user grant-role "${APISIX_USER}" "${APISIX_USER}" >/dev/null 2>&1 || true

# healthcheck user: NO roles on purpose (used by the Docker healthcheck only)
if ctl user get healthcheck >/dev/null 2>&1; then
  printf '%s\n' "${ETCD_HEALTHCHECK_PASSWORD:-healthcheck}" | ctl user passwd healthcheck --interactive=false >/dev/null
else
  log "creating user healthcheck (no roles)"
  ctl user add healthcheck --interactive=false --new-user-password="${ETCD_HEALTHCHECK_PASSWORD:-healthcheck}" >/dev/null
fi

if [ "${AUTH_ENABLED}" = false ]; then
  log "enabling auth"
  etcdctl auth enable >/dev/null
fi

log "done — cluster members:"
etcdctl --user="root:${ETCD_ROOT_PASSWORD}" endpoint status -w table
