#!/usr/bin/env bash
# Restore the whole etcd cluster from a snapshot in ./backups.
#   ./scripts/etcd-restore.sh etcd-snapshot-YYYYmmdd-HHMMSS.db
# DESTRUCTIVE: current etcd data in all 3 members is replaced. FORCE=1 skips the prompt.
source "$(dirname "$0")/lib.sh"
snap=${1:?usage: etcd-restore.sh <snapshot file name in ./backups>}
[ -f "backups/${snap}" ] || { echo "backups/${snap} not found"; exit 1; }

if [ "${FORCE:-0}" != 1 ]; then
  read -r -p "This REPLACES all etcd data with ${snap}. Type 'restore' to continue: " ok
  [ "$ok" = restore ] || { echo aborted; exit 1; }
fi

dc stop apisix etcd-1 etcd-2 etcd-3
dc --profile restore run --rm etcd-restore /scripts/restore.sh "${snap}"
dc up -d --wait etcd-1 etcd-2 etcd-3 apisix
echo "restored. Verify: ./scripts/smoke-test.sh"
