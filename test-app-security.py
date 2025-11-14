#!/usr/bin/env python3
"""
Test security features of the Flask app
"""

import requests
import sys

def test_security_features(base_url):
    """Test basic security features"""
    print(f"Testing security features for: {base_url}")

    results = []

    # Test 1: Check if app is accessible
    print("\n1. Testing app accessibility...")
    try:
        response = requests.get(f"{base_url}/", timeout=10)
        if response.status_code == 200:
            print(f"   PASS: App accessible (status {response.status_code})")
            results.append(("Accessibility", True))
        else:
            print(f"   FAIL: App not accessible (status {response.status_code})")
            results.append(("Accessibility", False))

    except Exception as e:
        print(f"   ERROR: {e}")
        results.append(("Accessibility", False))

    # Test 2: API functionality
    print("\n2. Testing API functionality...")
    try:
        response = requests.get(f"{base_url}/api/status", timeout=10)
        if response.status_code == 200:
            print(f"   PASS: API working (status {response.status_code})")
            results.append(("API Functionality", True))
        else:
            print(f"   FAIL: API not working (status {response.status_code})")
            results.append(("API Functionality", False))

    except Exception as e:
        print(f"   ERROR: {e}")
        results.append(("API Functionality", False))

    # Test 3: Input validation
    print("\n3. Testing input validation...")
    try:
        response = requests.post(
            f"{base_url}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": ""},  # Empty text
            timeout=10
        )

        if response.status_code == 400:
            print("   PASS: Empty input correctly rejected")
            validation_ok = True
        else:
            print("   FAIL: Empty input accepted")
            validation_ok = False

    except Exception as e:
        print(f"   ERROR: {e}")
        validation_ok = False

    results.append(("Input Validation", validation_ok))

    # Test 4: Create a valid todo
    print("\n4. Testing valid todo creation...")
    try:
        response = requests.post(
            f"{base_url}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": "Security test todo"},
            timeout=10
        )

        if response.status_code == 201:
            print("   PASS: Valid todo created successfully")
            creation_ok = True
        else:
            print(f"   FAIL: Todo creation failed (status {response.status_code})")
            creation_ok = False

    except Exception as e:
        print(f"   ERROR: {e}")
        creation_ok = False

    results.append(("Todo Creation", creation_ok))

    # Summary
    print("\n=== SECURITY TEST SUMMARY ===")
    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        print(f"{test_name}: {status}")

    print(f"\nOverall: {passed}/{total} tests passed")

    return passed == total

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python test-app-security.py <base_url>")
        print("Example: python test-app-security.py https://kbtu-ldoc.uc.r.appspot.com")
        sys.exit(1)

    base_url = sys.argv[1]
    success = test_security_features(base_url)
    sys.exit(0 if success else 1)