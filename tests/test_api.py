"""
Tests for MAPS REST API
"""

import pytest
from fastapi.testclient import TestClient
from maps.api.app import create_app


@pytest.fixture
def client():
    """Create test client"""
    app = create_app()
    return TestClient(app)


def test_health_check(client):
    """Test health check endpoint"""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "MAPS API"
    assert "timestamp" in data


def test_status_check(client):
    """Test status endpoint"""
    response = client.get("/api/status")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "operational"
    assert "components" in data
    assert "timestamp" in data


def test_list_profiles(client):
    """Test profile listing"""
    response = client.get("/api/profiles")
    assert response.status_code == 200
    data = response.json()
    assert "profiles" in data
    assert isinstance(data["profiles"], list)


def test_keyword_normalize(client):
    """Test keyword normalization"""
    response = client.get("/api/keywords/normalize?keyword=lung")
    assert response.status_code == 200
    data = response.json()
    assert "original" in data
    assert "normalized" in data
    assert data["original"] == "lung"


def test_keyword_search(client):
    """Test keyword search"""
    response = client.get("/api/keywords/search?query=lung")
    assert response.status_code == 200
    data = response.json()
    assert "query" in data
    assert "results" in data


def test_invalid_endpoint(client):
    """Test invalid endpoint returns 404"""
    response = client.get("/api/invalid")
    assert response.status_code == 404
