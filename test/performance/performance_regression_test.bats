#!/usr/bin/env bats

# Performance Regression Testing Suite
# Tests execution time, memory usage, and performance characteristics

# Test data setup
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/performance_test_$$"
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

# Helper function to measure execution time
measure_execution_time() {
    local script="$1"
    local output_file="$2"
    
    cd "$TEST_DIR"
    local start_time=$(date +%s.%N)
    ./"$script" -o "$output_file" >/dev/null 2>&1
    local exit_code=$?
    local end_time=$(date +%s.%N)
    
    if [ "$exit_code" -eq 0 ]; then
        echo "scale=3; $end_time - $start_time" | bc
    else
        echo "ERROR"
    fi
}

@test "collect_info.sh execution time baseline" {
    local exec_time=$(measure_execution_time "collect_info.sh" "baseline.json")
    
    [ "$exec_time" != "ERROR" ]
    
    # Should complete within 30 seconds on reasonable hardware
    local time_check=$(echo "$exec_time < 30.0" | bc)
    [ "$time_check" -eq 1 ]
    
    # Store baseline for comparison
    echo "$exec_time" > "$BASELINE_DIR/collect_info_baseline.txt"
}

@test "collect_info_fast.sh should be faster than main script" {
    local main_time=$(measure_execution_time "collect_info.sh" "main.json")
    local fast_time=$(measure_execution_time "collect_info_fast.sh" "fast.json")
    
    [ "$main_time" != "ERROR" ]
    [ "$fast_time" != "ERROR" ]
    
    # Fast version should be faster (or at least not slower)
    local speed_check=$(echo "$fast_time <= $main_time" | bc)
    [ "$speed_check" -eq 1 ]
}

@test "collect_info_optimized.sh performance characteristics" {
    local optimized_time=$(measure_execution_time "collect_info_optimized.sh" "optimized.json")
    
    [ "$optimized_time" != "ERROR" ]
    
    # Should complete within reasonable time
    local time_check=$(echo "$optimized_time < 25.0" | bc)
    [ "$time_check" -eq 1 ]
}

@test "collect_info_ultra_optimized.sh should be fastest variant" {
    local main_time=$(measure_execution_time "collect_info.sh" "main.json")
    local ultra_time=$(measure_execution_time "collect_info_ultra_optimized.sh" "ultra.json")
    
    [ "$main_time" != "ERROR" ]
    [ "$ultra_time" != "ERROR" ]
    
    # Ultra optimized should be fastest or equal
    local speed_check=$(echo "$ultra_time <= $main_time" | bc)
    [ "$speed_check" -eq 1 ]
}

@test "memory usage should be reasonable for all variants" {
    cd "$TEST_DIR"
    
    # Test memory usage for each variant using /usr/bin/time if available
    if command -v /usr/bin/time >/dev/null 2>&1; then
        # Main script memory test
        /usr/bin/time -f "%M" ./collect_info.sh -o mem_main.json 2> mem_main.log >/dev/null
        local main_mem=$(cat mem_main.log)
        
        # Memory usage should be reasonable (less than 100MB = 100000 KB)
        [ "$main_mem" -lt 100000 ]
        
        # Fast script memory test
        /usr/bin/time -f "%M" ./collect_info_fast.sh -o mem_fast.json 2> mem_fast.log >/dev/null
        local fast_mem=$(cat mem_fast.log)
        [ "$fast_mem" -lt 100000 ]
    else
        # Skip if /usr/bin/time not available
        skip "GNU time not available for memory testing"
    fi
}

@test "performance regression detection" {
    local current_time=$(measure_execution_time "collect_info.sh" "regression_test.json")
    
    [ "$current_time" != "ERROR" ]
    
    # If baseline exists, compare against it
    if [ -f "$BASELINE_DIR/collect_info_baseline.txt" ]; then
        local baseline_time=$(cat "$BASELINE_DIR/collect_info_baseline.txt")
        
        # Current time should not be more than 50% slower than baseline
        local regression_check=$(echo "$current_time < ($baseline_time * 1.5)" | bc)
        [ "$regression_check" -eq 1 ]
    fi
    
    # Update baseline with current measurement
    echo "$current_time" > "$BASELINE_DIR/collect_info_baseline.txt"
}

