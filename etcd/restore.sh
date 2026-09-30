#!/bin/sh
# Runs inside the etcd-restore container (network_mode: none).
# Restores ONE snapshot into the data volumes of all 3 members.
# Invoked by scripts/etcd-restore.sh — do not run while etcd is up.
set -eu

SNAPSHOT="/backups/${1:?usage: restore.sh <snapshot-file-name>}"
[ -f "$SNAPSHOT" ] || { echo "snapshot not found: $SNAPSHOT"; exit 1; }

CLUSTER="etcd-1=http://etcd-1:2380,etcd-2=http://etcd-2:2380,etcd-3=http://etcd-3:2380"
TOKEN="${ETCD_CLUSTER_TOKEN:-apisix-etcd-cluster}-restored-$(date +%s)"

etcdutl snapshot status "$SNAPSHOT" -w table

for m in etcd-1 etcd-2 etcd-3; do
  dir="/data/${m}"
  echo "[restore] ${m}: wiping ${dir} and restoring"
  rm -rf "${dir:?}/member" "${dir:?}/tmp"
  etcdutl snapshot restore "$SNAPSHOT" \
    --name "$m" \
    --initial-cluster "$CLUSTER" \
    --initial-cluster-token "$TOKEN" \
    --initial-advertise-peer-urls "http://${m}:2380" \
    --data-dir "${dir}/tmp"
  mv "${dir}/tmp/member" "${dir}/member"
  rm -rf "${dir}/tmp"
done
echo "[restore] done"
