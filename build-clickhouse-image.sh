#!/usr/bin/env bash
# Requirement 2: add clickhouse-connect to the production Superset image.

set -euo pipefail

SUPERSET_VERSION="6.1.0"
BASE_IMAGE="${BASE_IMAGE:-superset:${SUPERSET_VERSION}}"
IMAGE_NAME="${IMAGE_NAME:-superset}"
IMAGE_TAG="${IMAGE_TAG:-${SUPERSET_VERSION}}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH." >&2
  exit 1
fi

docker_invoke() {
  if docker info >/dev/null 2>&1; then
    env DOCKER_BUILDKIT=1 docker "$@"
  elif id -nG "${USER}" | grep -qw docker; then
    sg docker -c "DOCKER_BUILDKIT=1 docker $(printf '%q ' "$@")"
  else
    echo "Error: permission denied on /var/run/docker.sock." >&2
    exit 1
  fi
}

if ! docker_invoke image inspect "${BASE_IMAGE}" >/dev/null 2>&1; then
  echo "Error: base image '${BASE_IMAGE}' not found." >&2
  echo "Run ./build-production-image.sh first." >&2
  exit 1
fi

echo "Building ${IMAGE_NAME}:${IMAGE_TAG} from ${BASE_IMAGE} with clickhouse-connect..."

docker_invoke build \
  --file "${PROJECT_DIR}/Dockerfile" \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
  --tag "${IMAGE_NAME}:production" \
  "${PROJECT_DIR}"

echo
echo "Image built successfully:"
docker_invoke images "${IMAGE_NAME}:${IMAGE_TAG}"

echo
echo "Verifying clickhouse-connect installation..."
docker_invoke run --rm "${IMAGE_NAME}:${IMAGE_TAG}" \
  python -c "import importlib.metadata as m; print('clickhouse-connect', m.version('clickhouse-connect'))"
