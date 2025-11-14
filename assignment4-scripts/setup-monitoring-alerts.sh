#!/bin/bash
# Assignment 4 - Exercise 1: Monitoring and Alerting Setup
# This script sets up monitoring, logging, and security alerts

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

echo "Setting up Monitoring and Alerting for project: $PROJECT_ID"

# Enable Cloud Audit Logs
echo "Configuring Cloud Audit Logs..."
gcloud projects get-iam-policy $PROJECT_ID > policy.yaml

# Add audit log configuration (this would typically be done through console or API)
cat > audit-config.yaml << EOF
auditConfigs:
- auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_WRITE
  - logType: DATA_READ
  service: allServices
EOF

echo "⚠️  Note: Audit logs configuration requires manual setup in Cloud Console"
echo "   Navigate to: IAM & Admin > Audit Logs"
echo "   Enable Admin Read, Data Write, and Data Read for Cloud SQL, Storage, and App Engine"

# Create monitoring notifications
echo "Creating monitoring notification channels..."
gcloud monitoring channels create \
    --type=email \
    --display-name="Security Alerts" \
    --description="Email notifications for security alerts" \
    --labels=email_address="admin@example.com" \
    --format="value(name)" > channel-id.txt

CHANNEL_ID=$(cat channel-id.txt)
echo "✅ Notification channel created: $CHANNEL_ID"

# Create alert policies for security events
echo "Setting up security alert policies..."

# Alert for failed authentication attempts
gcloud monitoring policies create \
    --notification-channels=$CHANNEL_ID \
    --condition-display-name="High Failed Login Rate" \
    --condition-filter='metric.type="appengine.googleapis.com/http/server/response_count" resource.type="gae_app" metric.labels.response_code_class="4xx"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_RATE" \
    --condition-trigger-threshold-value=10 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="60s" \
    --combining="OR"

# Alert for high error rates
gcloud monitoring policies create \
    --notification-channels=$CHANNEL_ID \
    --condition-display-name="High Application Error Rate" \
    --condition-filter='metric.type="appengine.googleapis.com/http/server/response_count" resource.type="gae_app" metric.labels.response_code_class="5xx"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_RATE" \
    --condition-trigger-threshold-value=5 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="60s" \
    --combining="OR"

# Alert for unusual CPU usage
gcloud monitoring policies create \
    --notification-channels=$CHANNEL_ID \
    --condition-display-name="High CPU Usage" \
    --condition-filter='metric.type="appengine.googleapis.com/instance/cpu/utilization" resource.type="gae_app"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_MEAN" \
    --condition-trigger-threshold-value=0.8 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="300s" \
    --combining="OR"

echo "✅ Security monitoring alerts configured"

# Enable Security Center
echo "Enabling Security Center..."
gcloud services enable securitycenter.googleapis.com

# Create Security Center source
gcloud scc sources create \
    --organization=$(gcloud organizations list --format="value(ID)" --limit=1) \
    --display-name="Assignment 4 Security Source" \
    --description="Security monitoring for Assignment 4 Flask application"

echo "✅ Security Center enabled"

# Set up log-based metrics for security events
echo "Creating log-based metrics..."
gcloud logging metrics create security_events \
    --description="Log-based metric for security events" \
    --filter='resource.type="gae_app" AND (protoPayload.methodName="appengine.applications.create" OR protoPayload.methodName="appengine.services.delete")'

gcloud logging metrics create authentication_failures \
    --description="Count of authentication failures" \
    --filter='resource.type="gae_app" AND httpRequest.status=401'

echo "✅ Log-based metrics created"

# Create log sinks for security logs
echo "Setting up log sinks..."
BUCKET_NAME="${PROJECT_ID}-security-logs"

# Create storage bucket for security logs
gsutil mb -l $REGION gs://$BUCKET_NAME

# Create log sink
gcloud logging sinks create security-logs-sink \
    storage.googleapis.com/$BUCKET_NAME \
    --log-filter='protoPayload.methodName!~"storage.objects.get" AND protoPayload.methodName!~"storage.objects.list" AND protoPayload.methodName!~"appengine.services.get"' \
    --include-children

echo "✅ Log sinks configured"

echo "🎯 Monitoring and Alerting setup completed!"
echo ""
echo "Next steps:"
echo "1. Update email address in notification channels"
echo "2. Configure audit logs in Cloud Console"
echo "3. Set up Cloud Security Command Center monitoring"
echo "4. Create incident response plan (see incident-response-plan.md)"