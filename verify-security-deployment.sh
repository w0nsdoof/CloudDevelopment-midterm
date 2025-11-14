#!/bin/bash
# Verify security deployment

SERVICE="secure"
echo "Verifying secure deployment: "

echo "1. Checking service status..."
gcloud app services describe 

echo "2. Checking service account..."
gcloud app services describe  --format="value(serviceAccount)"

echo "3. Testing deployment..."
APP_URL="https://-dot-gcp-as3-assignment.uc.r.appspot.com"
curl -s "/api/status" | jq .

echo "4. Running security tests..."
./test-security.sh  gcp-as3-assignment

echo "✅ Verification completed"
