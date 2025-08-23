#!/usr/bin/env python3
"""
Unified Comprehensive Test Runner
Orchestrates performance, integration, and security testing across multiple frameworks
"""

import os
import sys
import subprocess
import json
import time
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import concurrent.futures
import threading
import tempfile

class TestResult:
    def __init__(self, name: str, category: str, status: str, 
                 duration: float = 0, details: str = "", metrics: Dict = None):
        self.name = name
        self.category = category
        self.status = status  # "PASS", "FAIL", "SKIP", "ERROR"
        self.duration = duration
        self.details = details
        self.metrics = metrics or {}
        self.timestamp = datetime.utcnow().isoformat()

class ComprehensiveTestRunner:
    def __init__(self, base_dir: str = "."):
        self.base_dir = Path(base_dir)
        self.results: List[TestResult] = []
        self.start_time = None
        self.config = {
            "enable_performance": True,
            "enable_integration": True,
            "enable_security": True,
            "enable_bats": True,
            "enable_python": True,
            "parallel_execution": True,
            "timeout_seconds": 300
        }
        
    def run_bats_tests(self, test_pattern: str, category: str) -> List[TestResult]:
        """Run BATS tests and parse results"""
        results = []
        
        try:
            # Find BATS test files
            test_files = list(self.base_dir.glob(test_pattern))
            
            if not test_files:
                results.append(TestResult(
                    name=f"bats_{category}_discovery",
                    category=category,
                    status="SKIP",
                    details=f"No BATS tests found matching {test_pattern}"
                ))
                return results
            
            for test_file in test_files:
                start_time = time.time()
                
                try:
                    # Run BATS test
                    process = subprocess.run(
                        ["bats", str(test_file)],
                        capture_output=True,
                        text=True,
                        timeout=self.config["timeout_seconds"]
                    )
                    
                    duration = time.time() - start_time
                    
                    # Parse BATS output
                    test_count = 0
                    passed_count = 0
                    failed_tests = []
                    
                    for line in process.stdout.split('\n'):
                        if line.startswith('ok ') or line.startswith('not ok '):
                            test_count += 1
                            if line.startswith('ok '):
                                passed_count += 1
                            else:
                                failed_tests.append(line)
                    
                    if process.returncode == 0:
                        status = "PASS"
                        details = f"All {test_count} tests passed"
                    else:
                        status = "FAIL"
                        details = f"{passed_count}/{test_count} tests passed. Failures: {'; '.join(failed_tests[:3])}"
                    
                    results.append(TestResult(
                        name=f"bats_{test_file.stem}",
                        category=category,
                        status=status,
                        duration=duration,
                        details=details,
                        metrics={
                            "total_tests": test_count,
                            "passed_tests": passed_count,
                            "failed_tests": test_count - passed_count
                        }
                    ))
                    
                except subprocess.TimeoutExpired:
                    results.append(TestResult(
                        name=f"bats_{test_file.stem}",
                        category=category,
                        status="ERROR",
                        duration=self.config["timeout_seconds"],
                        details="Test timed out"
                    ))
                    
                except Exception as e:
                    results.append(TestResult(
                        name=f"bats_{test_file.stem}",
                        category=category,
                        status="ERROR",
                        duration=time.time() - start_time,
                        details=f"Error running test: {str(e)}"
                    ))
                    
        except Exception as e:
            results.append(TestResult(
                name=f"bats_{category}_error",
                category=category,
                status="ERROR",
                details=f"Error setting up BATS tests: {str(e)}"
            ))
            
        return results
    
    def run_python_tests(self, test_file: str, category: str) -> List[TestResult]:
        """Run Python tests and parse results"""
        results = []
        
        if not os.path.exists(test_file):
            results.append(TestResult(
                name=f"python_{category}",
                category=category,
                status="SKIP",
                details=f"Python test file {test_file} not found"
            ))
            return results
        
        start_time = time.time()
        
        try:
            # Run Python test with pytest
            process = subprocess.run(
                ["python3", "-m", "pytest", test_file, "-v", "--tb=short"],
                capture_output=True,
                text=True,
                timeout=self.config["timeout_seconds"]
            )
            
            duration = time.time() - start_time
            
            # Parse pytest output
            if "FAILED" in process.stdout or process.returncode != 0:
                status = "FAIL"
                details = f"Python tests failed. Return code: {process.returncode}"
                if process.stderr:
                    details += f" Error: {process.stderr[:200]}"
            else:
                status = "PASS"
                details = "All Python tests passed"
            
            results.append(TestResult(
                name=f"python_{category}",
                category=category,
                status=status,
                duration=duration,
                details=details
            ))
            
        except subprocess.TimeoutExpired:
            results.append(TestResult(
                name=f"python_{category}",
                category=category,
                status="ERROR",
                duration=self.config["timeout_seconds"],
                details="Python tests timed out"
            ))
            
        except Exception as e:
            results.append(TestResult(
                name=f"python_{category}",
                category=category,
                status="ERROR",
                duration=time.time() - start_time,
                details=f"Error running Python tests: {str(e)}"
            ))
            
        return results
    
    def run_shell_script_tests(self, script_path: str, category: str) -> List[TestResult]:
        """Run shell script tests"""
        results = []
        
        if not os.path.exists(script_path):
            results.append(TestResult(
                name=f"shell_{category}",
                category=category,
                status="SKIP",
                details=f"Shell script {script_path} not found"
            ))
            return results
        
        start_time = time.time()
        
        try:
            # Make script executable
            os.chmod(script_path, 0o755)
            
            # Run shell script
            process = subprocess.run(
                [script_path],
                capture_output=True,
                text=True,
                timeout=self.config["timeout_seconds"]
            )
            
            duration = time.time() - start_time
            
            if process.returncode == 0:
                status = "PASS"
                details = "Shell script tests passed"
            else:
                status = "FAIL"
                details = f"Shell script failed with return code {process.returncode}"
                if process.stderr:
                    details += f" Error: {process.stderr[:200]}"
            
            results.append(TestResult(
                name=f"shell_{Path(script_path).stem}",
                category=category,
                status=status,
                duration=duration,
                details=details
            ))
            
        except subprocess.TimeoutExpired:
            results.append(TestResult(
                name=f"shell_{Path(script_path).stem}",
                category=category,
                status="ERROR",
                duration=self.config["timeout_seconds"],
                details="Shell script timed out"
            ))
            
        except Exception as e:
            results.append(TestResult(
                name=f"shell_{Path(script_path).stem}",
                category=category,
                status="ERROR",
                duration=time.time() - start_time,
                details=f"Error running shell script: {str(e)}"
            ))
            
        return results
    
    def run_performance_tests(self) -> List[TestResult]:
        """Run all performance tests"""
        print("🔄 Running Performance Tests...")
        results = []
        
        # BATS performance tests
        if self.config["enable_bats"]:
            results.extend(self.run_bats_tests("test/performance/*.bats", "performance"))
        
        # Python performance tests
        if self.config["enable_python"]:
            results.extend(self.run_python_tests("test_comprehensive.py::PerformanceTestSuite", "performance"))
        
        # Shell script performance tests
        results.extend(self.run_shell_script_tests("comprehensive_test_suite_enhanced.sh", "performance"))
        results.extend(self.run_shell_script_tests("bash_perf_suite.sh", "performance"))
        
        return results
    
    def run_security_tests(self) -> List[TestResult]:
        """Run all security tests"""
        print("🔄 Running Security Tests...")
        results = []
        
        # BATS security tests
        if self.config["enable_bats"]:
            results.extend(self.run_bats_tests("test/security/*.bats", "security"))
        
        # Python security tests
        if self.config["enable_python"]:
            results.extend(self.run_python_tests("test_comprehensive.py::SecurityTestSuite", "security"))
        
        return results
    
    def run_integration_tests(self) -> List[TestResult]:
        """Run all integration tests"""
        print("🔄 Running Integration Tests...")
        results = []
        
        # BATS integration tests
        if self.config["enable_bats"]:
            results.extend(self.run_bats_tests("test/integration/*.bats", "integration"))
        
        # Python integration tests
        if self.config["enable_python"]:
            results.extend(self.run_python_tests("test_comprehensive.py::IntegrationTestSuite", "integration"))
        
        return results
    
    def run_regression_tests(self) -> List[TestResult]:
        """Run regression tests"""
        print("🔄 Running Regression Tests...")
        results = []
        
        # BATS regression tests
        if self.config["enable_bats"]:
            results.extend(self.run_bats_tests("test/regression/*.bats", "regression"))
        
        return results
    
    def run_functional_tests(self) -> List[TestResult]:
        """Run functional tests"""
        print("🔄 Running Functional Tests...")
        results = []
        
        # BATS functional tests
        if self.config["enable_bats"]:
            results.extend(self.run_bats_tests("test/functional/*.bats", "functional"))
        
        return results
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run comprehensive test suite"""
        print("🧪 Starting Comprehensive Test Suite")
        print("=" * 50)
        
        self.start_time = time.time()
        
        # Define test categories
        test_categories = []
        
        if self.config["enable_performance"]:
            test_categories.append(("Performance", self.run_performance_tests))
        
        if self.config["enable_security"]:
            test_categories.append(("Security", self.run_security_tests))
        
        if self.config["enable_integration"]:
            test_categories.append(("Integration", self.run_integration_tests))
        
        # Always run these
        test_categories.extend([
            ("Regression", self.run_regression_tests),
            ("Functional", self.run_functional_tests)
        ])
        
        # Run tests
        if self.config["parallel_execution"]:
            # Run test categories in parallel
            with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
                future_to_category = {
                    executor.submit(test_func): category_name 
                    for category_name, test_func in test_categories
                }
                
                for future in concurrent.futures.as_completed(future_to_category):
                    category_name = future_to_category[future]
                    try:
                        category_results = future.result()
                        self.results.extend(category_results)
                        print(f"✅ {category_name} tests completed ({len(category_results)} tests)")
                    except Exception as e:
                        print(f"❌ {category_name} tests failed: {str(e)}")
                        self.results.append(TestResult(
                            name=f"{category_name.lower()}_suite",
                            category=category_name.lower(),
                            status="ERROR",
                            details=f"Test suite execution error: {str(e)}"
                        ))
        else:
            # Run test categories sequentially
            for category_name, test_func in test_categories:
                try:
                    category_results = test_func()
                    self.results.extend(category_results)
                    print(f"✅ {category_name} tests completed ({len(category_results)} tests)")
                except Exception as e:
                    print(f"❌ {category_name} tests failed: {str(e)}")
                    self.results.append(TestResult(
                        name=f"{category_name.lower()}_suite",
                        category=category_name.lower(),
                        status="ERROR",
                        details=f"Test suite execution error: {str(e)}"
                    ))
        
        total_duration = time.time() - self.start_time
        
        # Generate summary
        summary = self.generate_summary(total_duration)
        
        print("\n" + "=" * 50)
        print("📊 Test Suite Summary")
        print("=" * 50)
        print(f"Total Duration: {total_duration:.2f}s")
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed_tests']} ({summary['pass_rate']:.1f}%)")
        print(f"Failed: {summary['failed_tests']}")
        print(f"Errors: {summary['error_tests']}")
        print(f"Skipped: {summary['skipped_tests']}")
        
        # Category breakdown
        print("\n📋 Category Breakdown:")
        for category, stats in summary['category_stats'].items():
            print(f"  {category.title()}: {stats['passed']}/{stats['total']} passed")
        
        return summary
    
    def generate_summary(self, total_duration: float) -> Dict[str, Any]:
        """Generate test summary"""
        total_tests = len(self.results)
        passed_tests = len([r for r in self.results if r.status == "PASS"])
        failed_tests = len([r for r in self.results if r.status == "FAIL"])
        error_tests = len([r for r in self.results if r.status == "ERROR"])
        skipped_tests = len([r for r in self.results if r.status == "SKIP"])
        
        pass_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        # Category statistics
        category_stats = {}
        for result in self.results:
            if result.category not in category_stats:
                category_stats[result.category] = {"total": 0, "passed": 0, "failed": 0, "errors": 0, "skipped": 0}
            
            category_stats[result.category]["total"] += 1
            if result.status == "PASS":
                category_stats[result.category]["passed"] += 1
            elif result.status == "FAIL":
                category_stats[result.category]["failed"] += 1
            elif result.status == "ERROR":
                category_stats[result.category]["errors"] += 1
            elif result.status == "SKIP":
                category_stats[result.category]["skipped"] += 1
        
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "total_duration": total_duration,
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": failed_tests,
            "error_tests": error_tests,
            "skipped_tests": skipped_tests,
            "pass_rate": pass_rate,
            "category_stats": category_stats,
            "results": [
                {
                    "name": r.name,
                    "category": r.category,
                    "status": r.status,
                    "duration": r.duration,
                    "details": r.details,
                    "metrics": r.metrics,
                    "timestamp": r.timestamp
                }
                for r in self.results
            ]
        }
    
    def save_results(self, output_file: str = "test_results/comprehensive_test_results.json"):
        """Save test results to file"""
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        summary = self.generate_summary(time.time() - (self.start_time or time.time()))
        
        with open(output_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"\n📄 Test results saved to: {output_file}")
        return output_file
    
    def generate_html_report(self, output_file: str = "test_results/test_report.html"):
        """Generate HTML test report"""
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        summary = self.generate_summary(time.time() - (self.start_time or time.time()))
        
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Comprehensive Test Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background: #f0f0f0; padding: 20px; border-radius: 5px; }}
        .summary {{ display: flex; gap: 20px; margin: 20px 0; }}
        .metric {{ background: #e8f4f8; padding: 15px; border-radius: 5px; text-align: center; }}
        .metric h3 {{ margin: 0; color: #2c3e50; }}
        .metric .value {{ font-size: 24px; font-weight: bold; color: #3498db; }}
        .category {{ margin: 20px 0; }}
        .test-result {{ padding: 10px; margin: 5px 0; border-radius: 3px; }}
        .pass {{ background: #d4edda; border-left: 4px solid #28a745; }}
        .fail {{ background: #f8d7da; border-left: 4px solid #dc3545; }}
        .error {{ background: #fff3cd; border-left: 4px solid #ffc107; }}
        .skip {{ background: #e2e3e5; border-left: 4px solid #6c757d; }}
        .details {{ font-size: 12px; color: #666; margin-top: 5px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Comprehensive Test Report</h1>
        <p>Generated: {summary['timestamp']}</p>
        <p>Duration: {summary['total_duration']:.2f}s</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Total Tests</h3>
            <div class="value">{summary['total_tests']}</div>
        </div>
        <div class="metric">
            <h3>Pass Rate</h3>
            <div class="value">{summary['pass_rate']:.1f}%</div>
        </div>
        <div class="metric">
            <h3>Passed</h3>
            <div class="value" style="color: #28a745;">{summary['passed_tests']}</div>
        </div>
        <div class="metric">
            <h3>Failed</h3>
            <div class="value" style="color: #dc3545;">{summary['failed_tests']}</div>
        </div>
    </div>
    
    <h2>📋 Test Results by Category</h2>
"""
        
        # Group results by category
        categories = {}
        for result in self.results:
            if result.category not in categories:
                categories[result.category] = []
            categories[result.category].append(result)
        
        for category, results in categories.items():
            html_content += f"""
    <div class="category">
        <h3>{category.title()} Tests</h3>
"""
            for result in results:
                status_class = result.status.lower()
                if status_class == "pass":
                    status_class = "pass"
                elif status_class == "fail":
                    status_class = "fail"
                elif status_class == "error":
                    status_class = "error"
                else:
                    status_class = "skip"
                
                html_content += f"""
        <div class="test-result {status_class}">
            <strong>{result.name}</strong> - {result.status} ({result.duration:.2f}s)
            <div class="details">{result.details}</div>
        </div>
"""
            html_content += "    </div>\n"
        
        html_content += """
</body>
</html>
"""
        
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        print(f"📄 HTML report saved to: {output_file}")
        return output_file


