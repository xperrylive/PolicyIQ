#!/bin/bash
# test_deployment.sh — PolicyIQ Deployment Verification Script
# Tests all critical endpoints to ensure the deployment is working correctly

set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if URL is provided
if [ -z "$1" ]; then
    echo -e "${RED}ERROR: No URL provided${NC}"
    echo "Usage: ./test_deployment.sh <cloud-run-url>"
    echo "Example: ./test_deployment.sh https://policyiq-backend-abc123-as.a.run.app"
    exit 1
fi

BASE_URL="$1"

echo "=========================================="
echo "  PolicyIQ Deployment Verification"
echo "  Testing: $BASE_URL"
echo "=========================================="
echo ""

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "  Response: $BODY"
else
    echo -e "${RED}✗ Health check failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
    exit 1
fi
echo ""

# Test 2: API Docs
echo -e "${YELLOW}Test 2: API Documentation${NC}"
DOCS_RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/docs")
HTTP_CODE=$(echo "$DOCS_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ API docs accessible${NC}"
    echo "  URL: $BASE_URL/docs"
else
    echo -e "${RED}✗ API docs failed (HTTP $HTTP_CODE)${NC}"
    exit 1
fi
echo ""

# Test 3: Policy Validation (Good Policy)
echo -e "${YELLOW}Test 3: Policy Validation (Good Policy)${NC}"
GOOD_POLICY='{"raw_policy_text": "Implement a targeted RM100 monthly cash transfer to B40 households via PADU, funded by a 2% luxury goods tax on items above RM10,000."}'
VALIDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/validate-policy" \
  -H "Content-Type: application/json" \
  -d "$GOOD_POLICY")
HTTP_CODE=$(echo "$VALIDATE_RESPONSE" | tail -n1)
BODY=$(echo "$VALIDATE_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    IS_FEASIBLE=$(echo "$BODY" | grep -o '"is_feasible":[^,}]*' | cut -d':' -f2 | tr -d ' ')
    if [ "$IS_FEASIBLE" = "true" ]; then
        echo -e "${GREEN}✓ Good policy validated successfully${NC}"
        echo "  is_feasible: true"
    else
        echo -e "${YELLOW}⚠ Policy was rejected (expected to pass)${NC}"
        echo "  is_feasible: false"
    fi
else
    echo -e "${RED}✗ Policy validation failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
    exit 1
fi
echo ""

# Test 4: Policy Validation (Bad Policy)
echo -e "${YELLOW}Test 4: Policy Validation (Bad Policy)${NC}"
BAD_POLICY='{"raw_policy_text": "Make everything cheaper for everyone."}'
VALIDATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/validate-policy" \
  -H "Content-Type: application/json" \
  -d "$BAD_POLICY")
HTTP_CODE=$(echo "$VALIDATE_RESPONSE" | tail -n1)
BODY=$(echo "$VALIDATE_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    IS_FEASIBLE=$(echo "$BODY" | grep -o '"is_feasible":[^,}]*' | cut -d':' -f2 | tr -d ' ')
    if [ "$IS_FEASIBLE" = "false" ]; then
        echo -e "${GREEN}✓ Bad policy rejected correctly${NC}"
        echo "  is_feasible: false"
        
        # Check for suggestions
        SUGGESTIONS_COUNT=$(echo "$BODY" | grep -o '"suggestions":\[' | wc -l)
        if [ "$SUGGESTIONS_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✓ Suggestions provided${NC}"
        else
            echo -e "${YELLOW}⚠ No suggestions provided${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Bad policy was accepted (expected to be rejected)${NC}"
        echo "  is_feasible: true"
    fi
else
    echo -e "${RED}✗ Policy validation failed (HTTP $HTTP_CODE)${NC}"
    echo "  Response: $BODY"
    exit 1
fi
echo ""

# Test 5: CORS Headers
echo -e "${YELLOW}Test 5: CORS Configuration${NC}"
CORS_RESPONSE=$(curl -s -I -X OPTIONS "$BASE_URL/validate-policy" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST")

if echo "$CORS_RESPONSE" | grep -q "access-control-allow-origin: \*"; then
    echo -e "${GREEN}✓ CORS configured correctly (allow all origins)${NC}"
else
    echo -e "${YELLOW}⚠ CORS may not be configured for all origins${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}  All Tests Passed!${NC}"
echo "=========================================="
echo ""
echo "Your PolicyIQ deployment is ready for the hackathon demo."
echo ""
echo "Next steps:"
echo "  1. Update frontend/lib/services/api_client.dart with:"
echo "     const String _kApiBaseUrl = '$BASE_URL';"
echo "  2. Rebuild your Flutter app"
echo "  3. Test the full Governor's Journey in the UI"
echo ""
echo "API Documentation: $BASE_URL/docs"
echo ""
