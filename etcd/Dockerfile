# etcd-tools: alpine + etcdctl/etcdutl copied from the official (distroless) etcd image.
# Used by the one-shot etcd-init (auth bootstrap) and etcd-restore jobs.
ARG ETCD_IMAGE=quay.io/coreos/etcd:v3.7.2
ARG ALPINE_IMAGE=alpine:3.24.2

FROM ${ETCD_IMAGE} AS etcd

FROM ${ALPINE_IMAGE}
COPY --from=etcd /usr/local/bin/etcdctl /usr/local/bin/etcdutl /usr/local/bin/
# scripts are committed with +x; COPY keeps the mode (works without BuildKit)
COPY init-auth.sh restore.sh /scripts/
USER 65534:65534
ENTRYPOINT []
