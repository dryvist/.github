#!/usr/bin/env bash
# Start or stop a sidecar container for a GitHub Actions job.
#
# GitHub-hosted runners are a VM: publish a host port. Containerized
# self-hosted runners (the docker-host fleet) have no usable localhost
# port mapping from a `services:` container, so the sidecar joins the
# runner's network namespace instead.
#
# Required env: PHASE (start|stop)
# Start also needs: IMAGE
# Optional: SIDECAR_NAME, EXTRA_ENV (KEY=VALUE lines), PUBLISH

set -euo pipefail

: "${PHASE:?required}"

name="${SIDECAR_NAME:-${SIDECAR_CONTAINER:-sidecar-${GITHUB_RUN_ID:-$$}}}"

case "${PHASE}" in
  start)
    : "${IMAGE:?image is required when phase is start}"
    : "${PUBLISH:?publish is required when phase is start}"
    args=(run -d --name "${name}")
    if docker inspect "$(hostname)" >/dev/null 2>&1; then
      args+=(--network "container:$(hostname)")
    else
      args+=(-p "${PUBLISH}")
    fi
    while IFS= read -r line || [[ -n "${line}" ]]; do
      [[ -z "${line}" ]] && continue
      args+=(-e "${line}")
    done <<< "${EXTRA_ENV:-}"
    args+=("${IMAGE}")
    docker "${args[@]}"
    echo "SIDECAR_CONTAINER=${name}" >> "${GITHUB_ENV}"
    echo "container-name=${name}" >> "${GITHUB_OUTPUT}"
    ;;
  stop)
    docker rm -f "${name}" || true
    ;;
  *)
    echo "PHASE must be start or stop, got ${PHASE}" >&2
    exit 1
    ;;
esac
