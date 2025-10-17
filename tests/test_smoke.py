import requests
import pytest

def test_homepage():
    """Test that homepage returns 200 status"""
    response = requests.get('http://localhost:8080', timeout=10)
    assert response.status_code == 200
    assert 'Hello, GCP' in response.text