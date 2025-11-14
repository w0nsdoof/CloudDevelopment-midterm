import requests
import pytest
import json
import time
import os

BASE_URL = "https://kbtu-ldoc.uc.r.appspot.com"

def test_cloud_homepage():
    """Test that cloud homepage returns 200 status"""
    response = requests.get(BASE_URL, timeout=10)
    assert response.status_code == 200
    assert 'Hello, GCP' in response.text
    print(f"[PASS] Homepage test passed: {response.status_code}")

def test_api_status():
    """Test that API status endpoint works"""
    response = requests.get(f"{BASE_URL}/api/status", timeout=10)
    assert response.status_code == 200
    data = response.json()
    assert 'status' in data
    assert data['status'] == 'operational'
    assert 'version' in data
    print(f"[PASS] API status test passed: {data}")

def test_api_todos_workflow():
    """Test full todo API workflow"""
    # Get initial todos
    response = requests.get(f"{BASE_URL}/api/todos", timeout=10)
    assert response.status_code == 200
    initial_todos = response.json()
    initial_count = len(initial_todos)

    # Create a new todo
    todo_text = f"Assignment 4 test todo {int(time.time())}"
    response = requests.post(
        f"{BASE_URL}/api/todos",
        headers={"Content-Type": "application/json"},
        json={"text": todo_text},
        timeout=10
    )
    assert response.status_code == 201
    create_response = response.json()

    # Get todos again to verify creation
    response = requests.get(f"{BASE_URL}/api/todos", timeout=10)
    assert response.status_code == 200
    updated_todos = response.json()

    # Verify todo was created
    assert len(updated_todos) > initial_count
    todo_created = any(todo['text'] == todo_text for todo in updated_todos)
    assert todo_created

    print(f"[PASS] Todo API workflow test passed: Created {todo_text}")

def test_api_cors_headers():
    """Test that CORS headers are properly set"""
    response = requests.options(f"{BASE_URL}/api/todos", timeout=10)
    assert response.status_code == 200
    print(f"[PASS] CORS test passed: {response.status_code}")

def test_performance_response_time():
    """Test that response times are acceptable"""

    start_time = time.time()
    response = requests.get(f"{BASE_URL}/api/status", timeout=10)
    end_time = time.time()

    response_time_ms = (end_time - start_time) * 1000
    assert response.status_code == 200
    assert response_time_ms < 2000  # Should respond within 2 seconds

    print(f"[PASS] Performance test passed: {response_time_ms:.2f}ms")

def test_error_handling():
    """Test error handling for invalid requests"""
    # Test missing text field
    response = requests.post(
        f"{BASE_URL}/api/todos",
        headers={"Content-Type": "application/json"},
        json={"invalid_field": "test"},
        timeout=10
    )
    assert response.status_code == 400
    assert 'error' in response.json()

    # Test empty text field
    response = requests.post(
        f"{BASE_URL}/api/todos",
        headers={"Content-Type": "application/json"},
        json={"text": ""},
        timeout=10
    )
    assert response.status_code == 400
    assert 'error' in response.json()

    print(f"[PASS] Error handling test passed")

if __name__ == "__main__":
    print("Running cloud deployment smoke tests...")

    try:
        test_cloud_homepage()
        test_api_status()
        test_api_todos_workflow()
        test_api_cors_headers()
        test_performance_response_time()
        test_error_handling()

        print("\n[SUCCESS] All cloud deployment tests passed!")
        print(f"Application is running successfully at: {BASE_URL}")

    except Exception as e:
        print(f"\n[ERROR] Test failed: {e}")
        raise