#!/usr/bin/env bash
# Verify requirements 6 & 7: /welcome/ opens a dashboard without /superset/ prefix.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8088}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
GAMMA_USER="${GAMMA_USER:-gamma}"
GAMMA_PASSWORD="${GAMMA_PASSWORD:-gamma}"

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

login_and_check() {
  local username="$1"
  local password="$2"
  local cookie_jar login_html csrf_token login_status welcome_status welcome_redirect

  cookie_jar="$(mktemp)"
  login_html="$(mktemp)"
  trap 'rm -f "${cookie_jar}" "${login_html}"' RETURN

  echo "Checking welcome page for user '${username}'..."

  curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
    "${BASE_URL}/login/" -o "${login_html}"
  csrf_token="$(extract_csrf "${login_html}")"

  if [[ -z "${csrf_token}" ]]; then
    echo "FAIL: could not read CSRF token from login page" >&2
    return 1
  fi

  login_status="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o /dev/null -w '%{http_code}' \
      -X POST "${BASE_URL}/login/" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "username=${username}" \
      --data-urlencode "password=${password}" \
      --data-urlencode 'provider=db' \
      --data-urlencode "csrf_token=${csrf_token}"
  )"

  welcome_status="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o "/tmp/superset-welcome-${username}.html" \
      -w '%{http_code}' \
      -L "${BASE_URL}/welcome/"
  )"
  welcome_redirect="$(
    curl -sS -c "${cookie_jar}" -b "${cookie_jar}" \
      -o /dev/null -w '%{url_effective}' \
      -L "${BASE_URL}/welcome/"
  )"

  echo "  login HTTP: ${login_status}"
  echo "  welcome HTTP: ${welcome_status}"
  echo "  final URL: ${welcome_redirect}"

  if [[ "${welcome_status}" != "200" ]]; then
    echo "FAIL: /welcome/ returned HTTP ${welcome_status} for ${username}" >&2
    return 1
  fi

  if [[ "${welcome_redirect}" != *"/dashboard/"* ]]; then
    echo "FAIL: /welcome/ did not redirect to a dashboard for ${username}" >&2
    return 1
  fi

  if grep -qi "World Bank\|dashboard" "/tmp/superset-welcome-${username}.html"; then
    echo "  dashboard page loaded"
  fi

  if [[ "${welcome_redirect}" == *"/superset/"* ]]; then
    echo "FAIL: welcome URL still contains /superset/ prefix for ${username}" >&2
    return 1
  fi

  echo "PASS: ${username} opens dashboard from /welcome/"
}

login_and_check "${ADMIN_USER}" "${ADMIN_PASSWORD}"
login_and_check "${GAMMA_USER}" "${GAMMA_PASSWORD}"

echo
echo "All welcome-page checks passed."
