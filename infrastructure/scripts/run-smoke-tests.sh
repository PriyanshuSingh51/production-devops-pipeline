#!/usr/bin/env bash
# Minimal smoke test suite run after every staging/production deploy.
# Exercises the gateway health check and a couple of read-only endpoints.
set -euo pipefail

BASE_URL=${1:-https://api-staging.ecommerce.com}
FAILURES=0

check() {
  local path=$1
  local expected=$2
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}")
  if [ "$status" = "$expected" ]; then
    echo "  ✓ GET ${path} -> ${status}"
  else
    echo "  ✗ GET ${path} -> ${status} (expected ${expected})"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "Running smoke tests against ${BASE_URL}"
check "/actuator/health" "200"
check "/api/products" "200"
check "/api/orders/nonexistent-id" "404"

if [ "$FAILURES" -gt 0 ]; then
  echo "Smoke tests FAILED: ${FAILURES} check(s) did not pass."
  exit 1
fi
echo "All smoke tests passed."
