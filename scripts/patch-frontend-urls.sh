#!/usr/bin/env bash
# Patch pre-built frontend bundles to remove the /superset/ URL prefix.
set -euo pipefail

STATIC_DIR="${1:-/app/superset/static/assets}"

if [[ ! -d "${STATIC_DIR}" ]]; then
  echo "Error: static assets directory not found: ${STATIC_DIR}" >&2
  exit 1
fi

echo "Patching frontend bundles in ${STATIC_DIR}..."

find "${STATIC_DIR}" -name '*.js' -type f -print0 | while IFS= read -r -d '' file; do
  sed -i \
    -e 's|/superset/dashboard/|/dashboard/|g' \
    -e 's|/superset/dashboard|/dashboard|g' \
    -e 's|/superset/welcome/|/welcome/|g' \
    -e 's|/superset/welcome|/welcome|g' \
    -e 's|/superset/file-handler|/file-handler|g' \
    -e 's|/superset/explore/p|/explore/p|g' \
    -e 's|/superset/all_entities/|/all_entities/|g' \
    -e 's|/superset/tags/|/tags/|g' \
    -e 's|/superset/log/|/log/|g' \
    -e 's|/superset/explore_json/|/explore_json/|g' \
    -e 's|/superset/language_pack/|/language_pack/|g' \
    -e 's|/superset/fetch_datasource_metadata|/fetch_datasource_metadata|g' \
    -e 's|/superset/sql/|/sql/|g' \
    -e 's|/superset/slice/|/slice/|g' \
    "${file}"
done

echo "Frontend URL patch complete."
