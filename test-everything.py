#!/usr/bin/env python3
"""
Simple test script that checks everything is working
"""

import subprocess
import sys
import os

def run_command(command):
    """Run command and return success"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def main():
    print("Assignment 4 - Quick Test")
    print("=" * 40)

    # Test 1: Check Python works
    print("1. Testing Python...")
    success, out, err = run_command("python --version")
    if success:
        print(f"   Python is working: {out.strip()}")
    else:
        print(f"   Python error: {err}")
        return False

    # Test 2: Test security scan
    print("\n2. Testing security scan...")
    success, out, err = run_command("python security-scan-simple.py")
    if "Flask Todo App Security Scanner" in out:
        print("   Security scanner works!")
        if "0 high-severity" in out:
            print("   PASS: No high severity issues")
        else:
            print("   WARNING: Issues found (see full output)")
    else:
        print(f"   Security scanner error: {err}")

    # Test 3: Test app connectivity
    print("\n3. Testing app connectivity...")
    success, out, err = run_command("curl -I https://kbtu-ldoc.uc.r.appspot.com 2>nul")
    if "200" in out or "HTTP/2 200" in out:
        print("   App is accessible!")
    else:
        print("   App connectivity check failed")

    # Test 4: Test app security
    print("\n4. Testing app security...")
    success, out, err = run_command("python test-app-security.py https://kbtu-ldoc.uc.r.appspot.com")
    if "4/4 tests passed" in out:
        print("   Security tests PASS!")
    else:
        print("   Security tests had issues")

    print("\n" + "=" * 40)
    print("Quick test completed!")
    print("\nTo see full security scan output:")
    print("   python security-scan-simple.py")
    print("\nTo see full security test output:")
    print("   python test-app-security.py https://kbtu-ldoc.uc.r.appspot.com")

    return True

if __name__ == '__main__':
    main()