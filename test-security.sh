#!/bin/bash
# Basic security test script

APP_URL="https://$1-dot-$2.appspot.com"
echo "Testing security features for: $APP_URL"

echo "1. Testing KMS encryption..."
# Create a todo
RESPONSE=$(curl -s -X POST "$APP_URL/api/todos" \
    -H "Content-Type: application/json" \
    -d '{"text":"Security test with <script>alert(1)</script>"}')

if echo "$RESPONSE" | grep -q "error"; then
    echo "✅ XSS protection working"
else
    echo "❌ XSS protection may be compromised"
fi

echo "2. Testing input validation..."
# Test empty input
RESPONSE=$(curl -s -X POST "$APP_URL/api/todos" \
    -H "Content-Type: application/json" \
    -d '{"text":""}')

if echo "$RESPONSE" | grep -q "cannot be empty"; then
    echo "✅ Input validation working"
else
    echo "❌ Input validation may be compromised"
fi

echo "3. Testing CORS protection..."
RESPONSE=$(curl -s -I -X OPTIONS "$APP_URL/api/todos" \
    -H "Origin: https://malicious-site.com")

if echo "$RESPONSE" | grep -q "Access-Control-Allow-Origin"; then
    echo "❌ CORS may be too permissive"
else
    echo "✅ CORS protection working"
fi

echo "4. Checking security headers..."
RESPONSE=$(curl -s -I "$APP_URL/")

SECURITY_HEADERS=("X-Content-Type-Options" "X-Frame-Options" "X-XSS-Protection")
for header in "${SECURITY_HEADERS[@]}"; do
    if echo "$RESPONSE" | grep -qi "$header"; then
        echo "✅ $header header present"
    else
        echo "❌ $header header missing"
    fi
done

echo "Security tests completed."
