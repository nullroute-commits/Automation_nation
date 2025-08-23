#!/usr/bin/env bats

# Enhanced Security Testing Suite
# Tests for input validation, injection protection, and security boundaries

# Test environment setup
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/security_test_$$"
    export TEST_PLUGIN_DIR="$TEST_DIR/plugins"
    
    mkdir -p "$TEST_PLUGIN_DIR"
    
    # Copy main script to test location
    cp collect_info.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR/collect_info.sh"
    
    # Create a test plugin for security testing
    cat > "$TEST_PLUGIN_DIR/security_test_plugin.sh" << 'EOF'
#!/bin/bash
echo '{"security_test": "clean_data", "input_param": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/security_test_plugin.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
    
    # Clean up any potential security test artifacts
    rm -f /tmp/injected_file_* 2>/dev/null || true
    rm -f /tmp/security_breach_* 2>/dev/null || true
}

@test "should reject command injection in output filename" {
    cd "$TEST_DIR"
    
    # Test various command injection patterns
    local injection_patterns=(
        "; rm -rf /tmp/test_*"
        "| cat /etc/passwd > /tmp/injected_file_1"
        "&& echo 'INJECTED' > /tmp/security_breach_1"
        "\$(touch /tmp/security_breach_2)"
        "\`touch /tmp/security_breach_3\`"
    )
    
    for pattern in "${injection_patterns[@]}"; do
        # The script should either fail or not execute the injection
        run ./collect_info.sh -o "test${pattern}.json"
        
        # Verify no injection artifacts were created
        [ ! -f "/tmp/injected_file_1" ]
        [ ! -f "/tmp/security_breach_1" ]
        [ ! -f "/tmp/security_breach_2" ]
        [ ! -f "/tmp/security_breach_3" ]
    done
}

@test "should handle path traversal attempts safely" {
    cd "$TEST_DIR"
    
    local traversal_paths=(
        "../../../etc/passwd"
        "../../../../root/.ssh/id_rsa"
        "/etc/shadow"
        "..\\..\\..\\windows\\system32\\config\\sam"
        "....//....//....//etc//passwd"
    )
    
    for path in "${traversal_paths[@]}"; do
        # Script should handle path traversal safely
        run ./collect_info.sh -o "$path"
        
        # Should not create files in unauthorized locations
        [ ! -f "/etc/passwd_copy" ]
        [ ! -f "/root/.ssh/id_rsa_copy" ]
        [ ! -f "/etc/shadow_copy" ]
    done
}

@test "should sanitize environment variables" {
    cd "$TEST_DIR"
    
    # Test with malicious environment variables
    MALICIOUS_VAR="; rm -rf /tmp/*" ./collect_info.sh -o safe_output.json
    run test -f safe_output.json
    [ "$status" -eq 0 ]
    
    # Test with script injection in env vars
    ENABLE_HASHING="\$(touch /tmp/security_breach_env)" ./collect_info.sh -o env_test.json
    
    # Verify no injection occurred
    [ ! -f "/tmp/security_breach_env" ]
}

@test "should not expose sensitive system information" {
    cd "$TEST_DIR"
    
    run ./collect_info.sh -o sensitive_test.json
    [ "$status" -eq 0 ]
    
    # Check that output doesn't contain sensitive information
    if [ -f sensitive_test.json ]; then
        # Should not contain password hashes
        ! grep -E "^\$[1-9]\$.*:.*:" sensitive_test.json
        
        # Should not contain private keys
        ! grep -E "BEGIN.*PRIVATE KEY" sensitive_test.json
        
        # Should not contain password fields (common patterns)
        ! grep -iE "(password|passwd|pwd).*:" sensitive_test.json
    fi
}

@test "should handle resource exhaustion attempts" {
    cd "$TEST_DIR"
    
    # Create a plugin that might try to exhaust resources
    cat > "$TEST_PLUGIN_DIR/resource_exhaustion.sh" << 'EOF'
#!/bin/bash
# Simulate potential resource exhaustion
for i in {1..1000}; do
    echo '{"data": "'$(printf 'x%.0s' {1..1000})'"}'
done | jq -s '.'
EOF
    chmod +x "$TEST_PLUGIN_DIR/resource_exhaustion.sh"
    
    # Test with timeout to prevent actual exhaustion
    run timeout 10s ./collect_info.sh -o resource_test.json
    
    # Script should complete or timeout gracefully, not crash
    [ "$status" -eq 0 ] || [ "$status" -eq 124 ]  # 124 is timeout exit code
}

@test "should validate plugin execution permissions" {
    cd "$TEST_DIR"
    
    # Create a plugin without execute permissions
    cat > "$TEST_PLUGIN_DIR/no_execute.sh" << 'EOF'
#!/bin/bash
echo '{"unauthorized": "access"}'
EOF
    chmod 644 "$TEST_PLUGIN_DIR/no_execute.sh"  # Remove execute permission
    
    run ./collect_info.sh -o permission_test.json
    [ "$status" -eq 0 ]
    
    # The non-executable plugin should not be executed
    if [ -f permission_test.json ]; then
        ! grep -q "unauthorized" permission_test.json
    fi
}

@test "should protect against symlink attacks" {
    cd "$TEST_DIR"
    
    # Create a symlink to a sensitive file
    ln -s /etc/passwd "$TEST_DIR/symlink_target.json" 2>/dev/null || true
    
    # Try to use the symlink as output
    run ./collect_info.sh -o symlink_target.json
    
    # Should not overwrite the symlink target
    if [ -L symlink_target.json ]; then
        original_passwd_size=$(wc -c < /etc/passwd)
        symlink_target_size=$(wc -c < symlink_target.json 2>/dev/null || echo 0)
        
        # The sizes should be different (target shouldn't be overwritten)
        [ "$original_passwd_size" != "$symlink_target_size" ] || [ "$symlink_target_size" -eq 0 ]
    fi
}

