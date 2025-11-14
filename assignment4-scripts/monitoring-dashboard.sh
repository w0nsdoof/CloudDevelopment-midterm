#!/bin/bash
# Assignment 4 - Exercise 2: Performance Monitoring and Dashboards
# This script sets up comprehensive monitoring and dashboards

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

echo "Setting up performance monitoring and dashboards for project: $PROJECT_ID"

# Create custom metrics for application performance
echo "Creating custom metrics..."

# Todo API response time metric
gcloud monitoring metrics-descriptor create \
    custom.googleapis.com/flask_app/api_response_time \
    --description="Flask Todo API response time" \
    --display-name="Todo API Response Time" \
    --type="GAUGE" \
    --metric-kind="GAUGE" \
    --unit="ms"

# Active users metric
gcloud monitoring metrics-descriptor create \
    custom.googleapis.com/flask_app/active_users \
    --description="Number of active users" \
    --display-name="Active Users" \
    --type="GAUGE" \
    --metric-kind="GAUGE" \
    --unit="1"

# Todo operations metric
gcloud monitoring metrics-descriptor create \
    custom.googleapis.com/flask_app/todo_operations \
    --description="Number of todo operations (create/read/update/delete)" \
    --display-name="Todo Operations" \
    --type="CUMULATIVE" \
    --metric-kind="CUMULATIVE" \
    --unit="1"

echo "✅ Custom metrics created"

# Create monitoring dashboard
echo "Creating performance monitoring dashboard..."

cat > dashboard-definition.json << EOF
{
  "displayName": "Flask App Performance Dashboard",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "Request Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "prometheusQuerySource": {
                  "prometheusQuery": "rate(appengine.googleapis.com/http/server/request_count[5m])"
                }
              },
              "plotType": "LINE",
              "legendTemplate": "{{resource.label.project_id}}"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Requests/sec",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Response Time",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "prometheusQuerySource": {
                  "prometheusQuery": "histogram_quantile(0.95, rate(appengine.googleapis.com/http/server/response_latencies[5m]))"
                }
              },
              "plotType": "LINE",
              "legendTemplate": "95th percentile"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Response Time (ms)",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Error Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "prometheusQuerySource": {
                  "prometheusQuery": "rate(appengine.googleapis.com/http/server/response_count[5m])"
                }
              },
              "plotType": "LINE",
              "legendTemplate": "5xx errors"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Error Rate (%)",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "CPU Utilization",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "prometheusQuerySource": {
                  "prometheusQuery": "avg(appengine.googleapis.com/instance/cpu/utilization)"
                }
              },
              "plotType": "LINE",
              "legendTemplate": "CPU %"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "CPU Utilization (%)",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Memory Usage",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "prometheusQuerySource": {
                  "prometheusQuery": "avg(appengine.googleapis.com/instance/memory/usage)"
                }
              },
              "plotType": "LINE",
              "legendTemplate": "Memory MB"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Memory Usage (MB)",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Active Instances",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "prometheusQuerySource": {
                  "prometheusQuery": "appengine.googleapis.com/instance/count"
                }
              },
              "plotType": "LINE",
              "legendTemplate": "Running Instances"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Instance Count",
            "scale": "LINEAR"
          }
        }
      }
    ]
  }
}
EOF

# Create dashboard using Cloud Monitoring API
DASHBOARD_ID=$(curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d @dashboard-definition.json \
  "https://monitoring.googleapis.com/v1/projects/$PROJECT_ID/dashboards" | jq -r '.name')

echo "✅ Performance dashboard created: $DASHBOARD_ID"

# Create synthetic monitoring for uptime checks
echo "Setting up uptime checks..."

# Create uptime check for main application
gcloud monitoring uptime-checks create flask-app-uptime \
    --display-name="Flask App Uptime Check" \
    --host="$PROJECT_ID.uc.r.appspot.com" \
    --path="/" \
    --port=443 \
    --check-interval=60s \
    --timeout=10s \
    --selected-regions=us-central1,us-east1,us-west1 \
    --content-matchers="Hello, GCP"

