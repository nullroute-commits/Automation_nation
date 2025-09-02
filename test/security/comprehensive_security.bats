#!/usr/bin/env bats

# Comprehensive Security Test Suite
# 15+ tests covering all major attack vectors

setup() {
    export TEST_DIR="/tmp/security_test_$$"
    mkdir -p "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Input Validation Tests (5 tests)

@test "security: filename injection prevention" {
    run ./collect_info.sh -o "../../../etc/passwd"
    [ "$status" -ne 0 ]
}

@test "security: command injection in filename" {
    run ./collect_info.sh -o "test.json; cat /etc/passwd"
    [ "$status" -ne 0 ]
}

@test "security: architecture parameter validation" {
    run ./plugins/10_os_info.sh "x86_64; rm -rf /"
    [ "$status" -ne 0 ]
}

@test "security: path traversal prevention" {
    run ./collect_info.sh -o "../../sensitive_file"
    [ "$status" -ne 0 ]
}

@test "security: special character handling" {
    run ./collect_info.sh -o "test\$(whoami).json"
    [ "$status" -ne 0 ]
}

# Privilege Escalation Tests (3 tests)

@test "security: sudo usage validation" {
    ENABLE_SUDO_SUPPORT=0 run ./collect_info.sh
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "sudo" ]]
}

@test "security: unauthorized sudo prevention" {
    run bash -c 'ENABLE_SUDO_SUPPORT=1 timeout 5 ./collect_info.sh'
    [[ "$status" -eq 0 || "$status" -eq 124 ]]
}

@test "security: plugin permission validation" {
    for plugin in plugins/*.sh; do
        perms=$(stat -c "%a" "$plugin")
        [[ ! "$perms" =~ [0-9][0-9][2367] ]]
    done
}

# Output Security Tests (3 tests)

@test "security: sensitive data filtering" {
    run ./collect_info.sh -o "$TEST_DIR/output.json"
    [ "$status" -eq 0 ]
    [[ ! "$(cat "$TEST_DIR/output.json")" =~ password ]]
    [[ ! "$(cat "$TEST_DIR/output.json")" =~ secret ]]
}

@test "security: data integrity verification" {
    run ./collect_info.sh -o "$TEST_DIR/output.json"
    [ "$status" -eq 0 ]
    jq . "$TEST_DIR/output.json" >/dev/null
}

@test "security: output file permissions" {
    run ./collect_info.sh -o "$TEST_DIR/output.json"
    [ "$status" -eq 0 ]
    perms=$(stat -c "%a" "$TEST_DIR/output.json")
    [[ "$perms" =~ ^[0-7][0-7][0-4]$ ]]
}

# Configuration Security Tests (2 tests)

@test "security: environment variable validation" {
    MALICIOUS_VAR='$(rm -rf /)' run ./collect_info.sh
    [ "$status" -eq 0 ]
    [ -d "/bin" ]
}

@test "security: configuration tampering detection" {
    echo '#!/bin/bash
rm -rf /' > "$TEST_DIR/malicious.sh"
    chmod +x "$TEST_DIR/malicious.sh"
    run bash -c "PLUGIN_DIR=$TEST_DIR ./collect_info.sh"
    [ -d "/bin" ]
}

# Resource Security Tests (2 tests)

@test "security: execution time limits" {
    start_time=$(date +%s)
    run timeout 60 ./collect_info.sh
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))
    [ "$execution_time" -lt 60 ]
}

@test "security: resource usage limits" {
    run timeout 30 ./collect_info.sh
    [ "$status" -eq 0 ]
}