@test "scalability test with increased plugin load" {
    cd "$TEST_DIR"
    
    # Create additional test plugins to simulate load
    for i in {60..65}; do
        cat > "$TEST_PLUGIN_DIR/${i}_load_test.sh" << EOF
#!/bin/bash
echo '{"load_test_$i": "data", "architecture": "'"\$1"'"}'
EOF
        chmod +x "$TEST_PLUGIN_DIR/${i}_load_test.sh"
    done
    
    local loaded_time=$(measure_execution_time "collect_info.sh" "loaded.json")
    
    [ "$loaded_time" != "ERROR" ]
    
    # Even with extra plugins, should complete within 45 seconds
    local time_check=$(echo "$loaded_time < 45.0" | bc)
    [ "$time_check" -eq 1 ]
}

@test "plugin execution time individual analysis" {
    cd "$TEST_DIR"
    
    # Test individual plugin performance
    local plugin_times=""
    
    for plugin in "$TEST_PLUGIN_DIR"/*.sh; do
        if [ -x "$plugin" ]; then
            local plugin_name=$(basename "$plugin")
            local start_time=$(date +%s.%N)
            "$plugin" "x86_64" >/dev/null 2>&1
            local exit_code=$?
            local end_time=$(date +%s.%N)
            
            if [ "$exit_code" -eq 0 ]; then
                local plugin_time=$(echo "scale=3; $end_time - $start_time" | bc)
                
                # Each plugin should complete within 10 seconds
                local time_check=$(echo "$plugin_time < 10.0" | bc)
                [ "$time_check" -eq 1 ]
            fi
        fi
    done
}

@test "output size consistency and efficiency" {
    cd "$TEST_DIR"
    
    ./collect_info.sh -o size_test.json
    
    local filesize=$(stat -c%s size_test.json)
    
    # Output should be substantial but not excessive
    [ "$filesize" -gt 500 ]      # At least 500 bytes
    [ "$filesize" -lt 5242880 ]  # Less than 5MB
    
    # Should be valid JSON
    cat size_test.json | python3 -m json.tool > /dev/null
}

@test "concurrent execution performance impact" {
    cd "$TEST_DIR"
    
    # Measure single execution
    local single_time=$(measure_execution_time "collect_info.sh" "single.json")
    
    # Measure concurrent execution (3 instances)
    local start_time=$(date +%s.%N)
    ./collect_info.sh -o concurrent1.json &
    local pid1=$!
    ./collect_info.sh -o concurrent2.json &
    local pid2=$!
    ./collect_info.sh -o concurrent3.json &
    local pid3=$!
    
    wait $pid1 $pid2 $pid3
    local end_time=$(date +%s.%N)
    local concurrent_time=$(echo "scale=3; $end_time - $start_time" | bc)
    
    [ "$single_time" != "ERROR" ]
    [ "$concurrent_time" != "ERROR" ]
    
    # Concurrent execution should not take more than 3x single execution
    local efficiency_check=$(echo "$concurrent_time < ($single_time * 3.5)" | bc)
    [ "$efficiency_check" -eq 1 ]
}

@test "resource cleanup efficiency" {
    cd "$TEST_DIR"
    
    # Check for temporary file leaks
    local temp_before=$(find /tmp -name "*collect_info*" -o -name "*plugin*" 2>/dev/null | wc -l)
    
    ./collect_info.sh -o cleanup_test.json
    
    local temp_after=$(find /tmp -name "*collect_info*" -o -name "*plugin*" 2>/dev/null | wc -l)
    
    # Should not leave significant temporary files
    local temp_diff=$((temp_after - temp_before))
    [ "$temp_diff" -le 1 ]  # Allow for one temp file (our own test dir)
}

@test "performance stability across multiple runs" {
    cd "$TEST_DIR"
    
    # Run multiple times and check for consistency
    local times=""
    local total_time=0
    local run_count=3
    
    for i in $(seq 1 $run_count); do
        local exec_time=$(measure_execution_time "collect_info.sh" "stability_$i.json")
        [ "$exec_time" != "ERROR" ]
        
        times="$times $exec_time"
        total_time=$(echo "scale=3; $total_time + $exec_time" | bc)
    done
    
    local avg_time=$(echo "scale=3; $total_time / $run_count" | bc)
    
    # Check that no single run deviates more than 100% from average
    for time in $times; do
        local deviation=$(echo "scale=3; ($time - $avg_time) / $avg_time" | bc)
        local abs_deviation=$(echo "$deviation" | sed 's/-//')
        local stability_check=$(echo "$abs_deviation < 1.0" | bc)
        [ "$stability_check" -eq 1 ]
    done
}