# Create uptime check for API endpoint
gcloud monitoring uptime-checks create flask-api-uptime \
    --display-name="Flask API Uptime Check" \
    --host="$PROJECT_ID.uc.r.appspot.com" \
    --path="/api/status" \
    --port=443 \
    --check-interval=60s \
    --timeout=10s \
    --selected-regions=us-central1,us-east1,us-west1 \
    --content-matchers="operational"

echo "✅ Uptime checks created"

# Create alert policies for performance monitoring
echo "Creating performance alert policies..."

# Alert for high response time
gcloud monitoring policies create \
    --condition-display-name="High API Response Time" \
    --condition-filter='metric.type="appengine.googleapis.com/http/server/response_latencies" resource.type="gae_app"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_PERCENTILE_95" \
    --condition-aggregations-alignment-period="300s" \
    --condition-trigger-threshold-value=1000 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="300s" \
    --display-name="High API Response Time Alert"

# Alert for high error rate
gcloud monitoring policies create \
    --condition-display-name="High Error Rate" \
    --condition-filter='metric.type="appengine.googleapis.com/http/server/response_count" resource.type="gae_app" metric.labels.response_code_class="5xx"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_RATE" \
    --condition-trigger-threshold-value=0.05 \
    --condition-trigger-threshold-comparison="COMPARISON_GT" \
    --condition-duration="300s" \
    --display-name="High Error Rate Alert"

# Alert for low available instances
gcloud monitoring policies create \
    --condition-display-name="Low Available Instances" \
    --condition-filter='metric.type="appengine.googleapis.com/instance/available" resource.type="gae_app"' \
    --condition-aggregations-alignment-period="300s" \
    --condition-aggregations-per-series-aligner="ALIGN_MIN" \
    --condition-trigger-threshold-value=1 \
    --condition-trigger-threshold-comparison="COMPARISON_LT" \
    --condition-duration="60s" \
    --display-name="Low Available Instances Alert"

echo "✅ Performance alert policies created"

# Create cost optimization monitoring
echo "Setting up cost optimization monitoring..."

# Cost tracking alerts
gcloud billing budgets create \
    --display-name="Monthly Cost Budget" \
    --billing-account=$(gcloud billing accounts list --format='value(ACCOUNT_ID)' --limit=1) \
    --budget-amount=50USD \
    --threshold-rule-percent=90 \
    --threshold-rule-spend-basis=current-spend

echo "✅ Cost optimization monitoring configured"

# Create performance benchmarking script
cat > performance-benchmark.sh << EOF
#!/bin/bash
# Performance benchmarking script for the Flask application

APP_URL="https://$PROJECT_ID.uc.r.appspot.com"
API_URL="\$APP_URL/api/todos"
RESULTS_FILE="performance-results-\$(date +%Y%m%d-%H%M%S).csv"

echo "TimeStamp,Endpoint,ResponseTime,StatusCode,ContentSize" > \$RESULTS_FILE

echo "Starting performance benchmark at \$(date)"
echo "Target URL: \$APP_URL"
echo "Results will be saved to: \$RESULTS_FILE"

# Test homepage endpoint
for i in {1..100}; do
  START_TIME=\$(date +%s%N)
  RESPONSE=\$(curl -s -w "%{http_code}" "\$APP_URL")
  END_TIME=\$(date +%s%N)

  STATUS_CODE=\${RESPONSE: -3}
  CONTENT_SIZE=\$(echo "\$RESPONSE" | wc -c)
  RESPONSE_TIME=\$(((\$END_TIME - \$START_TIME) / 1000000))

  echo "\$(date),/,\$RESPONSE_TIME,\$STATUS_CODE,\$CONTENT_SIZE" >> \$RESULTS_FILE
  sleep 0.1
done

