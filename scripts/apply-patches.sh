#!/usr/bin/env bash
# Copy requirement patches into the Superset 6.1.0 source tree before building.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${PROJECT_DIR}/superset"
PATCHES_DIR="${PROJECT_DIR}/patches"

if [[ ! -d "${SOURCE_DIR}/superset" ]]; then
  echo "Error: Superset source not found at ${SOURCE_DIR}" >&2
  echo "Clone tag 6.1.0 first:" >&2
  echo "  git clone --branch 6.1.0 --depth 1 https://github.com/apache/superset.git superset" >&2
  exit 1
fi

copy_tree() {
  local src="$1"
  local dest_root="$2"
  if [[ ! -d "${src}" ]]; then
    return 0
  fi
  find "${src}" -type f | while read -r file; do
    rel="${file#"${src}/"}"
    dest="${dest_root}/${rel}"
    mkdir -p "$(dirname "${dest}")"
    cp "${file}" "${dest}"
    echo "  patched ${rel}"
  done
}

echo "Applying patches to ${SOURCE_DIR}..."

for req in 03-watermark 06-welcome-dashboard 07-url-prefix; do
  if [[ -d "${PATCHES_DIR}/${req}/superset" ]]; then
    echo "[${req}] backend"
    copy_tree "${PATCHES_DIR}/${req}/superset" "${SOURCE_DIR}/superset"
  fi
  if [[ -d "${PATCHES_DIR}/${req}/superset-frontend" ]]; then
    echo "[${req}] frontend"
    copy_tree "${PATCHES_DIR}/${req}/superset-frontend" "${SOURCE_DIR}/superset-frontend"
  fi
done

echo "Patches applied."
