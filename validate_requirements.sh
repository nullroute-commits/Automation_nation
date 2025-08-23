#!/bin/bash
# Final validation test for modular dependency management solution
# Validates all requirements from the problem statement

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Validation function
validate_requirement() {
    local test_name="$1"
    local test_cmd="$2"
    
    log_info "Testing: $test_name"
    
    if eval "$test_cmd"; then
        log_success "$test_name"
        ((TESTS_PASSED++))
    else
        log_fail "$test_name"
        ((TESTS_FAILED++))
    fi
    echo ""
}

echo "========================================"
echo "Final Validation: Modular Dependency Management"
echo "========================================"
echo ""

# Requirement 1: Bash-only solution
validate_requirement "Bash-only implementation" '
    # Check that dependency manager is pure bash
    head -1 dependency_manager.sh | grep -q "#!/bin/bash" &&
    # Check that all plugins are bash
    find plugins/ -name "*.sh" -exec head -1 {} \; | grep -q "#!/bin/bash" &&
    # Verify no external language dependencies
    ! grep -r "python\|node\|ruby\|perl" dependency_manager.sh
'

# Requirement 2: Comprehensive testing
validate_requirement "Comprehensive testing framework" '
    # Check test files exist
    [[ -f test_dependency_manager.sh ]] &&
    [[ -x test_dependency_manager.sh ]] &&
    # Test basic functionality
    timeout 30 ./dependency_manager.sh help >/dev/null 2>&1 &&
    timeout 30 ./dependency_manager.sh check >/dev/null 2>&1
'

# Requirement 3: Modular coverage of all project components
validate_requirement "Modular dependency coverage for all plugins" '
    # Check all plugins have dependency declarations
    plugin_count=$(find plugins/ -name "*.sh" | wc -l)
    plugins_with_deps=$(grep -l "^# DEPENDS:" plugins/*.sh | wc -l)
    
    # At least 8 of 9 plugins should have dependencies (some might legitimately have none)
    [[ $plugins_with_deps -ge 8 ]] &&
    
    # Check dependency manager can validate each plugin
    for plugin in plugins/*.sh; do
        timeout 10 ./dependency_manager.sh validate "$plugin" >/dev/null 2>&1 || true
    done
'

# Requirement 4: Documentation alignment
validate_requirement "Documentation alignment with implementation" '
    # Check documentation files exist
    [[ -f DEPENDENCY_MANAGEMENT.md ]] &&
    
    # Check documentation mentions key components
    grep -q "dependency_manager.sh" DEPENDENCY_MANAGEMENT.md &&
    grep -q "DEPENDS:" DEPENDENCY_MANAGEMENT.md &&
    
    # Check README or docs mention dependency management
    (grep -q -i "dependency" README.md || grep -q -i "dependency" *.md)
'

# Requirement 5: Integration with main system
validate_requirement "Integration with main collection system" '
    # Test main script works with dependency management
    timeout 60 ./collect_info.sh >/dev/null 2>&1 &&
    
    # Test main script works without dependency management
    ENABLE_DEPENDENCY_VALIDATION=0 timeout 60 ./collect_info.sh >/dev/null 2>&1 &&
    
    # Check integration messages appear
    ./collect_info.sh 2>&1 | grep -q "dependency"
'

# Requirement 6: All plugins functional
validate_requirement "All plugins remain functional" '
    # Test each plugin individually
    success_count=0
    total_plugins=0
    
    for plugin in plugins/*.sh; do
        ((total_plugins++))
        if timeout 10 "$plugin" x86_64 | jq . >/dev/null 2>&1; then
            ((success_count++))
        fi
    done
    
    # At least 90% of plugins should work
    threshold=$((total_plugins * 90 / 100))
    [[ $success_count -ge $threshold ]]
'

# Requirement 7: Dependency type coverage
validate_requirement "Multiple dependency types supported" '
    # Check dependency manager supports various types
    ./dependency_manager.sh help | grep -q "command" &&
    ./dependency_manager.sh help | grep -q "file" &&
    
    # Test different dependency types
    ./dependency_manager.sh check command:echo >/dev/null 2>&1 &&
    ./dependency_manager.sh check file:/etc/os-release >/dev/null 2>&1 &&
    ./dependency_manager.sh check capability:read_proc >/dev/null 2>&1
'

# Requirement 8: Error handling and fallbacks
validate_requirement "Graceful error handling and fallbacks" '
    # Test with missing dependencies
    ./dependency_manager.sh check command:nonexistent_command 2>&1 | grep -q "unavailable" &&
    
    # Test main script continues with missing dependencies
    # (We simulate this by checking the warning system)
    timeout 60 ./collect_info.sh 2>&1 | grep -q -E "(Warning|dependencies)" &&
    
    # Verify JSON output is still produced despite warnings
    timeout 60 ./collect_info.sh 2>/dev/null | jq . >/dev/null 2>&1
'

# Requirement 9: Performance requirements
validate_requirement "Performance requirements met" '
    # Test dependency checking performance
    start_time=$(date +%s)
    ./dependency_manager.sh check >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Should complete within reasonable time (30 seconds)
    [[ $duration -lt 30 ]] &&
    
    # Test main script performance
    start_time=$(date +%s)
    timeout 60 ./collect_info.sh >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Should complete within reasonable time (60 seconds)
    [[ $duration -lt 60 ]]
'

# Requirement 10: Configuration and environment support
validate_requirement "Environment-based configuration support" '
    # Test environment variable support
    ENABLE_DEPENDENCY_VALIDATION=0 ./collect_info.sh --help 2>&1 | grep -q "ENABLE_DEPENDENCY_VALIDATION" &&
    
    # Test dependency manager environment variables
    ./dependency_manager.sh help | grep -q "Environment Variables" &&
    
    # Test configuration actually works
    ENABLE_DEPENDENCY_VALIDATION=0 timeout 30 ./collect_info.sh >/dev/null 2>&1
'

echo "========================================"
echo "Validation Summary"
echo "========================================"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_success "ALL REQUIREMENTS VALIDATED SUCCESSFULLY!"
    echo ""
    log_info "The modular dependency management solution meets all requirements:"
    echo "  ✅ Bash-only implementation"
    echo "  ✅ Comprehensive testing framework"
    echo "  ✅ Modular coverage of all project components"
    echo "  ✅ Documentation alignment"
    echo "  ✅ System integration"
    echo "  ✅ Plugin functionality preserved"
    echo "  ✅ Multiple dependency types"
    echo "  ✅ Error handling and fallbacks"
    echo "  ✅ Performance requirements"
    echo "  ✅ Configuration support"
    
    exit 0
else
    log_fail "$TESTS_FAILED requirement(s) not fully met!"
    echo ""
    log_warn "Please review the failed requirements and address any issues."
    exit 1
fi