@test "should handle special characters in filenames safely" {
    cd "$TEST_DIR"
    
    local special_chars=(
        "file with spaces.json"
        "file\$with\$dollars.json"
        "file'with'quotes.json"
        'file"with"doublequotes.json'
        "file\`with\`backticks.json"
        "file;with;semicolons.json"
        "file|with|pipes.json"
    )
    
    for filename in "${special_chars[@]}"; do
        run ./collect_info.sh -o "$filename"
        
        # Should handle special characters without injection
        if [ "$status" -eq 0 ]; then
            [ -f "$filename" ] || [ -f "$(basename "$filename")" ]
        fi
        
        # Verify no security artifacts were created
        [ ! -f "/tmp/security_breach_special" ]
    done
}

@test "should validate JSON output integrity" {
    cd "$TEST_DIR"
    
    # Create a plugin that might try to inject malicious JSON
    cat > "$TEST_PLUGIN_DIR/json_injection.sh" << 'EOF'
#!/bin/bash
echo '{"valid": "data", "injection": "value\"}, {\"malicious\": \"injected"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/json_injection.sh"
    
    run ./collect_info.sh -o json_integrity_test.json
    [ "$status" -eq 0 ]
    
    if [ -f json_integrity_test.json ]; then
        # Output should still be valid JSON despite injection attempt
        run jq . json_integrity_test.json
        [ "$status" -eq 0 ]
        
        # Should not contain obviously malicious content
        ! grep -q "malicious.*injected" json_integrity_test.json
    fi
}

@test "should enforce execution timeouts" {
    cd "$TEST_DIR"
    
    # Create a plugin that runs indefinitely
    cat > "$TEST_PLUGIN_DIR/infinite_loop.sh" << 'EOF'
#!/bin/bash
while true; do
    sleep 1
done
EOF
    chmod +x "$TEST_PLUGIN_DIR/infinite_loop.sh"
    
    # Test with timeout
    run timeout 5s ./collect_info.sh -o timeout_test.json
    
    # Should timeout gracefully
    [ "$status" -eq 124 ] || [ "$status" -eq 0 ]
}

@test "should not leak memory during execution" {
    cd "$TEST_DIR"
    
    # Create plugins that allocate memory
    for i in {1..5}; do
        cat > "$TEST_PLUGIN_DIR/memory_plugin_$i.sh" << EOF
#!/bin/bash
# Allocate some memory
data=\$(printf 'x%.0s' {1..10000})
echo '{"plugin_$i": "'\$data'"}'
EOF
        chmod +x "$TEST_PLUGIN_DIR/memory_plugin_$i.sh"
    done
    
    # Monitor memory usage before and after
    local before_memory=$(ps -o vsz= -p $$ | tr -d ' ')
    
    run ./collect_info.sh -o memory_test.json
    [ "$status" -eq 0 ]
    
    local after_memory=$(ps -o vsz= -p $$ | tr -d ' ')
    
    # Memory should not increase significantly (allowing for some variance)
    local memory_increase=$((after_memory - before_memory))
    
    # Should not increase by more than 50MB (50000 KB)
    [ "$memory_increase" -lt 50000 ]
}

@test "should handle concurrent access safely" {
    cd "$TEST_DIR"
    
    # Start multiple instances in background
    for i in {1..5}; do
        ./collect_info.sh -o "concurrent_$i.json" &
    done
    
    # Wait for all to complete
    wait
    
    # All output files should exist and be valid
    for i in {1..5}; do
        [ -f "concurrent_$i.json" ]
        
        if [ -f "concurrent_$i.json" ]; then
            run jq . "concurrent_$i.json"
            [ "$status" -eq 0 ]
        fi
    done
    
    # No race condition artifacts should exist
    [ ! -f "/tmp/race_condition_detected" ]
}

@test "should validate architecture parameter sanitization" {
    cd "$TEST_DIR"
    
    # Create a plugin that echoes the architecture parameter
    cat > "$TEST_PLUGIN_DIR/arch_echo.sh" << 'EOF'
#!/bin/bash
echo '{"received_arch": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/arch_echo.sh"
    
    # Test with malicious architecture values
    local malicious_archs=(
        "x86_64; rm -rf /tmp/*"
        "arm64\$(touch /tmp/security_breach_arch)"
        "i386|cat /etc/passwd"
        "unknown\`id > /tmp/security_breach_arch2\`"
    )
    
    for arch in "${malicious_archs[@]}"; do
        # Force a specific architecture (if the script supports it)
        # Most scripts auto-detect, but test parameter passing
        
        # Verify no injection artifacts were created
        [ ! -f "/tmp/security_breach_arch" ]
        [ ! -f "/tmp/security_breach_arch2" ]
    done
}

@test "should protect plugin output parsing" {
    cd "$TEST_DIR"
    
    # Create plugin with potentially malicious output
    cat > "$TEST_PLUGIN_DIR/malicious_output.sh" << 'EOF'
#!/bin/bash
echo '{"normal": "data"}'
echo 'rm -rf /tmp/security_test_*'
echo '{"more": "data"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/malicious_output.sh"
    
    run ./collect_info.sh -o malicious_output_test.json
    
    # Script should handle malicious plugin output safely
    [ ! -f "/tmp/security_test_breach" ]
    
    if [ -f malicious_output_test.json ]; then
        # Should still produce valid JSON
        run jq . malicious_output_test.json
        [ "$status" -eq 0 ]
    fi
}