#!/usr/bin/env bash
# Build the final customized production image (requirements 2–7).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${PROJECT_DIR}/scripts/apply-patches.sh"
"${PROJECT_DIR}/build-clickhouse-image.sh"