# Test API endpoint
for i in {1..50}; do
  START_TIME=\$(date +%s%N)
  RESPONSE=\$(curl -s -w "%{http_code}" "\$API_URL")
  END_TIME=\$(date +%s%N)

  STATUS_CODE=\${RESPONSE: -3}
  CONTENT_SIZE=\$(echo "\$RESPONSE" | wc -c)
  RESPONSE_TIME=\$(((\$END_TIME - \$START_TIME) / 1000000))

  echo "\$(date),/api/todos,\$RESPONSE_TIME,\$STATUS_CODE,\$CONTENT_SIZE" >> \$RESULTS_FILE
  sleep 0.2
done

echo "Benchmark completed. Results saved to \$RESULTS_FILE"
echo ""
echo "Summary statistics:"
echo "Average response time: \$(awk -F',' 'NR>1 {sum+=\$3; count++} END {if(count>0) print sum/count; else print "N/A"}' \$RESULTS_FILE) ms"
echo "Maximum response time: \$(awk -F',' 'NR>1 && \$3>max {max=\$3} END {print max}' \$RESULTS_FILE) ms"
echo "Minimum response time: \$(awk -F',' 'NR>1 {if(min=="" || \$3<min) min=\$3} END {print min}' \$RESULTS_FILE) ms"
EOF

chmod +x performance-benchmark.sh

echo "✅ Performance benchmarking script created"

# Generate deployment summary
cat > monitoring-summary.md << EOF
# Assignment 4 - Monitoring and Performance Summary

## Monitoring Setup Completed

### 📊 Dashboards
- **Performance Dashboard**: Comprehensive view of application metrics
- **Dashboard URL**: https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID

### 🔍 Metrics Being Monitored
1. **Performance Metrics**
   - Request rate (requests/second)
   - Response times (95th percentile)
   - Error rates (5xx responses)
   - CPU utilization
   - Memory usage
   - Active instance count

2. **Availability Metrics**
   - Uptime checks for main endpoint
   - API endpoint health monitoring
   - Regional availability checks (3 regions)

3. **Custom Application Metrics**
   - Todo API response time
   - Active users count
   - Todo operations counter

### 🚨 Alert Policies
1. **Performance Alerts**
   - High API response time (>1000ms)
   - High error rate (>5%)
   - Low available instances (<1)

2. **Cost Alerts**
   - Monthly budget monitoring (90% threshold)

### 📈 Auto-scaling Configuration
- **App Engine**: 1-10 instances, CPU target 65%, throughput target 75%
- **GKE**: 2-10 pods, CPU target 50%
- **Cloud Run**: 0-100 instances, 100 concurrent requests

### 🎯 Performance Targets
- **Response Time**: <200ms (95th percentile)
- **Availability**: 99.9% uptime
- **Error Rate**: <1%
- **Scaling Response**: <2 minutes to respond to load changes

### 📋 Monitoring Checklist
- [x] Performance dashboards created
- [x] Uptime checks configured
- [x] Alert policies implemented
- [x] Cost monitoring enabled
- [x] Custom metrics defined
- [x] Benchmarking script ready

### 🚀 How to Use

1. **View Dashboards**:
   \`\`\`bash
   https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID
   \`\`\`

2. **Run Performance Benchmarks**:
   \`\`\`bash
   ./performance-benchmark.sh
   \`\`\`

3. **Check Alert Status**:
   \`\`\`bash
   gcloud monitoring policies list
   \`\`\`

4. **View Uptime Checks**:
   \`\`\`bash
   gcloud monitoring uptime-checks list
   \`\`\`

### 📊 Next Steps for Optimization
1. Analyze performance data over time
2. Adjust auto-scaling thresholds based on patterns
3. Implement caching for frequently accessed data
4. Consider CDN for static assets
5. Optimize database queries and connection pooling

**Last Updated**: $(date)
**Project ID**: $PROJECT_ID
EOF

echo "🎯 Monitoring and performance setup completed!"
echo ""
echo "📊 Dashboard: https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"
echo "📋 Summary report: monitoring-summary.md"
echo ""
echo "Next steps:"
echo "1. Run performance benchmarks: ./performance-benchmark.sh"
echo "2. Monitor dashboards for patterns"
echo "3. Adjust scaling thresholds as needed"
echo "4. Review cost optimization opportunities"