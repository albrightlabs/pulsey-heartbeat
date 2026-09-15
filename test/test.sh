#!/usr/bin/env bash
# Runs ping.sh against a local mock server and checks what it sent.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
port=$((20000 + RANDOM % 20000))
log="$(mktemp)"
out="$(mktemp)"
python3 "$here/mock_server.py" "$port" "$log" &
server=$!
trap 'kill $server 2>/dev/null; wait $server 2>/dev/null; rm -f "$log" "$out"' EXIT
for _ in $(seq 1 50); do curl -s "http://127.0.0.1:$port/ready" >/dev/null && break; sleep 0.1; done
: > "$log"

base="http://127.0.0.1:$port/heartbeat/2f1c9b7e-0000-4000-8000-000000000001"
failures=0

run() { env -i PATH="$PATH" GITHUB_OUTPUT="$out" PULSEY_RUN_URL="https://github.com/acme/app/actions/runs/42" PULSEY_RETRIES=0 PULSEY_TIMEOUT=5 "$@" "$here/../ping.sh"; }
last() { tail -n 1 "$log"; }
check() {
  local name="$1" condition="$2"
  if eval "$condition"; then echo "PASS $name"; else echo "FAIL $name"; echo "  log: $(last)"; echo "  output: $(tail -n 1 "$out")"; failures=$((failures + 1)); fi
}

run PULSEY_URL="$base" PULSEY_STATUS=success >/dev/null
check "success pings the heartbeat URL" '[[ "$(last)" == *"\"path\": \"/heartbeat/2f1c9b7e-0000-4000-8000-000000000001\""* && "$(tail -n 1 "$out")" == "http-status=200" ]]'

run PULSEY_URL="$base/" PULSEY_STATUS=failure PULSEY_MESSAGE="Tests failed: 3 of 120 & more" >/dev/null
check "failure pings /fail with the message" '[[ "$(last)" == *"/fail\""* && "$(last)" == *"Tests failed: 3 of 120 & more"* ]]'

run PULSEY_URL="$base/fail" PULSEY_STATUS=failure >/dev/null
check "failure without a message links the run (and /fail isn't doubled)" '[[ "$(last)" == *"/heartbeat/2f1c9b7e-0000-4000-8000-000000000001/fail\""* && "$(last)" == *"actions/runs/42"* ]]'

lines_before="$(wc -l < "$log")"
run PULSEY_URL="$base" PULSEY_STATUS=cancelled >/dev/null
check "cancelled runs are skipped by default" '[[ "$(wc -l < "$log")" == "$lines_before" && "$(tail -n 1 "$out")" == "http-status=" ]]'

run PULSEY_URL="$base" PULSEY_STATUS=cancelled PULSEY_REPORT_CANCELLED=true >/dev/null
check "cancelled runs can be reported as failures" '[[ "$(last)" == *"/fail\""* && "$(last)" == *"Workflow cancelled"* ]]'

run PULSEY_URL="$base" PULSEY_STATUS=maybe >/dev/null 2>&1
code=$?
check "an unknown status fails the step" '[[ $code -ne 0 ]]'
run PULSEY_URL="" >/dev/null 2>&1
code=$?
check "a missing URL fails the step" '[[ $code -ne 0 ]]'

warning="$(run PULSEY_URL="http://127.0.0.1:$port/broken" PULSEY_STATUS=success)"
code=$?
check "a Pulsey error is a warning, not a failed step" '[[ $code -eq 0 && "$warning" == *"::warning::Pulsey returned HTTP 500"* ]]'

unreachable="$(env -i PATH="$PATH" GITHUB_OUTPUT="$out" PULSEY_URL="http://127.0.0.1:1/heartbeat/x" PULSEY_RETRIES=0 PULSEY_TIMEOUT=2 "$here/../ping.sh")"
code=$?
check "an unreachable Pulsey is a warning with status 000" '[[ $code -eq 0 && "$unreachable" == *"HTTP 000"* ]]'

if [[ $failures -eq 0 ]]; then echo "All tests passed."; else echo "$failures test(s) failed."; exit 1; fi
