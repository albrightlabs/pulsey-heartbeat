#!/usr/bin/env bash
# Sends a Pulsey heartbeat: success pings the heartbeat URL, failure pings URL/fail.
# Configured through PULSEY_* environment variables (see action.yml). A Pulsey error
# is reported as a warning and never fails the workflow.
set -euo pipefail

url="${PULSEY_URL:-}"
status="${PULSEY_STATUS:-success}"
message="${PULSEY_MESSAGE:-}"
report_cancelled="${PULSEY_REPORT_CANCELLED:-false}"
retries="${PULSEY_RETRIES:-3}"
timeout="${PULSEY_TIMEOUT:-10}"
output="${GITHUB_OUTPUT:-/dev/null}"

if [[ -z "$url" ]]; then
  echo "::error::The url input is required: the heartbeat URL from Pulsey."
  exit 1
fi

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "::add-mask::$url"
fi

url="${url%/}"
url="${url%/fail}"

case "$status" in
  success)
    target="$url"
    message=""
    ;;
  failure)
    target="$url/fail"
    message="${message:-Workflow failed: ${PULSEY_RUN_URL:-}}"
    ;;
  cancelled)
    if [[ "$report_cancelled" != "true" ]]; then
      echo "The run was cancelled; not reporting it to Pulsey."
      echo "http-status=" >> "$output"
      exit 0
    fi
    target="$url/fail"
    message="${message:-Workflow cancelled: ${PULSEY_RUN_URL:-}}"
    ;;
  *)
    echo "::error::status must be success, failure or cancelled (got \"$status\")."
    exit 1
    ;;
esac

args=(-sS -o /dev/null -w '%{http_code}' --max-time "$timeout" --retry "$retries" --retry-delay 2 --retry-all-errors -X POST)
if [[ -n "$message" ]]; then
  args+=(--data-urlencode "message=${message:0:500}")
fi

code="$(curl "${args[@]}" "$target" 2>/dev/null)" || code="${code:-000}"
echo "http-status=$code" >> "$output"

if [[ "$code" =~ ^2 ]]; then
  echo "Pulsey heartbeat sent ($status)."
else
  echo "::warning::Pulsey returned HTTP $code, so this $status may not have been recorded."
fi
