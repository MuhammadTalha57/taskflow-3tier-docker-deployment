#!/usr/bin/env bash
# End-to-end smoke test: browser path -> Web Tier (nginx) -> App Tier (Express) -> DB.
# Usage: scripts/smoke-test.sh [BASE_URL] [TIMEOUT_SECONDS]
#   local : scripts/smoke-test.sh http://localhost:8080
#   AWS   : scripts/smoke-test.sh http://<public-alb-dns>
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
TIMEOUT="${2:-180}"
BASE_URL="${BASE_URL%/}"

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "==> Waiting up to ${TIMEOUT}s for ${BASE_URL}/api/tasks ..."
deadline=$(( $(date +%s) + TIMEOUT ))
until curl -fsS -o /dev/null "${BASE_URL}/api/tasks"; do
  [ "$(date +%s)" -ge "$deadline" ] && fail "service not ready after ${TIMEOUT}s"
  sleep 5
done

echo "==> 1. Web tier liveness (/healthz)"
[ "$(curl -fsS "${BASE_URL}/healthz")" = "ok" ] || fail "/healthz did not return ok"

echo "==> 2. Create a task (POST /api/tasks)"
title="smoke-test-$(date +%s)"
created=$(curl -fsS -X POST "${BASE_URL}/api/tasks" \
  -H 'Content-Type: application/json' -d "{\"title\":\"${title}\"}")
id=$(echo "$created" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
[ -n "$id" ] || fail "no id in response: $created"
echo "    created id=${id}"

echo "==> 3. List tasks contains it (GET /api/tasks)"
curl -fsS "${BASE_URL}/api/tasks" | grep -q "\"${title}\"" || fail "task not listed"

echo "==> 4. Mark done (PUT /api/tasks/${id})"
curl -fsS -X PUT "${BASE_URL}/api/tasks/${id}" \
  -H 'Content-Type: application/json' -d '{"done":true}' | grep -q '"done":true' \
  || fail "update failed"

echo "==> 5. Validation rejects empty title (expect 400)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/api/tasks" \
  -H 'Content-Type: application/json' -d '{"title":""}')
[ "$code" = "400" ] || fail "expected 400, got $code"

echo "==> 6. Delete (DELETE /api/tasks/${id}, expect 204)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "${BASE_URL}/api/tasks/${id}")
[ "$code" = "204" ] || fail "expected 204, got $code"

echo "ALL SMOKE TESTS PASSED against ${BASE_URL}"
