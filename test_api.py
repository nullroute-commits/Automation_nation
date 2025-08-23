"""
Test suite for Automation Nation Python API
"""

import pytest
import asyncio
import json
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)


def test_root_endpoint():
    """Test the root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "timestamp" in data
    assert "status" in data
    assert data["message"] == "Automation Nation API"
    assert data["status"] == "running"


def test_health_check():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert "database" in data
    assert "services" in data


def test_list_plugins():
    """Test the plugins listing endpoint"""
    response = client.get("/plugins")
    assert response.status_code == 200
    data = response.json()
    assert "plugins" in data
    assert isinstance(data["plugins"], list)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])