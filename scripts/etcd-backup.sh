#!/usr/bin/env bash
# Take an etcd snapshot (= all APISIX config) into ./backups and prune old ones.
# Cron example (daily 02:00):
#   0 2 * * * cd /opt/apisix && ./scripts/etcd-backup.sh >> backups/backup.log 2>&1
source "$(dirname "$0")/lib.sh"

name="etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"
dc exec -T etcd-1 etcdctl --user "root:${ETCD_ROOT_PASSWORD}" snapshot save "/backups/${name}"
dc exec -T etcd-1 etcdutl snapshot status "/backups/${name}" -w table
find backups -name 'etcd-snapshot-*.db' -mtime "+${BACKUP_RETENTION_DAYS:-14}" -print -delete
echo "backup: backups/${name}"
echo "NOTE: copy backups/ off-host (S3/NAS). SSL keys inside need APISIX_ENCRYPTION_KEY to decrypt."
