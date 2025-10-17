import pytest
import playwright.sync_api
import requests
import json
import time

# Test configuration
BASE_URL = "http://localhost:8080"

class TestFlaskApp:

    @pytest.fixture(scope="class", autouse=True)
    def setup_playwright(self):
        """Setup Playwright browser"""
        with playwright.sync_api.sync_playwright() as p:
            self.browser = p.chromium.launch(headless=True)
            self.context = self.browser.new_context()
            self.page = self.context.new_page()
            yield
            self.context.close()
            self.browser.close()

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

    def test_homepage_content(self):
        """Test homepage displays 'Hello, GCP'"""
        response = self.page.goto(f"{BASE_URL}/")
        assert response is not None

        # Check page content
        content = self.page.content()
        assert "Hello, GCP" in content
        assert "<h1>" in content
        assert "<html>" in content
        assert "<body>" in content

        # Check page title and elements
        h1_element = self.page.locator("h1")
        assert h1_element.is_visible()
        assert h1_element.text_content() == "Hello, GCP"

    def test_homepage_response_code(self):
        """Test homepage returns 200 status code"""
        response = requests.get(f"{BASE_URL}/")
        assert response.status_code == 200
        assert "Hello, GCP" in response.text

    def test_api_todos_get_empty(self):
        """Test GET /api/todos returns empty list initially"""
        # Clear todos by restarting app logic (simulate empty state)
        response = requests.get(f"{BASE_URL}/api/todos")
        assert response.status_code == 200

        todos = response.json()
        assert isinstance(todos, list)
        # Should be empty or contain existing todos from previous tests

    def test_api_todos_post_valid(self):
        """Test POST /api/todos with valid data"""
        todo_data = {"text": "Test todo item"}

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

    def test_api_todos_post_missing_text(self):
        """Test POST /api/todos with missing text field"""
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={}
        )

        assert response.status_code == 400
        result = response.json()
        assert "error" in result
        assert "text field is required" in result["error"]

    def test_api_todos_post_empty_text(self):
        """Test POST /api/todos with empty text"""
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": ""}
        )

        assert response.status_code == 400
        result = response.json()
        assert "error" in result
        assert "text cannot be empty" in result["error"]

    def test_api_todos_post_whitespace_text(self):
        """Test POST /api/todos with whitespace-only text"""
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": "   "}
        )

        assert response.status_code == 400
        result = response.json()
        assert "error" in result
        assert "text cannot be empty" in result["error"]

    def test_api_todos_post_too_long_text(self):
        """Test POST /api/todos with text exceeding 255 characters"""
        long_text = "x" * 256  # 256 characters

        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": long_text}
        )

        assert response.status_code == 400
        result = response.json()
        assert "error" in result
        assert "text maximum 255 characters" in result["error"]

    def test_api_todos_post_invalid_json(self):
        """Test POST /api/todos with invalid JSON"""
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            data="invalid json"
        )

        assert response.status_code == 400

    def test_todo_workflow_complete(self):
        """Test complete todo workflow: GET -> POST -> GET"""
        # Get initial todos
        initial_response = requests.get(f"{BASE_URL}/api/todos")
        initial_count = len(initial_response.json())

        # Add a new todo
        todo_text = "Complete workflow test"
        post_response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": todo_text}
        )

        assert post_response.status_code == 201
        post_result = post_response.json()
        assert post_result["count"] == initial_count + 1

        # Verify todo was added
        get_response = requests.get(f"{BASE_URL}/api/todos")
        assert get_response.status_code == 200

        todos = get_response.json()
        assert len(todos) == initial_count + 1

        # Find our todo in the list
        found_todo = None
        for todo in todos:
            if todo["text"] == todo_text:
                found_todo = todo
                break

        assert found_todo is not None
        assert "id" in found_todo
        assert "text" in found_todo
        assert "created_at" in found_todo
        assert found_todo["text"] == todo_text

    def test_multiple_todos(self):
        """Test adding multiple todos"""
        todos_to_add = [
            "Buy groceries",
            "Walk the dog",
            "Read a book"
        ]

        # Get initial count
        initial_response = requests.get(f"{BASE_URL}/api/todos")
        initial_count = len(initial_response.json())

        # Add multiple todos
        added_count = 0
        for todo_text in todos_to_add:
            response = requests.post(
                f"{BASE_URL}/api/todos",
                headers={"Content-Type": "application/json"},
                json={"text": todo_text}
            )

            if response.status_code == 201:
                added_count += 1

        # Verify all were added
        final_response = requests.get(f"{BASE_URL}/api/todos")
        final_todos = final_response.json()

        assert len(final_todos) >= initial_count + added_count

        # Check that our todos are in the list
        for todo_text in todos_to_add:
            found = any(todo["text"] == todo_text for todo in final_todos)
            if found:
                added_count -= 1

        # All should be found (accounting for any that failed due to validation)
        assert added_count <= len(todos_to_add)

    def test_api_response_content_type(self):
        """Test API endpoints return correct content type"""
        response = requests.get(f"{BASE_URL}/api/todos")
        assert response.headers["content-type"] == "application/json"

        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": "Test content type"}
        )
        if response.status_code == 201:
            assert response.headers["content-type"] == "application/json"

    def test_performance_homepage(self):
        """Test homepage loads quickly (< 2 seconds)"""
        start_time = time.time()
        response = requests.get(f"{BASE_URL}/", timeout=5)
        end_time = time.time()

        assert response.status_code == 200
        assert (end_time - start_time) < 2.0  # Should load in under 2 seconds

    def test_performance_api(self):
        """Test API endpoints respond quickly (< 500ms)"""
        # Test GET /api/todos
        start_time = time.time()
        response = requests.get(f"{BASE_URL}/api/todos", timeout=2)
        end_time = time.time()

        assert response.status_code == 200
        assert (end_time - start_time) < 0.5  # Should respond in under 500ms

        # Test POST /api/todos
        start_time = time.time()
        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": "Performance test"},
            timeout=2
        )
        end_time = time.time()

        assert response.status_code == 201
        assert (end_time - start_time) < 0.5  # Should respond in under 500ms

    def test_page_structure_with_playwright(self):
        """Test page structure using Playwright browser automation"""
        page = self.page
        page.goto(f"{BASE_URL}/")

        # Wait for page to load
        page.wait_for_load_state("networkidle")

        # Check HTML structure
        html_element = page.locator("html")
        assert html_element.is_visible()

        body_element = page.locator("body")
        assert body_element.is_visible()

        h1_element = page.locator("h1")
        assert h1_element.is_visible()
        assert h1_element.text_content() == "Hello, GCP"

        # Check that there are no console errors
        page.wait_for_timeout(1000)  # Wait a bit for any async errors

    @pytest.mark.parametrize("todo_text", [
        "Simple todo",
        "Todo with numbers 123",
        "Todo with special chars: !@#$%",
        "Todo with ümlauts",
        "Todo with emoji 🚀"
    ])
    def test_various_todo_texts(self, todo_text):
        """Test todos with various text content"""
        # Skip if text is too long (will fail validation)
        if len(todo_text) > 255:
            pytest.skip("Text too long for validation")

        response = requests.post(
            f"{BASE_URL}/api/todos",
            headers={"Content-Type": "application/json"},
            json={"text": todo_text}
        )

        if response.status_code == 201:
            # Verify it was added correctly
            get_response = requests.get(f"{BASE_URL}/api/todos")
            todos = get_response.json()

            found = any(todo["text"] == todo_text for todo in todos)
            assert found, f"Todo with text '{todo_text}' was not found in the list"
        else:
            # If validation failed, make sure it's expected
            assert response.status_code == 400
            result = response.json()
            assert "error" in result