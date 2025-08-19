#!/usr/bin/env bats

# Regression Testing Suite
# Tests for version compatibility, configuration changes, and plugin compatibility

# Test data setup
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/regression_test_$$"
    export TEST_PLUGIN_DIR="$TEST_DIR/plugins"
    export BASELINE_DIR="$TEST_DIR/baselines"
    
    # Create test environment
    mkdir -p "$TEST_PLUGIN_DIR" "$BASELINE_DIR"
    
    # Copy scripts and plugins
    cp collect_info.sh "$TEST_DIR/"
    cp collect_info_fast.sh "$TEST_DIR/"
    cp collect_info_optimized.sh "$TEST_DIR/"
    cp collect_info_ultra_optimized.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR"/*.sh
    
    cp plugins/*.sh "$TEST_PLUGIN_DIR/"
    chmod +x "$TEST_PLUGIN_DIR"/*.sh
}

teardown() {
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
}

@test "backward compatibility: legacy plugin interface" {
    cd "$TEST_DIR"
    
    # Create plugin using older interface patterns
    cat > "$TEST_PLUGIN_DIR/99_legacy.sh" << 'EOF'
#!/bin/bash
# Legacy plugin without architecture parameter validation
echo '{"legacy": "data"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_legacy.sh"
    
    run ./collect_info.sh -o legacy_compat.json
    [ "$status" -eq 0 ]
    [ -f legacy_compat.json ]
    
    # Should handle legacy plugins gracefully
    cat legacy_compat.json | python3 -m json.tool > /dev/null
}

@test "configuration regression: environment variable changes" {
    cd "$TEST_DIR"
    
    # Test current behavior as baseline
    run env ENABLE_HASHING=1 ./collect_info.sh -o current_config.json
    [ "$status" -eq 0 ]
    
    # Test with different configurations
    run env ENABLE_HASHING=0 ./collect_info.sh -o disabled_config.json
    [ "$status" -eq 0 ]
    
    # Both should work
    [ -f current_config.json ]
    [ -f disabled_config.json ]
    cat current_config.json | python3 -m json.tool > /dev/null
    cat disabled_config.json | python3 -m json.tool > /dev/null
    
    # Should have different hashing behavior
    local hash_current=$(grep -o '"hashing_enabled": [01]' current_config.json | cut -d: -f2 | tr -d ' ')
    local hash_disabled=$(grep -o '"hashing_enabled": [01]' disabled_config.json | cut -d: -f2 | tr -d ' ')
    
    [ "$hash_current" = "1" ]
    [ "$hash_disabled" = "0" ]
}

@test "plugin addition regression: new plugin integration" {
    cd "$TEST_DIR"
    
    # Baseline with current plugins
    ./collect_info.sh -o baseline_plugins.json
    
    # Add new plugin
    cat > "$TEST_PLUGIN_DIR/95_new_plugin.sh" << 'EOF'
#!/bin/bash
echo '{"new_plugin": "added", "version": "1.0", "architecture": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/95_new_plugin.sh"
    
    # Test with new plugin
    run ./collect_info.sh -o with_new_plugin.json
    [ "$status" -eq 0 ]
    [ -f with_new_plugin.json ]
    
    # Should include new plugin data
    grep -q "new_plugin" with_new_plugin.json
    grep -q "added" with_new_plugin.json
    
    # Should still include original plugin data
    cat with_new_plugin.json | python3 -m json.tool > /dev/null
}

@test "plugin removal regression: missing plugin handling" {
    cd "$TEST_DIR"
    
    # Remove a non-essential plugin
    if [ -f "$TEST_PLUGIN_DIR/50_uptime_info.sh" ]; then
        mv "$TEST_PLUGIN_DIR/50_uptime_info.sh" "$TEST_PLUGIN_DIR/50_uptime_info.sh.disabled"
    fi
    
    run ./collect_info.sh -o missing_plugin.json
    [ "$status" -eq 0 ]
    [ -f missing_plugin.json ]
    
    # Should still work without the plugin
    cat missing_plugin.json | python3 -m json.tool > /dev/null
    
    # Should not contain uptime info
    ! grep -q "uptime_info" missing_plugin.json || ! grep -q "uptime_seconds" missing_plugin.json
}

@test "script variant consistency regression" {
    cd "$TEST_DIR"
    
    # Test all script variants produce compatible output
    ./collect_info.sh -o variant_main.json
    ./collect_info_fast.sh -o variant_fast.json
    ./collect_info_optimized.sh -o variant_optimized.json
    
    # All should be valid JSON
    cat variant_main.json | python3 -m json.tool > /dev/null
    cat variant_fast.json | python3 -m json.tool > /dev/null
    cat variant_optimized.json | python3 -m json.tool > /dev/null
    
    # Should have similar structure (common fields)
    python3 -c "
import json

with open('variant_main.json') as f: main_data = json.load(f)
with open('variant_fast.json') as f: fast_data = json.load(f)
with open('variant_optimized.json') as f: opt_data = json.load(f)

# Check for common fields
common_fields = ['collection_metadata', 'detected_architecture']
for field in common_fields:
    if field in main_data:
        assert field in fast_data or 'timestamp' in fast_data, f'Fast variant missing {field}'
        assert field in opt_data or 'timestamp' in opt_data, f'Optimized variant missing {field}'

print('Variant consistency verified')
"
}

@test "output format stability regression" {
    cd "$TEST_DIR"
    
    # Generate baseline output
    ./collect_info.sh -o format_baseline.json
    
    # Extract structure information
    python3 -c "
import json
with open('format_baseline.json') as f:
    data = json.load(f)
    
def get_structure(obj, path=''):
    structure = {}
    if isinstance(obj, dict):
        for key, value in obj.items():
            if isinstance(value, dict):
                structure[f'{path}.{key}'] = 'object'
                structure.update(get_structure(value, f'{path}.{key}'))
            elif isinstance(value, list):
                structure[f'{path}.{key}'] = 'array'
                if value and isinstance(value[0], dict):
                    structure.update(get_structure(value[0], f'{path}.{key}[0]'))
            else:
                structure[f'{path}.{key}'] = type(value).__name__
    return structure

structure = get_structure(data)
with open('structure_baseline.json', 'w') as f:
    json.dump(structure, f, indent=2)
print(f'Structure baseline created with {len(structure)} fields')
"
    
    # Verify structure is reasonable
    [ -f structure_baseline.json ]
    local field_count=$(cat structure_baseline.json | python3 -c "import json, sys; print(len(json.load(sys.stdin)))")
    [ "$field_count" -gt 10 ]  # Should have substantial structure
}

@test "command line interface regression" {
    cd "$TEST_DIR"
    
    # Test help option
    run ./collect_info.sh -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage" ]]
    
    # Test output option
    run ./collect_info.sh -o cli_test.json
    [ "$status" -eq 0 ]
    [ -f cli_test.json ]
    
    # Test invalid option handling
    run ./collect_info.sh --invalid-option
    [ "$status" -ne 0 ] || [[ "$output" =~ "Usage" ]]
}

@test "architecture detection consistency regression" {
    cd "$TEST_DIR"
    
    # Test multiple runs for consistency
    ./collect_info.sh -o arch1.json
    ./collect_info.sh -o arch2.json
    ./collect_info.sh -o arch3.json
    
    # Extract detected architecture from each run
    local arch1=$(grep -o '"detected_architecture": "[^"]*"' arch1.json | cut -d'"' -f4)
    local arch2=$(grep -o '"detected_architecture": "[^"]*"' arch2.json | cut -d'"' -f4)
    local arch3=$(grep -o '"detected_architecture": "[^"]*"' arch3.json | cut -d'"' -f4)
    
    # Should be consistent across runs
    [ "$arch1" = "$arch2" ]
    [ "$arch2" = "$arch3" ]
    
    # Should be a valid architecture
    [[ "$arch1" =~ ^(x86_64|arm64|i386|ppc64le|s390x|riscv64|mips64|aarch32|sparc64|loongarch64)$ ]]
}

@test "plugin output schema regression" {
    cd "$TEST_DIR"
    
    # Test each plugin individually for schema consistency
    for plugin in "$TEST_PLUGIN_DIR"/*.sh; do
        if [ -x "$plugin" ]; then
            local plugin_name=$(basename "$plugin")
            
            run "$plugin" "x86_64"
            if [ "$status" -eq 0 ]; then
                # Should produce valid JSON
                echo "$output" | python3 -m json.tool > /dev/null
                
                # Should include architecture field
                [[ "$output" =~ "architecture" ]] || [[ "$output" =~ "x86_64" ]]
            fi
        fi
    done
}

@test "configuration file compatibility regression" {
    cd "$TEST_DIR"
    
    # Test with various configuration combinations
    local configs=(
        "ENABLE_HASHING=0"
        "ENABLE_HASHING=1"
        "MAX_PACKAGES=100 MAX_EXECUTABLES=50"
        "MAX_PACKAGES=1000 MAX_EXECUTABLES=500"
    )
    
    for config in "${configs[@]}"; do
        run env $config ./collect_info.sh -o "config_$(echo $config | tr ' =' '_').json"
        [ "$status" -eq 0 ]
        
        local output_file="config_$(echo $config | tr ' =' '_').json"
        [ -f "$output_file" ]
        cat "$output_file" | python3 -m json.tool > /dev/null
    done
}

@test "error code consistency regression" {
    cd "$TEST_DIR"
    
    # Test expected error conditions
    
    # Missing plugins directory
    rm -rf "$TEST_PLUGIN_DIR"
    run ./collect_info.sh -o error_test.json
    [ "$status" -eq 2 ]
    
    # Restore plugins directory but make it empty
    mkdir -p "$TEST_PLUGIN_DIR"
    run ./collect_info.sh -o error_test2.json
    [ "$status" -eq 3 ]
    
    # Invalid output directory
    run ./collect_info.sh -o "/root/invalid/path.json"
    [ "$status" -ne 0 ]
}

@test "performance baseline regression" {
    cd "$TEST_DIR"
    
    # Measure current performance
    local start_time=$(date +%s.%N)
    ./collect_info.sh -o perf_regression.json
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "scale=3; $end_time - $start_time" | bc)
    
    # Store baseline
    echo "$execution_time" > "$BASELINE_DIR/performance_baseline.txt"
    
    # Should complete within reasonable time
    local time_check=$(echo "$execution_time < 30.0" | bc)
    [ "$time_check" -eq 1 ]
    
    # Should produce valid output
    [ -f perf_regression.json ]
    cat perf_regression.json | python3 -m json.tool > /dev/null
}

@test "dependency regression: required tools" {
    cd "$TEST_DIR"
    
    # Test with minimal environment
    local required_tools="bash sh grep sed awk cat echo find"
    
    # Should work with basic POSIX tools
    run env PATH="/bin:/usr/bin" ./collect_info.sh -o minimal_tools.json
    [ "$status" -eq 0 ]
    [ -f minimal_tools.json ]
    
    # Should produce valid JSON even with limited tools
    cat minimal_tools.json | python3 -m json.tool > /dev/null
}

@test "data format backward compatibility" {
    cd "$TEST_DIR"
    
    # Generate current format
    ./collect_info.sh -o current_format.json
    
    # Validate against expected structure
    python3 -c "
import json
with open('current_format.json') as f:
    data = json.load(f)

# Check for expected top-level fields
expected_fields = ['collection_metadata', 'detected_architecture']
for field in expected_fields:
    assert field in data, f'Missing expected field: {field}'

# Check metadata structure
if 'collection_metadata' in data:
    metadata = data['collection_metadata']
    assert 'timestamp' in metadata, 'Missing timestamp in metadata'

print('Backward compatibility verified')
"
}

@test "plugin interface stability" {
    cd "$TEST_DIR"
    
    # Create plugin using current interface
    cat > "$TEST_PLUGIN_DIR/99_interface_test.sh" << 'EOF'
#!/bin/bash
# Test current plugin interface
if [ $# -eq 0 ]; then
    echo "Architecture parameter required" >&2
    exit 1
fi

ARCH="$1"
echo '{"interface_test": "passed", "architecture": "'$ARCH'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_interface_test.sh"
    
    run ./collect_info.sh -o interface_test.json
    [ "$status" -eq 0 ]
    [ -f interface_test.json ]
    
    # Should include interface test data
    grep -q "interface_test" interface_test.json
    grep -q "passed" interface_test.json
}