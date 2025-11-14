#!/usr/bin/env python3
"""
Simple security scanning script using Bandit
This analyzes the Flask app code for security issues
"""

import os
import subprocess
import json
import sys
from datetime import datetime

def run_bandit_scan(file_path):
    """Run Bandit security scan on a Python file"""
    try:
        print(f"[SCANNING] Running security scan on {file_path}...")

        # Run bandit with JSON output
        result = subprocess.run([
            'bandit',
            '-r',
            file_path,
            '-f', 'json',
            '-ll'  # Low confidence level to catch more issues
        ], capture_output=True, text=True)

        if result.returncode == 0:
            print("[PASS] No high-severity security issues found")
            return {"status": "clean", "issues": []}
        else:
            # Parse JSON output
            try:
                data = json.loads(result.stdout)
                issues = data.get('results', [])
                return {"status": "issues_found", "issues": issues}
            except json.JSONDecodeError:
                print("[WARN] Could not parse bandit output")
                return {"status": "error", "error": "parse_error"}

    except FileNotFoundError:
        print("[ERROR] Bandit not installed. Run: pip install bandit")
        return {"status": "error", "error": "bandit_not_installed"}
    except Exception as e:
        print(f"[ERROR] Error running security scan: {e}")
        return {"status": "error", "error": str(e)}

def analyze_security_issues(issues):
    """Analyze and categorize security issues"""
    if not issues:
        return

    high_issues = [i for i in issues if i.get('issue_severity') == 'HIGH']
    medium_issues = [i for i in issues if i.get('issue_severity') == 'MEDIUM']
    low_issues = [i for i in issues if i.get('issue_severity') == 'LOW']

    print(f"\n📊 Security Analysis Summary:")
    print(f"   🔴 High: {len(high_issues)}")
    print(f"   🟡 Medium: {len(medium_issues)}")
    print(f"   🟢 Low: {len(low_issues)}")

    if high_issues:
        print(f"\n🚨 High Severity Issues:")
        for issue in high_issues:
            print(f"   • {issue.get('test_name', 'Unknown')}: {issue.get('issue_text', 'No description')}")
            print(f"     Location: {issue.get('filename', 'Unknown')}:{issue.get('line_number', '?')}")

    if medium_issues:
        print(f"\n⚠️  Medium Severity Issues:")
        for issue in medium_issues[:5]:  # Show first 5
            print(f"   • {issue.get('test_name', 'Unknown')}: {issue.get('issue_text', 'No description')}")

    return len(high_issues), len(medium_issues), len(low_issues)

def generate_security_report(scan_results):
    """Generate a security report"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    report = f"""
# Security Scan Report
Generated: {timestamp}

## Files Scanned:
- app/main.py
- app/secure_main.py
- cloud-function/main.py

## Results:
"""

    total_high = 0
    total_medium = 0
    total_low = 0

    for file_path, result in scan_results.items():
        if result['status'] == 'issues_found':
            issues = result['issues']
            high, medium, low = analyze_security_issues(issues)
            total_high += high
            total_medium += medium
            total_low += low
            report += f"### {file_path}: {high} high, {medium} medium, {low} low\n"
        elif result['status'] == 'clean':
            report += f"### {file_path}: ✅ Clean\n"
        else:
            report += f"### {file_path}: ❌ Error - {result.get('error', 'Unknown')}\n"

    report += f"""
## Summary:
- Total High Issues: {total_high}
- Total Medium Issues: {total_medium}
- Total Low Issues: {total_low}
- Overall Status: {'🚨 Action Required' if total_high > 0 else '⚠️ Review Recommended' if total_medium > 0 else '✅ Secure'}

## Recommendations:
- Fix all high-severity issues immediately
- Review medium-severity issues for potential impact
- Consider low-severity issues for hardening
- Run scans regularly and before deployments
"""

    # Save report
    with open('security-report.md', 'w') as f:
        f.write(report)

    print(f"\n📄 Security report saved to: security-report.md")
    return total_high, total_medium, total_low

def main():
    """Main security scanning function"""
    print("Flask Todo App Security Scanner")
    print("=" * 40)

    # Check if bandit is installed
    try:
        subprocess.run(['bandit', '--version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Installing Bandit...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'bandit'])

    # Files to scan
    files_to_scan = [
        'app/main.py',
        'app/secure_main.py',
        'cloud-function/main.py'
    ]

    # Run scans
    scan_results = {}
    for file_path in files_to_scan:
        if os.path.exists(file_path):
            result = run_bandit_scan(file_path)
            scan_results[file_path] = result
        else:
            print(f"⚠️  File not found: {file_path}")
            scan_results[file_path] = {"status": "not_found"}

    # Generate report
    high, medium, low = generate_security_report(scan_results)

    # Print summary
    print(f"\n🎯 Final Assessment:")
    if high > 0:
        print(f"🚨 CRITICAL: {high} high-severity issues found - Fix before production!")
    elif medium > 0:
        print(f"⚠️  WARNING: {medium} medium-severity issues found - Review recommended")
    else:
        print(f"✅ GOOD: No critical security issues found")

    print(f"📊 Total Issues: {high} high, {medium} medium, {low} low")

    return high == 0  # Return True if no high-severity issues

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)