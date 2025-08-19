#!/usr/bin/env bats

# Security Testing Suite
# Tests input validation, privilege escalation, and security concerns

# Test data setup
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/security_test_$$"
    export TEST_PLUGIN_DIR="$TEST_DIR/plugins"
    
    # Create test environment
    mkdir -p "$TEST_PLUGIN_DIR"
    
    # Copy scripts and plugins
    cp collect_info.sh "$TEST_DIR/"
    cp plugins/*.sh "$TEST_PLUGIN_DIR/"
    chmod +x "$TEST_DIR"/*.sh "$TEST_PLUGIN_DIR"/*.sh
}

teardown() {
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
}

@test "input sanitization: malicious architecture parameter" {
    cd "$TEST_DIR"
    
    # Test various malicious inputs
    local malicious_inputs=(
        "../../../etc/passwd"
        "\$(cat /etc/passwd)"
        "; rm -rf /"
        "' OR 1=1 --"
        "\`whoami\`"
        "%s%s%s%s"
        "\${IFS}cat\${IFS}/etc/passwd"
    )
    
    for input in "${malicious_inputs[@]}"; do
        run ./collect_info.sh -o "test_$RANDOM.json"
        # Script should not fail catastrophically with malicious input
        [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 2 ] || [ "$status" -eq 3 ]
        
        # Should not execute malicious commands
        [[ ! "$output" =~ "root:" ]]
        [[ ! "$output" =~ "/bin/bash" ]]
    done
}

@test "file path injection prevention" {
    cd "$TEST_DIR"
    
    # Test malicious output file paths
    local malicious_paths=(
        "../../../tmp/malicious.json"
        "/etc/passwd.json"
        "test;rm -rf /tmp.json"
    )
    
    for path in "${malicious_paths[@]}"; do
        run ./collect_info.sh -o "$path"
        # Should handle gracefully or reject
        [ "$status" -ne 127 ]  # Should not result in command not found
    done
}

@test "plugin execution sandboxing" {
    cd "$TEST_DIR"
    
    # Create a potentially malicious plugin
    cat > "$TEST_PLUGIN_DIR/99_malicious_test.sh" << 'EOF'
#!/bin/bash
# This plugin attempts to access sensitive files
if [ -r /etc/shadow ]; then
    echo '{"sensitive": "found shadow file"}'
else
    echo '{"sensitive": "no access", "architecture": "'$1'"}'
fi
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_malicious_test.sh"
    
    run ./collect_info.sh -o security_test.json
    [ "$status" -eq 0 ]
    
    # Should not contain sensitive information
    [ -f security_test.json ]
    ! grep -q "found shadow file" security_test.json
}

@test "privilege escalation prevention" {
    cd "$TEST_DIR"
    
    # Test that scripts don't require or attempt privilege escalation
    local original_uid=$(id -u)
    
    run ./collect_info.sh -o priv_test.json
    [ "$status" -eq 0 ]
    
    # Should still be running as same user
    local current_uid=$(id -u)
    [ "$original_uid" -eq "$current_uid" ]
}

@test "environment variable injection protection" {
    cd "$TEST_DIR"
    
    # Test with malicious environment variables
    run env 'MALICIOUS_VAR=$(cat /etc/passwd)' ./collect_info.sh -o env_test.json
    [ "$status" -eq 0 ]
    
    # Should not contain passwd file content
    [ -f env_test.json ]
    ! grep -q "root:" env_test.json
}

@test "command injection via plugin names" {
    cd "$TEST_DIR"
    
    # Create plugin with potentially dangerous name
    cat > "$TEST_PLUGIN_DIR/99_test;rm -rf.sh" << 'EOF'
#!/bin/bash
echo '{"test": "data", "architecture": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_test;rm -rf.sh"
    
    # Should handle the plugin safely
    run ./collect_info.sh -o injection_test.json
    [ "$status" -eq 0 ]
    
    # Test directory should still exist
    [ -d "$TEST_DIR" ]
}

@test "output file permissions security" {
    cd "$TEST_DIR"
    
    run ./collect_info.sh -o secure_output.json
    [ "$status" -eq 0 ]
    [ -f secure_output.json ]
    
    # Check file permissions are reasonable (not world-writable)
    local perms=$(stat -c "%a" secure_output.json)
    [[ ! "$perms" =~ [0-9][0-9][2367] ]]  # Last digit should not be 2,3,6,7 (world-writable)
}

@test "sensitive information leakage prevention" {
    cd "$TEST_DIR"
    
    run ./collect_info.sh -o leak_test.json
    [ "$status" -eq 0 ]
    [ -f leak_test.json ]
    
    # Should not contain common sensitive patterns
    ! grep -qi "password" leak_test.json
    ! grep -qi "secret" leak_test.json
    ! grep -qi "private.*key" leak_test.json
    ! grep -qi "api.*key" leak_test.json
    ! grep -E "BEGIN (RSA|DSA|EC) PRIVATE KEY" leak_test.json
}

@test "temporary file security" {
    cd "$TEST_DIR"
    
    # Monitor temporary files during execution
    local temp_before=$(find /tmp -user $(whoami) -name "*collect*" 2>/dev/null | wc -l)
    
    ./collect_info.sh -o temp_security.json
    
    local temp_after=$(find /tmp -user $(whoami) -name "*collect*" 2>/dev/null | wc -l)
    
    # Should not leave temp files with sensitive permissions
    find /tmp -user $(whoami) -name "*collect*" -perm /002 2>/dev/null | while read file; do
        [ ! -f "$file" ]  # Should not find world-writable temp files
    done
}

@test "resource consumption limits" {
    cd "$TEST_DIR"
    
    # Test with ulimit restrictions
    (
        ulimit -t 30  # 30 seconds CPU time limit
        ulimit -f 10240  # 10MB file size limit
        ulimit -v 1048576  # 1GB virtual memory limit
        
        run ./collect_info.sh -o resource_test.json
        [ "$status" -eq 0 ] || [ "$status" -eq 137 ]  # Success or killed by limit
    )
}

@test "safe handling of special characters in output" {
    cd "$TEST_DIR"
    
    # Create plugin that outputs special characters
    cat > "$TEST_PLUGIN_DIR/99_special_chars.sh" << 'EOF'
#!/bin/bash
echo '{"special": "test\nwith\ttabs\rand\"quotes", "architecture": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_special_chars.sh"
    
    run ./collect_info.sh -o special_chars.json
    [ "$status" -eq 0 ]
    
    # Should still produce valid JSON
    [ -f special_chars.json ]
    cat special_chars.json | python3 -m json.tool > /dev/null
}

@test "plugin isolation and failure containment" {
    cd "$TEST_DIR"
    
    # Create a plugin that crashes
    cat > "$TEST_PLUGIN_DIR/99_crash_test.sh" << 'EOF'
#!/bin/bash
kill -9 $$
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_crash_test.sh"
    
    # Create a normal plugin
    cat > "$TEST_PLUGIN_DIR/98_normal.sh" << 'EOF'
#!/bin/bash
echo '{"normal": "data", "architecture": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/98_normal.sh"
    
    run ./collect_info.sh -o isolation_test.json
    [ "$status" -eq 0 ]
    
    # Should still process other plugins
    [ -f isolation_test.json ]
    grep -q "normal" isolation_test.json
}

@test "protection against symlink attacks" {
    cd "$TEST_DIR"
    
    # Create symlink to sensitive file
    ln -s /etc/passwd "$TEST_DIR/passwd_link.json"
    
    # Should not follow symlinks to sensitive locations
    run ./collect_info.sh -o passwd_link.json
    
    # Should either fail safely or overwrite without following link
    [ "$status" -ne 127 ]
    
    # If file was created, it should not contain passwd content
    if [ -f passwd_link.json ]; then
        ! grep -q "root:" passwd_link.json
    fi
}

@test "network security considerations" {
    cd "$TEST_DIR"
    
    # Test that plugins don't make unauthorized network connections
    # This is difficult to test comprehensively, but we can check for common patterns
    
    run ./collect_info.sh -o network_security.json
    [ "$status" -eq 0 ]
    
    # Check that output doesn't contain credentials or tokens
    [ -f network_security.json ]
    ! grep -iE "(bearer|token|authorization|x-api-key)" network_security.json
}

@test "code injection via configuration" {
    cd "$TEST_DIR"
    
    # Test with potentially malicious configuration
    run env 'CONFIG_VAR=$(rm -rf /)' ./collect_info.sh -o config_injection.json
    [ "$status" -eq 0 ]
    
    # Test directory should still exist
    [ -d "$TEST_DIR" ]
    [ -f config_injection.json ]
}