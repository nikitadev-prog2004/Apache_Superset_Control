#!/usr/bin/env bash
# Verify requirement 7: URLs work without the /superset/ prefix.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8088}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

extract_csrf() {
  python3 - "$1" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8", errors="ignore").read()
for pattern in (
    r'name="csrf_token"[^>]*value="([^"]+)"',
    r'value="([^"]+)"[^>]*name="csrf_token"',
    r'"csrf_token"\s*:\s*"([^"]+)"',
):
    match = re.search(pattern, html)
    if match:
        print(match.group(1))
        break
PY
}

login() {
  local username="$1"
  local password="$2"
  local cookie_jar login_html csrf_token

  cookie_jar="$(mktemp)"
  login_html="$(mktemp)"
  trap 'rm -f "${cookie_jar}" "${login_html}"' RETURN

  curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
    "${BASE_URL}/login/" -o "${login_html}"
  csrf_token="$(extract_csrf "${login_html}")"

  if [[ -z "${csrf_token}" ]]; then
    echo "FAIL: could not read CSRF token from login page" >&2
    return 1
  fi

  curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
    -o /dev/null \
    -X POST "${BASE_URL}/login/" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "username=${username}" \
    --data-urlencode "password=${password}" \
    --data-urlencode 'provider=db' \
    --data-urlencode "csrf_token=${csrf_token}"

  echo "${cookie_jar}"
}

check_url() {
  local cookie_jar="$1"
  local path="$2"
  local label="$3"
  local status redirect

  status="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o "/tmp/superset-url-check.html" \
      -w '%{http_code}' \
      "${BASE_URL}${path}"
  )"
  redirect="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o /dev/null -w '%{url_effective}' \
      "${BASE_URL}${path}"
  )"

  echo "  ${label}: HTTP ${status}, URL ${redirect}"

  if [[ "${redirect}" == *"/superset/"* ]]; then
    echo "FAIL: ${label} still contains /superset/ prefix" >&2
    return 1
  fi

  if [[ "${status}" != "200" && "${status}" != "302" ]]; then
    echo "FAIL: ${label} returned HTTP ${status}" >&2
    return 1
  fi
}

check_legacy_redirect() {
  local cookie_jar="$1"
  local legacy_path="$2"
  local expected_path="$3"
  local status location

  status="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o /dev/null -w '%{http_code}' \
      "${BASE_URL}${legacy_path}"
  )"
  location="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o /dev/null -D - "${BASE_URL}${legacy_path}" \
      | awk 'tolower($1)=="location:" {print $2}' | tr -d '\r' | head -1
  )"

  echo "  legacy ${legacy_path} -> HTTP ${status}, Location ${location:-<none>}"

  if [[ "${status}" != "301" && "${status}" != "302" ]]; then
    echo "FAIL: expected redirect from ${legacy_path}" >&2
    return 1
  fi

  if [[ "${location}" != *"${expected_path}"* ]]; then
    echo "FAIL: legacy redirect target unexpected for ${legacy_path}" >&2
    return 1
  fi
}

echo "Checking prefix-free URLs..."
cookie_jar="$(login "${ADMIN_USER}" "${ADMIN_PASSWORD}")"

check_url "${cookie_jar}" "/welcome/" "welcome page"
check_url "${cookie_jar}" "/dashboard/world_health/" "dashboard by slug"

echo
echo "Checking legacy /superset/* redirects..."
check_legacy_redirect "${cookie_jar}" "/superset/welcome/" "/welcome/"
check_legacy_redirect "${cookie_jar}" "/superset/dashboard/world_health/" "/dashboard/world_health/"

echo
echo "All URL prefix checks passed."
