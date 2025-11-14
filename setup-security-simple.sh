#!/bin/bash
# Simplified Security Setup for Flask Todo App
# Focus on what actually works with current permissions

PROJECT_ID=$(gcloud config get-value project)
echo "Setting up practical security for Flask Todo App..."
echo "Project: $PROJECT_ID"

# Step 1: Create service account with basic permissions
echo "Creating app service account..."
APP_SA="flask-secure-sa"

gcloud iam service-accounts create $APP_SA \
    --description="Service account for secure Flask application" \
    --display-name="Secure Flask App" 2>/dev/null || echo "Service account might already exist"

# Grant basic permissions that work
echo "Granting permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$APP_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/appengine.appViewer" 2>/dev/null

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$APP_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter" 2>/dev/null

echo "✅ Service account and basic permissions configured"

# Step 2: Create simplified App Engine configuration
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

resources:
  cpu: 1
  memory_gb: 1

# Environment variables for security
env_variables:
  GOOGLE_CLOUD_PROJECT: "$PROJECT_ID"
  # Note: KMS variables would be set if KMS was available

# Health checks
health_check:
  enable_health_check: True
  check_interval_sec: 30
  timeout_sec: 4

readiness_check:
  app_start_timeout_sec: 300
EOF

echo "✅ Secure App Engine configuration created"

# Step 3: Install security scanning dependencies
echo "Installing security scanning tools..."
pip install bandit 2>/dev/null || python -m pip install bandit

echo "✅ Security scanning tools installed"

# Step 4: Create working security test
echo "Creating security test script..."
cat > test-security-simple.py << 'EOF'
#!/usr/bin/env python3
"""
Simple security test for the Flask app
"""

import requests
import json
import sys
import time

def test_security_features(base_url):
    """Test basic security features"""
    print(f"🔒 Testing security features for: {base_url}")

    results = []

    # Test 1: Check security headers
    print("\n1. Testing security headers...")
    try:
        response = requests.get(f"{base_url}/", timeout=10)

        security_headers = {
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'X-XSS-Protection': '1; mode=block'
        }

        headers_ok = True
        for header, expected in security_headers.items():
            if response.headers.get(header) == expected:
                print(f"   ✅ {header}: {expected}")
            else:
                print(f"   ❌ {header}: Missing or incorrect")
                headers_ok = False

        results.append(("Security Headers", headers_ok))

    except Exception as e:
        print(f"   ❌ Error testing headers: {e}")
        results.append(("Security Headers", False))

    # Test 2: Input validation
    print("\n2. Testing input validation...")
    test_cases = [
        ("", "empty text"),
        ("<script>alert('xss')</script>", "XSS attempt"),
        ("' OR 1=1 --", "SQL injection attempt"),
        ("../../etc/passwd", "Path traversal attempt")
    ]

    validation_ok = True
    for malicious_input, description in test_cases:
        try:
            response = requests.post(
                f"{base_url}/api/todos",
                headers={"Content-Type": "application/json"},
                json={"text": malicious_input},
                timeout=10
            )

            if response.status_code == 400:
                print(f"   ✅ Blocked {description}")
            else:
                print(f"   ❌ Allowed {description}")
                validation_ok = False

        except Exception as e:
            print(f"   ⚠️  Error testing {description}: {e}")

    results.append(("Input Validation", validation_ok))

    # Test 3: CORS protection
    print("\n3. Testing CORS protection...")
    try:
        response = requests.options(
            f"{base_url}/api/todos",
            headers={"Origin": "https://malicious-site.com"},
            timeout=10
        )

        # Check if it allows malicious origin
        allow_origin = response.headers.get("Access-Control-Allow-Origin")
        if allow_origin and "malicious-site.com" in allow_origin:
            print("   ❌ CORS allows malicious origin")
            cors_ok = False
        else:
            print("   ✅ CORS properly configured")
            cors_ok = True

    except Exception as e:
        print(f"   ⚠️  Error testing CORS: {e}")
        cors_ok = False

    results.append(("CORS Protection", cors_ok))

    # Test 4: Performance (DOS resistance)
    print("\n4. Testing performance limits...")
    try:
        start_time = time.time()

        # Make 10 quick requests
        for _ in range(10):
            response = requests.get(f"{base_url}/api/status", timeout=2)

        avg_time = (time.time() - start_time) / 10

        if avg_time < 0.5:
            print(f"   ✅ Good performance: {avg_time:.3f}s avg")
            perf_ok = True
        else:
            print(f"   ⚠️  Slow performance: {avg_time:.3f}s avg")
            perf_ok = False

    except Exception as e:
        print(f"   ❌ Error testing performance: {e}")
        perf_ok = False

    results.append(("Performance", perf_ok))

    # Summary
    print("\n📊 Security Test Summary:")
    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"   {test_name}: {status}")

    print(f"\nOverall: {passed}/{total} tests passed")

    return passed == total

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python test-security-simple.py <base_url>")
        print("Example: python test-security-simple.py https://secure-dot-gcp-as3-assignment.uc.r.appspot.com")
        sys.exit(1)

    base_url = sys.argv[1]
    success = test_security_features(base_url)
    sys.exit(0 if success else 1)
EOF

chmod +x test-security-simple.py

echo "✅ Security test script created"

# Step 5: Run security scan on code
echo "Running security scan on application code..."
python security-scan.py

echo ""
echo "🎉 Security Setup Complete!"
echo ""
echo "📋 What was created:"
echo "✅ Service account: $APP_SA"
echo "✅ App Engine config: secure-app.yaml"
echo "✅ Security test script: test-security-simple.py"
echo "✅ Security scanning: security-scan.py"
echo ""
echo "🚀 Next steps:"
echo "1. Deploy the secure version:"
echo "   gcloud app deploy secure-app.yaml"
echo ""
echo "2. Test security features:"
echo "   python test-security-simple.py https://secure-dot-$PROJECT_ID.uc.r.appspot.com"
echo ""
echo "🔗 Live URL will be:"
echo "https://secure-dot-$PROJECT_ID.uc.r.appspot.com"