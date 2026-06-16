#!/usr/bin/env bash
# Build production Docker image for Apache Superset 6.1.0 from source.
# Uses the official multi-stage Dockerfile with the "lean" target (production preset).

set -euo pipefail

SUPERSET_VERSION="6.1.0"
IMAGE_NAME="${IMAGE_NAME:-superset}"
IMAGE_TAG="${IMAGE_TAG:-${SUPERSET_VERSION}}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${PROJECT_DIR}/superset"
BUILD_DIR="${PROJECT_DIR}/.build"
PATCHED_DOCKERFILE="${BUILD_DIR}/Dockerfile.production"
BUILD_LOG="${BUILD_LOG:-/tmp/superset-build.log}"
BUILDX_PLUGIN="${HOME}/.docker/cli-plugins/docker-buildx"
BUILDX_VERSION="v0.23.0"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH." >&2
  echo "Install Docker Engine, then re-run this script." >&2
  exit 1
fi

ensure_buildkit() {
  if docker buildx version >/dev/null 2>&1; then
    return 0
  fi

  echo "BuildKit/buildx is required (Dockerfile uses --mount cache mounts)." >&2
  echo "Installing docker-buildx plugin to ${BUILDX_PLUGIN}..." >&2

  mkdir -p "$(dirname "${BUILDX_PLUGIN}")"
  curl -fsSL \
    "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
    -o "${BUILDX_PLUGIN}"
  chmod +x "${BUILDX_PLUGIN}"

  if ! docker buildx version >/dev/null 2>&1; then
    echo "Error: docker buildx is still unavailable after install." >&2
    echo "Try: sudo apt install -y docker-buildx" >&2
    exit 1
  fi
}

docker_invoke() {
  if docker info >/dev/null 2>&1; then
    env DOCKER_BUILDKIT=1 docker "$@"
  elif id -nG "${USER}" | grep -qw docker; then
    echo "Note: current shell lacks docker group; using 'sg docker'." >&2
    echo "      Run 'newgrp docker' or log out/in to avoid this message." >&2
    sg docker -c "DOCKER_BUILDKIT=1 docker $(printf '%q ' "$@")"
  else
    echo "Error: permission denied on /var/run/docker.sock." >&2
    echo "Run: sudo usermod -aG docker \"\${USER}\" && newgrp docker" >&2
    exit 1
  fi
}

prepare_dockerfile() {
  mkdir -p "${BUILD_DIR}"
  python3 - "${SOURCE_DIR}/Dockerfile" "${PATCHED_DOCKERFILE}" <<'PY'
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
text = src.read_text()

text = text.replace("node:20-trixie-slim", "node:22-trixie-slim")

npm_env = """
# Harden npm ci against transient registry network issues (EIDLETIMEOUT, ECONNRESET)
ENV npm_config_fetch_retries=5 \\
    npm_config_fetch_retry_mintimeout=20000 \\
    npm_config_fetch_retry_maxtimeout=120000 \\
    npm_config_fetch_timeout=600000
"""
needle = "    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true\n"
if needle in text and "npm_config_fetch_retries" not in text:
    text = text.replace(needle, needle + npm_env)

text = text.replace(
    "        npm ci; \\",
    '        for attempt in 1 2 3 4 5; do npm ci && break || { echo "npm ci failed (attempt ${attempt}), retrying..."; sleep 30; }; done; \\',
)

dst.write_text(text)
PY
}

ensure_buildkit

cd "${SOURCE_DIR}"

current_ref="$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)"
if [[ "${current_ref}" != "${SUPERSET_VERSION}" ]]; then
  echo "Checking out source tag ${SUPERSET_VERSION}..."
  git checkout "${SUPERSET_VERSION}"
fi

prepare_dockerfile

echo "Building production image ${IMAGE_NAME}:${IMAGE_TAG} from ${SUPERSET_VERSION} source..."
echo "Build context: ${SOURCE_DIR}"
echo "Dockerfile: ${PATCHED_DOCKERFILE}"
echo "Log file: ${BUILD_LOG}"

docker_invoke build \
  --file "${PATCHED_DOCKERFILE}" \
  --target lean \
  --build-arg DEV_MODE=false \
  --build-arg BUILD_TRANSLATIONS=false \
  --build-arg INCLUDE_CHROMIUM=false \
  --build-arg INCLUDE_FIREFOX=false \
  --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
  --tag "${IMAGE_NAME}:production" \
  . 2>&1 | tee "${BUILD_LOG}"

echo
echo "Production image built successfully:"
docker_invoke images "${IMAGE_NAME}:${IMAGE_TAG}"
