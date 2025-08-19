# Testing Documentation

This document provides comprehensive information about testing the `collect_info.sh` bash system information collection tool using the BATS testing framework.

## Testing Framework Overview

We use [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for all testing. BATS provides a simple, clean syntax for writing tests in bash and integrates well with CI/CD systems.

### Why BATS?

- **Native Bash**: Tests are written in bash, making them easy to understand and maintain
- **Simple Syntax**: Clean, readable test format
- **Good Integration**: Works well with CI/CD systems
- **Mature**: Well-established testing framework with good community support
- **Minimal Dependencies**: Only requires bash and common Unix utilities

## Test Structure

### Directory Layout

```
test/
├── integration/
│   └── collect_info_test.bats     # Main orchestrator tests (12 tests)
└── plugins/
    ├── 10_os_info_test.bats       # OS plugin tests
    ├── 20_hardware_info_test.bats # Hardware plugin tests
    ├── 25_virtualization_info_test.bats # Virtualization tests
    ├── 30_ip_info_test.bats       # Network interface tests
    ├── 31_network_stats_test.bats # Network statistics tests
    ├── 32_lldp_neighbors_test.bats # LLDP/ARP plugin tests
    ├── 40_packages_execs_test.bats # Package/executable tests
    └── 50_uptime_info_test.bats   # Uptime plugin tests
```

### Test Categories

#### 1. Integration Tests (`test/integration/`)
- **Purpose**: Test the main `collect_info.sh` orchestrator
- **Scope**: End-to-end functionality, plugin coordination, JSON output
- **Examples**: Architecture detection, plugin discovery, output formatting

#### 2. Plugin Tests (`test/plugins/`)
- **Purpose**: Test individual plugins in isolation
- **Scope**: Plugin-specific functionality, error handling, output validation
- **Examples**: JSON compliance, architecture handling, data collection

## Running Tests

### Basic Test Execution

```bash
# Run all tests
bats test/integration/*.bats test/plugins/*.bats

# Run integration tests only
bats test/integration/collect_info_test.bats

# Run specific plugin tests
bats test/plugins/20_hardware_info_test.bats

# Run all plugin tests
bats test/plugins/*.bats
```

### Advanced Test Execution

```bash
# Run tests with timing information
bats -t test/integration/collect_info_test.bats

# Run tests with pretty formatting
bats --pretty test/integration/collect_info_test.bats

# Run tests and capture output
bats test/integration/collect_info_test.bats 2>&1 | tee test_results.log

# Run tests with verbose output (show test names)
bats --verbose-run test/integration/collect_info_test.bats
```

### Parallel Test Execution

```bash
# Run tests in parallel (if supported)
bats --jobs 4 test/plugins/*.bats
```

## Test Environment

### Setup and Teardown

Each test file uses `setup()` and `teardown()` functions for environment management:

```bash
setup() {
    # Create isolated test environment
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/plugin_test_$$"
    mkdir -p "$TEST_DIR"
    
    # Copy scripts to test location
    cp collect_info.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR/collect_info.sh"
}

teardown() {
    # Clean up test environment
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
}
```

### Test Isolation

- **Temporary Directories**: Each test uses isolated `/tmp` directories
- **Environment Variables**: Original environment preserved and restored
- **File Permissions**: Test scripts get appropriate execute permissions
- **Path Management**: PATH modifications are contained to test scope

## Writing Tests

### BATS Test Syntax

```bash
#!/usr/bin/env bats

@test "descriptive test name" {
    # Test setup (if needed beyond setup() function)
    
    # Execute command under test
    run ./script_under_test.sh argument1 argument2
    
    # Assertions
    [ "$status" -eq 0 ]                    # Exit code assertion
    [[ "$output" =~ "expected pattern" ]]  # Output pattern assertion
    [ "${lines[0]}" = "first line" ]      # Specific line assertion
}
```

### Common Test Patterns

#### 1. Basic Command Execution

```bash
@test "script should execute successfully" {
    run ./collect_info.sh
    [ "$status" -eq 0 ]
}
```

#### 2. Output Validation

```bash
@test "script should produce valid JSON" {
    run ./collect_info.sh
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}
```

#### 3. Error Condition Testing

```bash
@test "script should fail with missing argument" {
    run ./plugin.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Architecture parameter required" ]]
}
```

#### 4. Multi-Architecture Testing

```bash
@test "script should handle different architectures" {
    for arch in x86_64 arm64 i386; do
        run ./plugin.sh "$arch"
        [ "$status" -eq 0 ]
        echo "$output" | jq . > /dev/null
    done
}
```

#### 5. File Output Testing

```bash
@test "script should create output file" {
    run ./collect_info.sh -o test_output.json
    [ "$status" -eq 0 ]
    [ -f test_output.json ]
    jq . < test_output.json > /dev/null
}
```

### Test Data Management

#### Creating Test Plugins

```bash
@test "should discover and execute test plugins" {
    # Create test plugin
    cat > "$TEST_PLUGIN_DIR/test_plugin.sh" << 'EOF'
#!/bin/bash
echo '{"test_data": "test_value"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/test_plugin.sh"
    
    # Test plugin discovery
    run ./collect_info.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test_data" ]]
}
```

#### Mocking System Commands

```bash
@test "should handle missing system commands gracefully" {
    # Create mock environment without specific commands
    export PATH="/usr/bin:/bin"  # Limited PATH
    
    run ./plugin.sh x86_64
    [ "$status" -eq 0 ]
    [[ "$output" =~ "unknown" ]]  # Should handle gracefully
}
```

## Test Coverage

### Current Test Coverage

#### Integration Tests (12 tests)
1. Architecture detection correctness
2. Plugin discovery functionality
3. Architecture parameter passing
4. JSON output validation
5. Multi-plugin output merging
6. Missing plugins directory handling
7. No executable plugins handling
8. Invalid JSON handling from plugins
9. File output (`-o` option) functionality
10. Help option (`-h`) display
11. All supported architectures validation
12. Function name keys and timestamp inclusion

#### Plugin Tests (varies by plugin)
- Parameter validation
- JSON output compliance
- Architecture-specific logic
- Error condition handling
- Data collection accuracy

### Coverage Analysis

```bash
# Count total tests
find test/ -name "*.bats" -exec grep -c "^@test" {} + | awk '{s+=$1} END {print "Total tests:", s}'

# List all test names
find test/ -name "*.bats" -exec grep "^@test" {} + | sed 's/.*@test "//' | sed 's/" {$//'

# Check test distribution
echo "Integration tests:"
grep -c "^@test" test/integration/*.bats
echo "Plugin tests:"
grep -c "^@test" test/plugins/*.bats
```

## Continuous Integration

### CI Test Strategy

1. **Multi-OS Testing**: Test on Ubuntu, CentOS, Alpine Linux
2. **Multi-Architecture Testing**: Test on x86_64, arm64 where possible
3. **Dependency Testing**: Test with minimal and full dependency sets
4. **Performance Testing**: Ensure tests complete within reasonable time

### GitHub Actions Example

```yaml
name: BATS Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, ubuntu-20.04]
        
    steps:
    - uses: actions/checkout@v3
    
    - name: Install BATS
      run: |
        sudo apt-get update
        sudo apt-get install -y bats
        
    - name: Install dependencies
      run: |
        sudo apt-get install -y jq curl
        
    - name: Run integration tests
      run: bats test/integration/collect_info_test.bats
      
    - name: Run plugin tests
      run: bats test/plugins/*.bats
```

## Debugging Tests

### Debug Test Execution

```bash
# Run single test with bash debug mode
bash -x $(which bats) test/integration/collect_info_test.bats

# Show test output during execution
bats --verbose-run test/integration/collect_info_test.bats

# Debug specific test
bats --filter "should produce valid JSON" test/integration/collect_info_test.bats
```

### Common Test Issues

#### 1. Path Issues
```bash
# Problem: Script not found
# Solution: Check TEST_DIR setup in setup() function
ls -la "$TEST_DIR"
```

#### 2. Permission Issues
```bash
# Problem: Script not executable
# Solution: Verify chmod in setup()
find "$TEST_DIR" -name "*.sh" -exec ls -la {} \;
```

#### 3. JSON Validation Failures
```bash
# Debug JSON output
run ./collect_info.sh
echo "Status: $status"
echo "Output: $output"
echo "$output" | jq . 2>&1 || echo "JSON validation failed"
```

#### 4. Environment Contamination
```bash
# Check for environment issues
env | grep TEST
echo "PATH: $PATH"
```

## Performance Testing

### Test Execution Time

```bash
# Time individual test files
time bats test/integration/collect_info_test.bats
time bats test/plugins/20_hardware_info_test.bats

# Time all tests
time bats test/integration/*.bats test/plugins/*.bats
```

### Performance Regression Detection

```bash
# Baseline timing
bats test/integration/collect_info_test.bats 2>&1 | tee baseline_timing.log

# After changes
bats test/integration/collect_info_test.bats 2>&1 | tee current_timing.log

# Compare (manual analysis)
diff baseline_timing.log current_timing.log
```

## Test Best Practices

### Writing Effective Tests

1. **Descriptive Names**: Use clear, descriptive test names
   ```bash
   @test "collect_info.sh should produce valid JSON output"  # Good
   @test "test json"                                         # Bad
   ```

2. **Single Responsibility**: Each test should verify one specific behavior
3. **Predictable**: Tests should produce the same results every time
4. **Fast**: Keep tests as fast as possible while maintaining coverage
5. **Independent**: Tests should not depend on each other

### Test Organization

1. **Logical Grouping**: Group related tests in the same file
2. **Consistent Setup**: Use consistent setup/teardown patterns
3. **Clear Assertions**: Make assertions explicit and easy to understand
4. **Error Messages**: Include helpful error context when tests fail

### Error Handling in Tests

```bash
@test "should handle error conditions gracefully" {
    # Test error condition
    run ./script.sh invalid_input
    
    # Verify failure
    [ "$status" -ne 0 ]
    
    # Verify error message
    [[ "$output" =~ "error" ]] || {
        echo "Expected error message, got: $output"
        return 1
    }
}
```

## Test Documentation

### Documenting Test Cases

Each test file should include:

1. **Purpose comment** at the top
2. **Test descriptions** that explain what is being tested
3. **Setup requirements** if any special setup is needed
4. **Expected outcomes** for complex tests

```bash
#!/usr/bin/env bats

# Tests for 20_hardware_info.sh plugin
# Purpose: Verify hardware information collection across architectures
# Requirements: Standard Unix utilities, /proc filesystem access

@test "hardware plugin should detect CPU information correctly" {
    # This test verifies that the hardware plugin can extract
    # CPU information from /proc/cpuinfo across different architectures
    
    run ./20_hardware_info.sh x86_64
    [ "$status" -eq 0 ]
    
    # Should contain CPU model information
    [[ "$output" =~ "cpu_model" ]]
}
```

## Integration with Development Workflow

### Pre-commit Testing

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running BATS tests..."
if ! bats test/integration/*.bats test/plugins/*.bats; then
    echo "Tests failed. Commit aborted."
    exit 1
fi
```

### Development Testing

```bash
# Quick test after changes
bats test/integration/collect_info_test.bats

# Full test before commit
bats test/integration/*.bats test/plugins/*.bats

# Test specific functionality
bats --filter "JSON" test/integration/collect_info_test.bats
```

This testing framework ensures the reliability and maintainability of the `collect_info.sh` tool across different environments and use cases.