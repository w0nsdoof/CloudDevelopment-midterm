import pytest
import requests
import json
import time

# Test configuration
BASE_URL = "http://localhost:8080"

class TestFlaskAppSimple:

    @pytest.fixture(scope="class", autouse=True)
    def ensure_app_running(self):
        """Ensure Flask app is running before tests"""
        max_retries = 10
        for i in range(max_retries):
            try:
                response = requests.get(f"{BASE_URL}/", timeout=2)
                if response.status_code == 200:
                    return
            except requests.exceptions.RequestException:
                pass
            time.sleep(1)
        raise Exception("Flask app is not running on localhost:8080")

    def test_homepage_response_code(self):
        """Test homepage returns 200 status code"""
        response = requests.get(f"{BASE_URL}/")
        assert response.status_code == 200
        assert "Hello, GCP" in response.text

    def test_api_todos_get_structure(self):
        """Test GET /api/todos returns proper structure"""
        response = requests.get(f"{BASE_URL}/api/todos")
        assert response.status_code == 200
        assert response.headers["content-type"] == "application/json"

        todos = response.json()
        assert isinstance(todos, list)

        # If there are todos, check their structure
        for todo in todos:
            assert "id" in todo
            assert "text" in todo
            assert "created_at" in todo
            assert isinstance(todo["id"], int)
            assert isinstance(todo["text"], str)
            assert isinstance(todo["created_at"], str)

    def test_api_todos_post_valid(self):
        """Test POST /api/todos with valid data"""
        todo_data = {"text": "Test todo from pytest"}

        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json=todo_data
        )

        assert response.status_code == 201
        result = response.json()
        assert "count" in result
        assert isinstance(result["count"], int)
        assert result["count"] >= 1

    def test_api_todos_post_validation_errors(self):
        """Test POST /api/todos validation errors"""
        test_cases = [
            ({}, "text field is required"),
            ({"text": ""}, "text cannot be empty"),
            ({"text": "   "}, "text cannot be empty"),
            ({"text": "x" * 256}, "text maximum 255 characters")
        ]

        for data, expected_error in test_cases:
            response = requests.post(
                f"{BASE_URL}/api/todos",
                headers={"Content-Type": "application/json"},
                json=data
            )

            assert response.status_code == 400
            result = response.json()
            assert "error" in result
            assert expected_error in result["error"]

    def test_complete_todo_workflow(self):
        """Test complete todo workflow"""
        # Get initial state
        initial_response = requests.get(f"{BASE_URL}/api/todos")
        initial_todos = initial_response.json()
        initial_count = len(initial_todos)

        # Add a todo
        todo_text = f"Workflow test todo {int(time.time())}"
        post_response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": todo_text}
        )

        assert post_response.status_code == 201
        post_result = post_response.json()
        new_count = post_result["count"]
        assert new_count == initial_count + 1

        # Verify todo was added
        get_response = requests.get(f"{BASE_URL}/api/todos")
        todos = get_response.json()
        assert len(todos) == new_count

        # Find our todo
        found_todo = None
        for todo in todos:
            if todo["text"] == todo_text:
                found_todo = todo
                break

        assert found_todo is not None
        assert found_todo["text"] == todo_text
        assert "id" in found_todo
        assert "created_at" in found_todo

    def test_api_performance(self):
        """Test API endpoints perform reasonably well"""
        # Test GET performance (should be under 1 second for local testing)
        start_time = time.time()
        response = requests.get(f"{BASE_URL}/api/todos", timeout=5)
        get_time = time.time() - start_time

        assert response.status_code == 200
        assert get_time < 1.0  # Local testing should be fast

        # Test POST performance (should be under 1 second for local testing)
        start_time = time.time()
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": "Performance test"},
            timeout=5
        )
        post_time = time.time() - start_time

        assert response.status_code == 201
        assert post_time < 1.0  # Local testing should be fast

        print(f"GET response time: {get_time:.3f}s")
        print(f"POST response time: {post_time:.3f}s")

    def test_various_todo_content(self):
        """Test todos with various content types"""
        test_todos = [
            "Simple text",
            "Text with numbers 123",
            "Special chars: !@#$%^&*()",
            "Unicode: café résumé naïve",
            "Mixed: Hello World 123! 🚀"
        ]

        added_count = 0
        for todo_text in test_todos:
            if len(todo_text) > 255:
                continue  # Skip if too long

            response = requests.post(
                f"{BASE_URL}/api/todos",
                headers={"Content-Type": "application/json"},
                json={"text": todo_text}
            )

            if response.status_code == 201:
                added_count += 1

        # Verify at least some were added successfully
        assert added_count > 0

        # Check final state
        final_response = requests.get(f"{BASE_URL}/api/todos")
        final_todos = final_response.json()

        found_count = 0
        for todo_text in test_todos:
            if any(todo["text"] == todo_text for todo in final_todos):
                found_count += 1

        print(f"Successfully added {found_count} out of {len(test_todos)} test todos")
        assert found_count >= added_count  # All successful posts should be found

    def test_error_handling(self):
        """Test error handling for invalid requests"""
        # Test invalid JSON
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            data="invalid json {"
        )
        assert response.status_code == 400

        # Test missing content type
        response = requests.post(
            f"{BASE_URL}/api/todos",
            data='{"text": "test"}'  # Send as raw data, not JSON
        )
        # This might work or fail depending on Flask's parsing
        # We just want to make sure it doesn't crash
        assert response.status_code in [201, 400, 415]

        # Test GET on non-existent endpoint
        response = requests.get(f"{BASE_URL}/nonexistent")
        assert response.status_code == 404

    def test_data_integrity(self):
        """Test that todo data maintains integrity"""
        unique_text = f"Integrity test {int(time.time() * 1000)}"

        # Add todo
        post_response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": unique_text}
        )
        assert post_response.status_code == 201

        # Retrieve and verify
        get_response = requests.get(f"{BASE_URL}/api/todos")
        todos = get_response.json()

        # Find our todo
        our_todo = None
        for todo in todos:
            if todo["text"] == unique_text:
                our_todo = todo
                break

        assert our_todo is not None
        assert our_todo["text"] == unique_text
        assert isinstance(our_todo["id"], int)
        assert our_todo["id"] > 0
        assert isinstance(our_todo["created_at"], str)
        assert len(our_todo["created_at"]) > 0  # Non-empty timestamp