def main():
    parser = argparse.ArgumentParser(description="Comprehensive Test Runner")
    parser.add_argument("--no-performance", action="store_true", 
                       help="Disable performance tests")
    parser.add_argument("--no-security", action="store_true", 
                       help="Disable security tests")
    parser.add_argument("--no-integration", action="store_true", 
                       help="Disable integration tests")
    parser.add_argument("--no-parallel", action="store_true", 
                       help="Disable parallel execution")
    parser.add_argument("--timeout", type=int, default=300, 
                       help="Test timeout in seconds")
    parser.add_argument("--output", default="test_results/comprehensive_test_results.json", 
                       help="Output file for results")
    parser.add_argument("--html", action="store_true", 
                       help="Generate HTML report")
    
    args = parser.parse_args()
    
    # Create test runner
    runner = ComprehensiveTestRunner()
    
    # Configure based on arguments
    runner.config.update({
        "enable_performance": not args.no_performance,
        "enable_security": not args.no_security,
        "enable_integration": not args.no_integration,
        "parallel_execution": not args.no_parallel,
        "timeout_seconds": args.timeout
    })
    
    try:
        # Run tests
        summary = runner.run_all_tests()
        
        # Save results
        runner.save_results(args.output)
        
        # Generate HTML report if requested
        if args.html:
            runner.generate_html_report()
        
        # Exit with appropriate code
        if summary['failed_tests'] > 0 or summary['error_tests'] > 0:
            sys.exit(1)
        else:
            print("\n🎉 All tests passed successfully!")
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n⚠️ Test execution interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Test execution failed: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()