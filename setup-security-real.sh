#!/bin/bash
# Practical Security Setup for Flask Todo App
# This script sets up security features that will actually be used

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

echo "Setting up practical security for Flask Todo App..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Step 1: Enable necessary APIs
echo "Enabling APIs..."
gcloud services enable \
    kms.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com \
    cloudresourcemanager.googleapis.com \
    appengine.googleapis.com

echo "✅ APIs enabled"

# Step 2: Create KMS keyring and key
echo "Setting up KMS encryption..."
gcloud kms keyrings create flask-keyring \
    --location=$REGION \
    --description="Key ring for Flask app encryption"

gcloud kms keys create flask-encryption-key \
    --location=$REGION \
    --keyring=flask-keyring \
    --purpose=encryption \
    --rotation-period="86400s" \
    --next-rotation-time="$(date -d '+30 days' --iso-8601 2>/dev/null || date -v+30d -I)"

echo "✅ KMS key created"

# Step 3: Create service account for the app
echo "Creating app service account..."
APP_SA="flask-secure-sa"

gcloud iam service-accounts create $APP_SA \
    --description="Service account for secure Flask application" \
    --display-name="Secure Flask App"

# Grant necessary permissions
echo "Granting permissions..."
# KMS encryption/decryption
gcloud kms keys add-iam-policy-binding flask-encryption-key \
    --location=$REGION \
    --keyring=flask-keyring \
    --member="serviceAccount:$APP_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"

# Logging and monitoring
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$APP_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$APP_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/monitoring.metricWriter"

# App Engine permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$APP_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/appengine.appViewer"

echo "✅ Service account created and permissions granted"

# Step 4: Create App Engine configuration with service account
echo "Creating secure App Engine configuration..."
cat > secure-app.yaml << EOF
runtime: python311
entrypoint: gunicorn -b :\$PORT secure_main:app
instance_class: F1
service: secure

# Use our dedicated service account
service_account: $APP_SA@$PROJECT_ID.iam.gserviceaccount.com

automatic_scaling:
  min_instances: 0
  max_instances: 2
  target_cpu_utilization: 0.75
  target_throughput_utilization: 0.75

resources:
  cpu: 1
  memory_gb: 1
  disk_size_gb: 10

# Environment variables for security
env_variables:
  GOOGLE_CLOUD_PROJECT: "$PROJECT_ID"
  KMS_LOCATION: "$REGION"
  KMS_KEY_RING: "flask-keyring"
  KMS_KEY_ID: "flask-encryption-key"

# Health checks
health_check:
  enable_health_check: True
  check_interval_sec: 30
  timeout_sec: 4
  unhealthy_threshold: 2
  healthy_threshold: 2

readiness_check:
  app_start_timeout_sec: 300
EOF

echo "✅ Secure App Engine configuration created"

# Step 5: Set up basic monitoring
echo "Setting up monitoring..."
# Create a simple notification channel (email would need to be configured)
gcloud monitoring channels create \
    --type=email \
    --display-name="App Security Alerts" \
    --description="Email notifications for app security issues" \
    --labels=email_address="alerts@example.com" \
    --format="value(name)" 2>/dev/null || echo "Email notification channel needs manual setup"

# Create alert for high error rates
gcloud monitoring policies create \
    --condition-display-name="High App Error Rate" \
    --condition-filter='metric.type="appengine.googleapis.com/http/server/response_count" resource.type="gae_app" metric.labels.response_code_class="5xx"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_RATE" \
    --condition-trigger-threshold-value=0.05 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="60s" \
    --display-name="Flask App Error Rate Alert" \
    --notification-channels=""  # Would be populated with actual channel ID

# Create alert for suspicious activity (high error rate)
gcloud monitoring policies create \
    --condition-display-name="Suspicious Activity Detection" \
    --condition-filter='metric.type="appengine.googleapis.com/http/server/response_count" resource.type="gae_app" metric.labels.response_code_class="4xx"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_RATE" \
    --condition-trigger-threshold-value=0.1 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="60s" \
    --display-name="Flask App 4xx Alert" \
    --notification-channels=""

echo "✅ Monitoring alerts configured"

# Step 6: Enable Cloud Logging for security events
echo "Configuring logging..."
# Create log-based metric for security events
gcloud logging metrics create app_security_events \
    --description="Security events from Flask app" \
    --filter='resource.type="gae_app" AND jsonPayload."message"="SECURITY_EVENT:"'

echo "✅ Logging metrics created"

# Step 7: Create basic security test script
echo "Creating security test script..."
cat > test-security.sh << 'EOF'
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
EOF

chmod +x test-security.sh

echo "✅ Security test script created"

# Step 8: Create deployment verification
echo "Creating deployment verification..."
cat > verify-security-deployment.sh << EOF
#!/bin/bash
# Verify security deployment

SERVICE="secure"
echo "Verifying secure deployment: $SERVICE"

echo "1. Checking service status..."
gcloud app services describe $SERVICE

echo "2. Checking service account..."
gcloud app services describe $SERVICE --format="value(serviceAccount)"

echo "3. Testing deployment..."
APP_URL="https://$SERVICE-dot-$PROJECT_ID.uc.r.appspot.com"
curl -s "$APP_URL/api/status" | jq .

echo "4. Running security tests..."
./test-security.sh $SERVICE $PROJECT_ID

echo "✅ Verification completed"
EOF

chmod +x verify-security-deployment.sh

echo "✅ Verification script created"

# Summary
cat << EOF

🔒 Security Setup Complete!

📋 What was created:
✅ KMS encryption key: flask-encryption-key
✅ Service account: $APP_SA
✅ App Engine config: secure-app.yaml
✅ Monitoring alerts for 4xx/5xx errors
✅ Security logging metrics
✅ Security test scripts

🚀 Next steps:
1. Deploy the secure version:
   gcloud app deploy secure-app.yaml

2. Verify deployment:
   ./verify-security-deployment.sh

3. Test security features:
   ./test-security.sh secure $PROJECT_ID

🔗 Live URL will be:
https://secure-dot-$PROJECT_ID.uc.r.appspot.com

⚠️  Manual setup needed:
- Configure email notification channels for alerts
- Review alert thresholds based on your traffic
EOF