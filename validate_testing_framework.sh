#!/bin/bash
# Comprehensive Testing Framework Validation Script
# Validates all components of the testing framework

set -e

echo "🧪 Comprehensive Testing Framework Validation"
echo "============================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

success_count=0
total_tests=0

run_validation() {
    local test_name="$1"
    local test_command="$2"
    
    ((total_tests++))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((success_count++))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
}

echo ""
echo "🔍 Validating Framework Components"
echo "===================================="

# Test dependencies
run_validation "BATS installation" "which bats"
run_validation "Python 3 availability" "python3 --version"
run_validation "bc calculator" "which bc"
run_validation "jq JSON processor" "which jq"

# Test core scripts
run_validation "Main script executable" "test -x ./collect_info.sh"
run_validation "Enhanced test suite executable" "test -x ./comprehensive_test_suite_enhanced.sh"
run_validation "Unified test runner executable" "test -x ./unified_test_runner.py"

# Test framework files
run_validation "Python test framework exists" "test -f ./test_comprehensive.py"
run_validation "Performance BATS tests exist" "test -f ./test/performance/enhanced_performance_test.bats"
run_validation "Security BATS tests exist" "test -f ./test/security/enhanced_security_test.bats"
run_validation "Integration BATS tests exist" "test -f ./test/integration/collect_info_test.bats"

echo ""
echo "🧪 Testing Core Functionality"
echo "============================="

# Test basic script functionality
run_validation "Basic script execution" "./collect_info.sh -o /tmp/validation_test.json"
run_validation "JSON output validation" "test -f /tmp/validation_test.json && jq . /tmp/validation_test.json"

# Test individual test suites
run_validation "BATS integration tests" "timeout 30 bats test/integration/collect_info_test.bats"
run_validation "Single security test" "timeout 30 bats test/security/enhanced_security_test.bats --filter 'should reject command injection'"
run_validation "Single performance test" "timeout 30 bats test/performance/enhanced_performance_test.bats --filter 'baseline execution time'"

# Test Python framework
run_validation "Python test imports" "python3 -c 'from test_comprehensive import IntegrationTestSuite; print(\"OK\")'"

echo ""
echo "📊 Validation Results"
echo "===================="
echo "Total validations: $total_tests"
echo "Passed: $success_count"
echo "Failed: $((total_tests - success_count))"

success_rate=$(echo "scale=1; $success_count * 100 / $total_tests" | bc -l)
echo "Success rate: ${success_rate}%"

if [ "$success_count" -eq "$total_tests" ]; then
    echo -e "\n${GREEN}🎉 All validations passed! Testing framework is ready.${NC}"
    echo ""
    echo "📋 Quick Start Commands:"
    echo "  python3 unified_test_runner.py --html    # Run all tests with HTML report"
    echo "  bats test/integration/*.bats             # Run integration tests"
    echo "  bats test/security/enhanced_security_test.bats  # Run security tests"
    echo "  bats test/performance/enhanced_performance_test.bats  # Run performance tests"
    echo "  ./comprehensive_test_suite_enhanced.sh   # Run shell test suite"
    echo ""
    echo "📖 Documentation: COMPREHENSIVE_TESTING_GUIDE.md"
    exit 0
else
    echo -e "\n${RED}❌ Some validations failed. Please check the output above.${NC}"
    exit 1
fi

# Cleanup
rm -f /tmp/validation_test.json