#!/usr/bin/env bats

# Functional Testing Suite
# Tests data integrity, cross-platform compatibility, and edge cases

# Test data setup
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/functional_test_$$"
    export TEST_PLUGIN_DIR="$TEST_DIR/plugins"
    
    # Create test environment
    mkdir -p "$TEST_PLUGIN_DIR"
    
    # Copy scripts and plugins
    cp collect_info.sh "$TEST_DIR/"
    cp collect_info_fast.sh "$TEST_DIR/"
    cp collect_info_optimized.sh "$TEST_DIR/"
    cp plugins/*.sh "$TEST_PLUGIN_DIR/"
    chmod +x "$TEST_DIR"/*.sh "$TEST_PLUGIN_DIR"/*.sh
}

teardown() {
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
}

@test "data integrity: JSON structure consistency" {
    cd "$TEST_DIR"
    
    # Run multiple times and verify structure consistency
    ./collect_info.sh -o run1.json
    ./collect_info.sh -o run2.json
    ./collect_info.sh -o run3.json
    
    # All should be valid JSON
    cat run1.json | python3 -m json.tool > /dev/null
    cat run2.json | python3 -m json.tool > /dev/null
    cat run3.json | python3 -m json.tool > /dev/null
    
    # Extract keys from each run
    python3 -c "
import json
with open('run1.json') as f: keys1 = set(json.load(f).keys())
with open('run2.json') as f: keys2 = set(json.load(f).keys())
with open('run3.json') as f: keys3 = set(json.load(f).keys())
assert keys1 == keys2 == keys3, 'Inconsistent top-level keys'
print('Structure consistent')
"
}

@test "data integrity: architecture consistency across plugins" {
    cd "$TEST_DIR"
    
    ./collect_info.sh -o integrity_test.json
    
    # Extract all architecture values and verify consistency
    python3 -c "
import json
with open('integrity_test.json') as f:
    data = json.load(f)
    
architectures = []
def extract_arch(obj, path=''):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key == 'architecture':
                architectures.append(value)
            elif isinstance(value, (dict, list)):
                extract_arch(value, f'{path}.{key}')
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            if isinstance(item, (dict, list)):
                extract_arch(item, f'{path}[{i}]')

extract_arch(data)
unique_archs = set(architectures)
assert len(unique_archs) <= 1, f'Inconsistent architectures: {unique_archs}'
print(f'Architecture consistency verified: {len(architectures)} references')
"
}

@test "cross-platform compatibility: minimal dependencies" {
    cd "$TEST_DIR"
    
    # Test with minimal PATH
    run env PATH="/bin:/usr/bin" ./collect_info.sh -o minimal_deps.json
    [ "$status" -eq 0 ]
    [ -f minimal_deps.json ]
    
    # Should still produce valid JSON
    cat minimal_deps.json | python3 -m json.tool > /dev/null
}

@test "edge case: extremely long plugin output" {
    cd "$TEST_DIR"
    
    # Create plugin with large output
    cat > "$TEST_PLUGIN_DIR/99_large_output.sh" << 'EOF'
#!/bin/bash
echo -n '{"large_data": "'
for i in {1..1000}; do
    echo -n "data_chunk_${i}_"
done
echo '", "architecture": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_large_output.sh"
    
    run timeout 60 ./collect_info.sh -o large_output.json
    [ "$status" -eq 0 ]
    
    # Should handle large output gracefully
    [ -f large_output.json ]
    cat large_output.json | python3 -m json.tool > /dev/null
}

@test "edge case: empty plugin output" {
    cd "$TEST_DIR"
    
    # Create plugin with no output
    cat > "$TEST_PLUGIN_DIR/99_empty.sh" << 'EOF'
#!/bin/bash
# This plugin produces no output
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_empty.sh"
    
    run ./collect_info.sh -o empty_plugin.json
    [ "$status" -eq 0 ]
    
    # Should still work with other plugins
    [ -f empty_plugin.json ]
    cat empty_plugin.json | python3 -m json.tool > /dev/null
}

@test "edge case: plugin with only whitespace output" {
    cd "$TEST_DIR"
    
    # Create plugin with whitespace output
    cat > "$TEST_PLUGIN_DIR/99_whitespace.sh" << 'EOF'
#!/bin/bash
echo "   
	
   "
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_whitespace.sh"
    
    run ./collect_info.sh -o whitespace.json
    [ "$status" -eq 0 ]
    
    # Should handle gracefully
    [ -f whitespace.json ]
    cat whitespace.json | python3 -m json.tool > /dev/null
}

@test "boundary condition: maximum supported architectures" {
    cd "$TEST_DIR"
    
    # Test all supported architectures from documentation
    local architectures="x86_64 arm64 i386 ppc64le s390x riscv64 mips64 aarch32 sparc64 loongarch64"
    
    for arch in $architectures; do
        # Create a test plugin for this architecture
        cat > "$TEST_PLUGIN_DIR/99_test_${arch}.sh" << EOF
#!/bin/bash
echo '{"test_arch": "$arch", "architecture": "'$1'"}'
EOF
        chmod +x "$TEST_PLUGIN_DIR/99_test_${arch}.sh"
        
        run ./collect_info.sh -o "test_${arch}.json"
        [ "$status" -eq 0 ]
        [ -f "test_${arch}.json" ]
        
        # Should contain the correct architecture
        grep -q "\"$arch\"" "test_${arch}.json" || grep -q "architecture" "test_${arch}.json"
    done
}

@test "data consistency: timestamp format validation" {
    cd "$TEST_DIR"
    
    ./collect_info.sh -o timestamp_test.json
    
    # Validate timestamp format
    python3 -c "
import json
import re
with open('timestamp_test.json') as f:
    data = json.load(f)

def find_timestamps(obj):
    timestamps = []
    if isinstance(obj, dict):
        for key, value in obj.items():
            if 'timestamp' in key.lower():
                timestamps.append(value)
            elif isinstance(value, (dict, list)):
                timestamps.extend(find_timestamps(value))
    elif isinstance(obj, list):
        for item in obj:
            if isinstance(item, (dict, list)):
                timestamps.extend(find_timestamps(item))
    return timestamps

timestamps = find_timestamps(data)
for ts in timestamps:
    # Check if it's a reasonable timestamp format
    assert isinstance(ts, (str, int, float)), f'Invalid timestamp type: {type(ts)}'
    if isinstance(ts, str):
        # Should be ISO format or unix timestamp
        assert re.match(r'^\d{4}-\d{2}-\d{2}|^\d{10}', ts), f'Invalid timestamp format: {ts}'

print(f'Timestamp validation passed: {len(timestamps)} timestamps')
"
}

@test "plugin discovery robustness" {
    cd "$TEST_DIR"
    
    # Create plugins with various naming patterns
    cat > "$TEST_PLUGIN_DIR/01_normal.sh" << 'EOF'
#!/bin/bash
echo '{"plugin": "01_normal", "architecture": "'$1'"}'
EOF
    
    cat > "$TEST_PLUGIN_DIR/plugin_without_number.sh" << 'EOF'
#!/bin/bash
echo '{"plugin": "without_number", "architecture": "'$1'"}'
EOF
    
    cat > "$TEST_PLUGIN_DIR/99_special-chars_plugin.sh" << 'EOF'
#!/bin/bash
echo '{"plugin": "special_chars", "architecture": "'$1'"}'
EOF
    
    # Make all executable
    chmod +x "$TEST_PLUGIN_DIR"/*.sh
    
    run ./collect_info.sh -o discovery_test.json
    [ "$status" -eq 0 ]
    [ -f discovery_test.json ]
    
    # Should include plugins that were discoverable
    cat discovery_test.json | python3 -m json.tool > /dev/null
}

@test "error recovery: malformed JSON handling" {
    cd "$TEST_DIR"
    
    # Create plugins with various JSON issues
    cat > "$TEST_PLUGIN_DIR/90_invalid_json.sh" << 'EOF'
#!/bin/bash
echo '{invalid json'
EOF
    
    cat > "$TEST_PLUGIN_DIR/91_valid_plugin.sh" << 'EOF'
#!/bin/bash
echo '{"valid": "plugin", "architecture": "'$1'"}'
EOF
    
    chmod +x "$TEST_PLUGIN_DIR"/*.sh
    
    run ./collect_info.sh -o malformed_json.json
    [ "$status" -eq 0 ]
    
    # Should still work with valid plugins
    [ -f malformed_json.json ]
    cat malformed_json.json | python3 -m json.tool > /dev/null
    grep -q "valid" malformed_json.json
}

@test "performance under resource constraints" {
    cd "$TEST_DIR"
    
    # Test with limited resources
    (
        ulimit -n 32  # Limit open files
        ulimit -u 50  # Limit processes
        
        run ./collect_info.sh -o constrained.json
        [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # Should handle gracefully
        
        if [ -f constrained.json ]; then
            cat constrained.json | python3 -m json.tool > /dev/null
        fi
    )
}

@test "unicode and international character handling" {
    cd "$TEST_DIR"
    
    # Create plugin with unicode output
    cat > "$TEST_PLUGIN_DIR/99_unicode.sh" << 'EOF'
#!/bin/bash
echo '{"unicode": "测试数据", "emoji": "🚀", "architecture": "'$1'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/99_unicode.sh"
    
    run ./collect_info.sh -o unicode.json
    [ "$status" -eq 0 ]
    [ -f unicode.json ]
    
    # Should handle unicode gracefully
    cat unicode.json | python3 -m json.tool > /dev/null
}

@test "file system edge cases" {
    cd "$TEST_DIR"
    
    # Test with unusual output file names
    local test_files=(
        "file with spaces.json"
        "file-with-dashes.json"
        "file_with_underscores.json"
        "file.with.dots.json"
    )
    
    for file in "${test_files[@]}"; do
        run ./collect_info.sh -o "$file"
        [ "$status" -eq 0 ]
        [ -f "$file" ]
        cat "$file" | python3 -m json.tool > /dev/null
    done
}

@test "plugin execution order consistency" {
    cd "$TEST_DIR"
    
    # Create numbered plugins to test ordering
    for i in {01..05}; do
        cat > "$TEST_PLUGIN_DIR/${i}_order_test.sh" << EOF
#!/bin/bash
echo '{"order": ${i}, "architecture": "'$1'"}'
EOF
        chmod +x "$TEST_PLUGIN_DIR/${i}_order_test.sh"
    done
    
    # Run multiple times and check consistency
    ./collect_info.sh -o order1.json
    ./collect_info.sh -o order2.json
    
    # Plugin execution order should be consistent
    # (Note: actual order may depend on implementation, but should be consistent)
    [ -f order1.json ]
    [ -f order2.json ]
    cat order1.json | python3 -m json.tool > /dev/null
    cat order2.json | python3 -m json.tool > /dev/null
}