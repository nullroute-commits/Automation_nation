#!/bin/bash
# Comprehensive test suite for the dependency manager
# Tests all aspects of dependency resolution, validation, and fallback mechanisms

set -e

# Test configuration
TEST_DIR="/tmp/dependency_test"
TEST_PLUGIN_DIR="$TEST_DIR/plugins"
DEPENDENCY_MANAGER="./dependency_manager.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Test execution framework
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    log_info "Running test: $test_name"
    
    if $test_function; then
        ((TESTS_PASSED++))
        log_success "$test_name"
    else
        ((TESTS_FAILED++))
        log_fail "$test_name"
    fi
    echo ""
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test directories
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_PLUGIN_DIR"
    
    # Create test plugins with various dependency scenarios
    create_test_plugins
    
    log_success "Test environment setup complete"
}

# Create test plugins
create_test_plugins() {
    # Plugin with all available dependencies
    cat > "$TEST_PLUGIN_DIR/01_basic_test.sh" << 'EOF'
#!/bin/bash
# DEPENDS: command:echo
# DEPENDS: command:grep
# DEPENDS: file:/etc/os-release

ARCH="$1"
echo '{"test": "basic", "status": "ok", "architecture": "'$ARCH'"}'
EOF

    # Plugin with missing dependencies
    cat > "$TEST_PLUGIN_DIR/02_missing_deps.sh" << 'EOF'
#!/bin/bash
# DEPENDS: command:nonexistent_command
# DEPENDS: file:/nonexistent/file
# DEPENDS: capability:nonexistent_capability

ARCH="$1"
echo '{"test": "missing_deps", "status": "ok", "architecture": "'$ARCH'"}'
EOF

    # Plugin with mixed dependencies
    cat > "$TEST_PLUGIN_DIR/03_mixed_deps.sh" << 'EOF'
#!/bin/bash
# DEPENDS: command:echo
# DEPENDS: command:nonexistent_tool
# DEPENDS: file:/proc/version

ARCH="$1"
echo '{"test": "mixed_deps", "status": "ok", "architecture": "'$ARCH'"}'
EOF

    # Plugin with no dependencies
    cat > "$TEST_PLUGIN_DIR/04_no_deps.sh" << 'EOF'
#!/bin/bash

ARCH="$1"
echo '{"test": "no_deps", "status": "ok", "architecture": "'$ARCH'"}'
EOF

    # Make all test plugins executable
    chmod +x "$TEST_PLUGIN_DIR"/*.sh
}

# Test 1: Basic dependency manager functionality
test_basic_functionality() {
    # Test help command
    if ! timeout 10 "$DEPENDENCY_MANAGER" help >/dev/null 2>&1; then
        return 1
    fi
    
    # Test check command
    if ! timeout 30 "$DEPENDENCY_MANAGER" check >/dev/null 2>&1; then
        return 1
    fi
    
    # Test report generation
    if ! timeout 30 "$DEPENDENCY_MANAGER" report json >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Test 2: Command dependency detection
test_command_dependencies() {
    # Test existing command
    if ! "$DEPENDENCY_MANAGER" check command:echo 2>&1 | grep -q "available"; then
        return 1
    fi
    
    # Test non-existing command
    if ! "$DEPENDENCY_MANAGER" check command:nonexistent_command 2>&1 | grep -q "unavailable"; then
        return 1
    fi
    
    return 0
}

# Test 3: File dependency detection
test_file_dependencies() {
    # Test existing file
    if ! "$DEPENDENCY_MANAGER" check file:/etc/os-release 2>&1 | grep -q "available"; then
        return 1
    fi
    
    # Test non-existing file
    if ! "$DEPENDENCY_MANAGER" check file:/nonexistent/file 2>&1 | grep -q "unavailable"; then
        return 1
    fi
    
    return 0
}

# Test 4: Capability dependency detection
test_capability_dependencies() {
    # Test proc reading capability
    if ! "$DEPENDENCY_MANAGER" check capability:read_proc 2>&1 | grep -q "available"; then
        return 1
    fi
    
    # Test architecture capability
    if ! "$DEPENDENCY_MANAGER" check capability:arch 2>&1 | grep -q "available"; then
        return 1
    fi
    
    return 0
}

# Test 5: Plugin dependency validation - all available
test_plugin_validation_success() {
    local result
    result=$("$DEPENDENCY_MANAGER" validate "$TEST_PLUGIN_DIR/01_basic_test.sh" 2>&1)
    
    if ! echo "$result" | grep -q "All dependencies satisfied"; then
        return 1
    fi
    
    # Should exit with code 0
    if ! "$DEPENDENCY_MANAGER" validate "$TEST_PLUGIN_DIR/01_basic_test.sh" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Test 6: Plugin dependency validation - missing dependencies
test_plugin_validation_failure() {
    local result
    result=$("$DEPENDENCY_MANAGER" validate "$TEST_PLUGIN_DIR/02_missing_deps.sh" 2>&1)
    
    if ! echo "$result" | grep -q "Dependency not available"; then
        return 1
    fi
    
    # Should exit with non-zero code
    if "$DEPENDENCY_MANAGER" validate "$TEST_PLUGIN_DIR/02_missing_deps.sh" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Test 7: Plugin with no dependencies
test_plugin_no_dependencies() {
    local result
    result=$("$DEPENDENCY_MANAGER" validate "$TEST_PLUGIN_DIR/04_no_deps.sh" 2>&1)
    
    if ! echo "$result" | grep -q "No dependencies declared"; then
        return 1
    fi
    
    # Should exit with code 0
    if ! "$DEPENDENCY_MANAGER" validate "$TEST_PLUGIN_DIR/04_no_deps.sh" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# Test 8: JSON report generation
test_json_report() {
    local json_output
    json_output=$("$DEPENDENCY_MANAGER" report json 2>/dev/null)
    
    # Basic JSON structure validation
    if ! echo "$json_output" | grep -q '"timestamp"'; then
        return 1
    fi
    
    if ! echo "$json_output" | grep -q '"dependency_manager_version"'; then
        return 1
    fi
    
    if ! echo "$json_output" | grep -q '"dependencies"'; then
        return 1
    fi
    
    # Validate with jq if available
    if command -v jq >/dev/null 2>&1; then
        if ! echo "$json_output" | jq . >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    return 0
}

# Test 9: Text report generation
test_text_report() {
    local text_output
    text_output=$("$DEPENDENCY_MANAGER" report text 2>/dev/null)
    
    # Check for expected report sections
    if ! echo "$text_output" | grep -q "Dependency Management Report"; then
        return 1
    fi
    
    if ! echo "$text_output" | grep -q "External command/binary Dependencies"; then
        return 1
    fi
    
    return 0
}

# Test 10: Dependency caching
test_dependency_caching() {
    local cache_file="/tmp/test_dependency_cache.json"
    
    # Remove existing cache
    rm -f "$cache_file"
    
    # Run with caching enabled
    DEPENDENCY_CACHE_FILE="$cache_file" ENABLE_DEPENDENCY_CACHING=1 \
        "$DEPENDENCY_MANAGER" check >/dev/null 2>&1
    
    # Check if cache file was created
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    # Verify cache file contains valid JSON
    if command -v jq >/dev/null 2>&1; then
        if ! jq . "$cache_file" >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    # Clean up
    rm -f "$cache_file"
    return 0
}

# Test 11: Integration with collect_info.sh
test_integration_with_main_script() {
    # Set environment for dependency validation
    export ENABLE_DEPENDENCY_VALIDATION=1
    export PLUGIN_DIR="$TEST_PLUGIN_DIR"
    
    # Test that collect_info.sh can use the dependency manager
    local output
    output=$(timeout 30 ./collect_info.sh 2>&1)
    
    # Should show dependency warnings for missing dependencies
    if ! echo "$output" | grep -q "has unmet dependencies"; then
        # This might not be present if all deps are available, so we'll check for initialization
        if ! echo "$output" | grep -q "Initializing dependency management"; then
            return 1
        fi
    fi
    
    # Should still produce valid JSON output despite dependency issues
    if ! echo "$output" | grep -q '"detected_architecture"'; then
        return 1
    fi
    
    return 0
}

# Test 12: Performance test
test_performance() {
    local start_time end_time duration
    
    start_time=$(date +%s.%N)
    "$DEPENDENCY_MANAGER" check >/dev/null 2>&1
    end_time=$(date +%s.%N)
    
    # Calculate duration in seconds
    if command -v bc >/dev/null 2>&1; then
        duration=$(echo "$end_time - $start_time" | bc)
        # Should complete within 10 seconds
        if (( $(echo "$duration > 10" | bc -l) )); then
            return 1
        fi
    fi
    
    return 0
}

# Main test execution
main() {
    echo "========================================"
    echo "Dependency Manager Test Suite"
    echo "========================================"
    echo ""
    
    # Check if dependency manager exists
    if [[ ! -f "$DEPENDENCY_MANAGER" ]] || [[ ! -x "$DEPENDENCY_MANAGER" ]]; then
        log_fail "Dependency manager not found or not executable: $DEPENDENCY_MANAGER"
        exit 1
    fi
    
    # Setup test environment
    setup_test_environment
    echo ""
    
    # Run all tests
    run_test "Basic Functionality" test_basic_functionality
    run_test "Command Dependencies" test_command_dependencies
    run_test "File Dependencies" test_file_dependencies
    run_test "Capability Dependencies" test_capability_dependencies
    run_test "Plugin Validation Success" test_plugin_validation_success
    run_test "Plugin Validation Failure" test_plugin_validation_failure
    run_test "Plugin No Dependencies" test_plugin_no_dependencies
    run_test "JSON Report Generation" test_json_report
    run_test "Text Report Generation" test_text_report
    run_test "Dependency Caching" test_dependency_caching
    run_test "Integration with Main Script" test_integration_with_main_script
    run_test "Performance Test" test_performance
    
    # Test summary
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        echo ""
        log_info "Dependency manager is working correctly."
    else
        log_fail "$TESTS_FAILED test(s) failed!"
        echo ""
        log_warn "Please review the failed tests and fix any issues."
    fi
    
    # Cleanup
    rm -rf "$TEST_DIR"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"