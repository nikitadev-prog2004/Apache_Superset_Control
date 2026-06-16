#!/usr/bin/env bash
# Recreate feature branches for separate PRs (see docs/PR-SPLIT.md).
# Run from a clean main branch after initial commit.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not a git repository. Run: git init && git add ... && git commit" >&2
  exit 1
fi

BASE="$(git merge-base HEAD main 2>/dev/null || echo "")"
if [[ -z "${BASE}" ]]; then
  BASE="$(git rev-list --max-parents=0 HEAD | tail -1)"
fi

create_branch() {
  local branch="$1"
  shift
  echo "Creating ${branch}..."
  git checkout -B "${branch}" "${BASE}" 2>/dev/null || git checkout -B "${branch}"
  for path in "$@"; do
    git checkout main -- "${path}" 2>/dev/null || true
  done
  if git diff --cached --quiet && git diff --quiet; then
    echo "  (no changes for ${branch})"
  else
    git add "$@"
    git commit -m "${branch}: deliverable files"
  fi
}

git checkout main

create_branch feat/01-production-base-image \
  build-production-image.sh .gitignore

create_branch feat/02-clickhouse-connect \
  Dockerfile build-clickhouse-image.sh build-custom-image.sh

create_branch feat/03-remove-watermark \
  patches/03-watermark Dockerfile

create_branch feat/04-custom-favicon \
  assets/favicon.png Dockerfile

create_branch feat/05-custom-logo \
  assets/logo.png Dockerfile

create_branch feat/06-welcome-dashboard \
  patches/06-welcome-dashboard config/superset_config.py scripts/post-init.sh Dockerfile

create_branch feat/07-url-without-superset-prefix \
  patches/07-url-prefix templates config/superset_config.py \
  scripts/patch-frontend-urls.sh scripts/verify-welcome-dashboard.sh \
  scripts/verify-url-prefix.sh scripts/apply-patches.sh \
  docker-compose.yml README.md docs/PR-SPLIT.md Makefile

git checkout main
echo "Done. Push branches and open PRs targeting main."
