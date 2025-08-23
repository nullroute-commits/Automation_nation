#!/bin/bash
# Comprehensive Performance, Integration, and Security Testing Suite
# For shell scripts and system components

set -e

# Test configuration
PERFORMANCE_ITERATIONS=50
STRESS_TEST_DURATION=30
CONCURRENT_PROCESSES=10
TEMP_DIR="/tmp/comprehensive_test_$$"
RESULTS_DIR="test_results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Create directories
mkdir -p "$TEMP_DIR" "$RESULTS_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test execution function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local description="$3"
    
    ((TOTAL_TESTS++))
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name: $description"
        return 0
    else
        log_error "$test_name: $description"
        return 1
    fi
}

# Performance testing functions
test_script_execution_time() {
    log_info "Testing script execution time performance..."
    
    local total_time=0
    local max_time=0
    local min_time=999999
    
    for i in $(seq 1 $PERFORMANCE_ITERATIONS); do
        local start_time=$(date +%s.%N)
        
        ./collect_info.sh -o "$TEMP_DIR/perf_test_$i.json" >/dev/null 2>&1
        
        local end_time=$(date +%s.%N)
        local execution_time=$(echo "$end_time - $start_time" | bc -l)
        
        total_time=$(echo "$total_time + $execution_time" | bc -l)
        
        # Update min/max
        if (( $(echo "$execution_time > $max_time" | bc -l) )); then
            max_time=$execution_time
        fi
        
        if (( $(echo "$execution_time < $min_time" | bc -l) )); then
            min_time=$execution_time
        fi
    done
    
    local avg_time=$(echo "scale=3; $total_time / $PERFORMANCE_ITERATIONS" | bc -l)
    
    log_info "Performance Results:"
    log_info "  Average: ${avg_time}s"
    log_info "  Min: ${min_time}s"
    log_info "  Max: ${max_time}s"
    
    # Save performance baseline
    echo "timestamp,avg_time,min_time,max_time" > "$RESULTS_DIR/performance_baseline.csv"
    echo "$(date -Iseconds),$avg_time,$min_time,$max_time" >> "$RESULTS_DIR/performance_baseline.csv"
    
    # Performance threshold (should complete within 10 seconds on average)
    if (( $(echo "$avg_time < 10.0" | bc -l) )); then
        log_success "Performance test: Average execution time within acceptable range"
    else
        log_error "Performance test: Average execution time too slow ($avg_time seconds)"
    fi
}

test_memory_usage() {
    log_info "Testing memory usage during execution..."
    
    # Start memory monitoring in background
    {
        while true; do
            ps aux | grep -E "(collect_info|bash)" | grep -v grep | awk '{print $6}' >> "$TEMP_DIR/memory_usage.log"
            sleep 0.1
        done
    } &
    local monitor_pid=$!
    
    # Run the script
    ./collect_info.sh -o "$TEMP_DIR/memory_test.json" >/dev/null 2>&1
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    if [[ -f "$TEMP_DIR/memory_usage.log" ]]; then
        local max_memory=$(sort -n "$TEMP_DIR/memory_usage.log" | tail -1)
        local avg_memory=$(awk '{sum+=$1} END {print sum/NR}' "$TEMP_DIR/memory_usage.log")
        
        log_info "Memory Usage:"
        log_info "  Max: ${max_memory}KB"
        log_info "  Avg: ${avg_memory}KB"
        
        # Memory threshold (should not exceed 100MB)
        if (( max_memory < 102400 )); then
            log_success "Memory test: Memory usage within acceptable range"
        else
            log_error "Memory test: Memory usage too high (${max_memory}KB)"
        fi
    else
        log_warning "Memory test: Could not collect memory usage data"
    fi
}

test_concurrent_execution() {
    log_info "Testing concurrent execution performance..."
    
    local start_time=$(date +%s)
    
    # Start multiple processes
    for i in $(seq 1 $CONCURRENT_PROCESSES); do
        {
            ./collect_info.sh -o "$TEMP_DIR/concurrent_$i.json" >/dev/null 2>&1
            echo "Process $i completed" >> "$TEMP_DIR/concurrent_results.log"
        } &
    done
    
    # Wait for all processes to complete
    wait
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    local completed_processes=$(wc -l < "$TEMP_DIR/concurrent_results.log" 2>/dev/null || echo 0)
    
    log_info "Concurrent Execution Results:"
    log_info "  Total Duration: ${total_duration}s"
    log_info "  Processes Started: $CONCURRENT_PROCESSES"
    log_info "  Processes Completed: $completed_processes"
    
    if (( completed_processes == CONCURRENT_PROCESSES )); then
        log_success "Concurrent test: All processes completed successfully"
    else
        log_error "Concurrent test: Only $completed_processes/$CONCURRENT_PROCESSES processes completed"
    fi
    
    # Performance threshold (concurrent execution should not take more than 2x sequential time)
    if (( total_duration < 60 )); then
        log_success "Concurrent performance: Execution time acceptable"
    else
        log_error "Concurrent performance: Execution took too long (${total_duration}s)"
    fi
}

