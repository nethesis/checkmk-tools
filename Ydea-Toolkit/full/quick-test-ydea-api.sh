#!/usr/bin/env bash

set -euo pipefail

# quick-test-ydea-api.sh - Test rapido connessione API Ydea

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YDEA_TOOLKIT="${SCRIPT_DIR}/ydea-toolkit.sh"

source "$YDEA_TOOLKIT"

echo ""
echo "Testing Ydea API Connection"
echo "========================================="
echo ""

echo "Test 1: Checking configuration..."
if [[ -z "${YDEA_ID:-}" || "${YDEA_ID}" == "ID" ]]; then
  echo "ERROR: YDEA_ID not configured"
  echo "Edit .env and set YDEA_ID"
  exit 1
fi

if [[ -z "${YDEA_API_KEY:-}" || "${YDEA_API_KEY}" == "TOKEN" ]]; then
  echo "ERROR: YDEA_API_KEY not configured"
  echo "Edit .env and set YDEA_API_KEY"
  exit 1
fi

echo "✓ Variables configured:"
echo "   YDEA_ID: ${YDEA_ID}"
echo "   YDEA_API_KEY: ${YDEA_API_KEY:0:10}..."
echo ""

echo "Test 2: Authentication..."
if ! ensure_token 2>&1; then
  echo "ERROR: Authentication failed"
  echo "Check YDEA_ID and YDEA_API_KEY in .env"
  exit 1
fi

echo "✓ Authentication successful"
echo ""

echo "Test 3: Testing categories API..."
categories_data=$(ydea_api GET "/categories" 2>&1) || true

if ! echo "$categories_data" | jq empty 2>/dev/null; then
  echo "ERROR: Response is not valid JSON"
  echo ""
  echo "Response:"
  echo "$categories_data" | head -30
  exit 1
fi

if echo "$categories_data" | jq -e 'has("error")' >/dev/null 2>&1; then
  echo "ERROR: API error response"
  echo "$categories_data" | jq '.'
  exit 1
fi

cat_count=$(echo "$categories_data" | jq -r '.objs | length' 2>/dev/null || echo "0")
echo "✓ Categories API working - $cat_count found"
echo ""

echo "Test 4: Testing tickets API..."
tickets_data=$(ydea_api GET "/tickets?limit=1" 2>&1) || true

if echo "$tickets_data" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: Tickets API error"
  echo "$tickets_data" | head -20
  exit 1
fi

echo "✓ Tickets API working"
echo ""

echo "Test 5: Testing users API..."
users_data=$(ydea_api GET "/users?limit=1" 2>&1) || true

if echo "$users_data" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: Users API error"
  echo "$users_data" | head -20
  exit 1
fi

echo "✓ Users API working"
echo ""

echo "========================================="
echo "✓ All tests passed!"
echo ""
echo "You can now run:"
echo "   ./ydea-discover-sla-ids.sh"
echo ""
