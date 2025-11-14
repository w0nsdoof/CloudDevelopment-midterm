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