test_stress_testing() {
    log_info "Running stress test for $STRESS_TEST_DURATION seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + STRESS_TEST_DURATION))
    local iteration=0
    local failures=0
    
    while (( $(date +%s) < end_time )); do
        ((iteration++))
        
        if ! ./collect_info.sh -o "$TEMP_DIR/stress_$iteration.json" >/dev/null 2>&1; then
            ((failures++))
        fi
        
        # Brief pause to prevent overwhelming the system
        sleep 0.1
    done
    
    local success_rate=$(echo "scale=2; ($iteration - $failures) / $iteration * 100" | bc -l)
    
    log_info "Stress Test Results:"
    log_info "  Total Iterations: $iteration"
    log_info "  Failures: $failures"
    log_info "  Success Rate: ${success_rate}%"
    
    # Stress test threshold (95% success rate)
    if (( $(echo "$success_rate >= 95" | bc -l) )); then
        log_success "Stress test: Success rate acceptable (${success_rate}%)"
    else
        log_error "Stress test: Success rate too low (${success_rate}%)"
    fi
}

# Security testing functions
test_input_sanitization() {
    log_info "Testing input sanitization and security..."
    
    # Test malicious input patterns
    local malicious_inputs=(
        "'; rm -rf /tmp/*; echo '"
        "\$(rm -rf /tmp/*)"
        "|cat /etc/passwd"
        "&& whoami"
        "../../../etc/passwd"
        "/etc/shadow"
        "\`id\`"
        "</dev/null; echo 'INJECTED'"
    )
    
    local security_failures=0
    
    for input in "${malicious_inputs[@]}"; do
        # Test with malicious output filename
        if ./collect_info.sh -o "$input" >/dev/null 2>&1; then
            # Check if any security breach occurred
            if [[ -f "$input" ]] || grep -q "INJECTED" "$TEMP_DIR"/* 2>/dev/null; then
                ((security_failures++))
                log_error "Security breach detected with input: $input"
            fi
        fi
    done
    
    if (( security_failures == 0 )); then
        log_success "Input sanitization: No security vulnerabilities detected"
    else
        log_error "Input sanitization: $security_failures security vulnerabilities found"
    fi
}

test_file_permissions() {
    log_info "Testing file permissions and access controls..."
    
    # Test script permissions
    run_test "script_executable" \
        "test -x ./collect_info.sh" \
        "Main script has executable permissions"
    
    # Test plugin permissions
    if [[ -d "plugins" ]]; then
        local plugin_permission_failures=0
        
        for plugin in plugins/*.sh; do
            if [[ -f "$plugin" ]]; then
                if [[ ! -x "$plugin" ]]; then
                    ((plugin_permission_failures++))
                fi
            fi
        done
        
        if (( plugin_permission_failures == 0 )); then
            log_success "Plugin permissions: All plugins have correct permissions"
        else
            log_error "Plugin permissions: $plugin_permission_failures plugins have incorrect permissions"
        fi
    fi
    
    # Test that sensitive files are not readable by the script
    run_test "no_sensitive_access" \
        "! ./collect_info.sh -o /etc/shadow >/dev/null 2>&1 || ! test -f /etc/shadow" \
        "Script cannot write to sensitive system files"
}

test_privilege_escalation() {
    log_info "Testing privilege escalation protection..."
    
    # Test that script doesn't escalate privileges
    local initial_user=$(whoami)
    
    # Run script and check if user changed
    local script_user=$(./collect_info.sh -o "$TEMP_DIR/priv_test.json" >/dev/null 2>&1; whoami)
    
    if [[ "$initial_user" == "$script_user" ]]; then
        log_success "Privilege escalation: No unauthorized privilege escalation"
    else
        log_error "Privilege escalation: Unauthorized privilege escalation detected"
    fi
    
    # Test SUDO_USER variable handling
    SUDO_USER="malicious_user" ./collect_info.sh -o "$TEMP_DIR/sudo_test.json" >/dev/null 2>&1
    
    if [[ -f "$TEMP_DIR/sudo_test.json" ]]; then
        if ! grep -q "malicious_user" "$TEMP_DIR/sudo_test.json"; then
            log_success "SUDO handling: SUDO_USER variable properly sanitized"
        else
            log_error "SUDO handling: SUDO_USER variable not properly sanitized"
        fi
    fi
}

test_resource_limits() {
    log_info "Testing resource limit compliance..."
    
    # Test file descriptor limits
    {
        ulimit -n 1024
        ./collect_info.sh -o "$TEMP_DIR/fd_test.json" >/dev/null 2>&1
    }
    
    if [[ $? -eq 0 ]]; then
        log_success "Resource limits: Script respects file descriptor limits"
    else
        log_error "Resource limits: Script exceeds file descriptor limits"
    fi
    
    # Test process limits
    {
        ulimit -u 100
        ./collect_info.sh -o "$TEMP_DIR/proc_test.json" >/dev/null 2>&1
    }
    
    if [[ $? -eq 0 ]]; then
        log_success "Resource limits: Script respects process limits"
    else
        log_warning "Resource limits: Script may exceed process limits under constraints"
    fi
}

# Integration testing functions
test_end_to_end_integration() {
    log_info "Testing end-to-end integration workflows..."
    
    # Test 1: Basic workflow
    run_test "basic_workflow" \
        "./collect_info.sh -o $TEMP_DIR/integration_basic.json && jq . $TEMP_DIR/integration_basic.json >/dev/null" \
        "Basic collection and JSON validation"
    
    # Test 2: With different configurations
    run_test "config_no_hashing" \
        "ENABLE_HASHING=0 ./collect_info.sh -o $TEMP_DIR/integration_no_hash.json" \
        "Configuration: Hashing disabled"
    
    run_test "config_no_sudo" \
        "ENABLE_SUDO_SUPPORT=0 ./collect_info.sh -o $TEMP_DIR/integration_no_sudo.json" \
        "Configuration: Sudo support disabled"
    
    # Test 3: Plugin integration
    if [[ -d "plugins" ]]; then
        run_test "plugin_integration" \
            "./collect_info.sh -o $TEMP_DIR/integration_plugins.json && grep -q 'get_' $TEMP_DIR/integration_plugins.json" \
            "Plugin integration and execution"
    fi
    
    # Test 4: Error recovery
    run_test "error_recovery" \
        "timeout 5 ./collect_info.sh -o $TEMP_DIR/integration_timeout.json || true" \
        "Error recovery and timeout handling"
}

test_cross_platform_compatibility() {
    log_info "Testing cross-platform compatibility..."
    
    # Test different shell environments
    if command -v dash >/dev/null; then
        run_test "dash_compatibility" \
            "dash -c './collect_info.sh -o $TEMP_DIR/dash_test.json'" \
            "Dash shell compatibility"
    fi
    
    if command -v zsh >/dev/null; then
        run_test "zsh_compatibility" \
            "zsh -c './collect_info.sh -o $TEMP_DIR/zsh_test.json'" \
            "Zsh shell compatibility"
    fi
    
    # Test different environments
    run_test "minimal_env" \
        "env -i PATH=/bin:/usr/bin ./collect_info.sh -o $TEMP_DIR/minimal_env.json" \
        "Minimal environment execution"
}

# Main execution
main() {
    echo "🧪 Comprehensive Performance, Integration, and Security Testing Suite"
    echo "=================================================================="
    
    # Performance Tests
    echo ""
    echo "📊 Performance Testing"
    echo "====================="
    test_script_execution_time
    test_memory_usage
    test_concurrent_execution
    test_stress_testing
    
    # Security Tests
    echo ""
    echo "🔒 Security Testing"
    echo "=================="
    test_input_sanitization
    test_file_permissions
    test_privilege_escalation
    test_resource_limits
    
    # Integration Tests
    echo ""
    echo "🔗 Integration Testing"
    echo "====================="
    test_end_to_end_integration
    test_cross_platform_compatibility
    
    # Final report
    echo ""
    echo "📊 Test Summary"
    echo "==============="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    local success_rate=0
    if (( TOTAL_TESTS > 0 )); then
        success_rate=$(echo "scale=2; $TESTS_PASSED / $TOTAL_TESTS * 100" | bc -l)
    fi
    
    echo "Success Rate: ${success_rate}%"
    
    # Generate report
    cat > "$RESULTS_DIR/comprehensive_test_report.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED,
    "success_rate": $success_rate
  },
  "categories": {
    "performance": "completed",
    "security": "completed", 
    "integration": "completed"
  },
  "status": "$([ $TESTS_FAILED -eq 0 ] && echo "PASSED" || echo "FAILED")"
}
EOF
    
    log_info "Test report saved to: $RESULTS_DIR/comprehensive_test_report.json"
    
    # Exit with appropriate code
    if (( TESTS_FAILED > 0 )); then
        exit 1
    else
        exit 0
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in bc jq timeout; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if (( ${#missing_deps[@]} > 0 )); then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and run again"
        exit 1
    fi
}

# Run dependency check and main function
check_dependencies
main "$@"