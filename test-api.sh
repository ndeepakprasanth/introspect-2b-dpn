#!/usr/bin/env bash
set -euo pipefail

# test-api.sh - Test API endpoints

echo "=== Testing Introspect Claims API ==="

# Check if API endpoint is provided
API_ENDPOINT=${1:-}

if [[ -z "$API_ENDPOINT" ]]; then
  echo "Usage: ./test-api.sh <api-endpoint>"
  echo "Example: ./test-api.sh https://abc123.execute-api.us-east-1.amazonaws.com"
  echo ""
  echo "Or use kubectl port-forward:"
  echo "  kubectl port-forward svc/sample-service 8080:8080 -n default &"
  echo "  ./test-api.sh http://localhost:8080"
  exit 1
fi

echo "Testing endpoint: $API_ENDPOINT"
echo ""

# Test 1: Health check
echo "Test 1: Health check (GET /)"
curl -s "$API_ENDPOINT/" | jq . || echo "FAILED"
echo ""

# Test 2: Get claim 1001
echo "Test 2: Get claim 1001 (GET /claims/1001)"
curl -s "$API_ENDPOINT/claims/1001" | jq . || echo "FAILED"
echo ""

# Test 3: Get claim 1002
echo "Test 3: Get claim 1002 (GET /claims/1002)"
curl -s "$API_ENDPOINT/claims/1002" | jq . || echo "FAILED"
echo ""

# Test 4: Get non-existent claim
echo "Test 4: Get non-existent claim (GET /claims/9999)"
curl -s "$API_ENDPOINT/claims/9999" | jq . || echo "FAILED"
echo ""

# Test 5: Summarize claim 1001
echo "Test 5: Summarize claim 1001 (POST /claims/1001/summarize)"
curl -s -X POST "$API_ENDPOINT/claims/1001/summarize" | jq . || echo "FAILED"
echo ""

# Test 6: Summarize claim 1005
echo "Test 6: Summarize claim 1005 (POST /claims/1005/summarize)"
curl -s -X POST "$API_ENDPOINT/claims/1005/summarize" | jq . || echo "FAILED"
echo ""

echo "=== Tests Complete ==="
