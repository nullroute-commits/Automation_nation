#!/usr/bin/env bats

# Enhanced Performance Testing Suite
# Tests for execution time, memory usage, scalability, and performance regression

# Test environment setup
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/performance_test_$$"
    export TEST_PLUGIN_DIR="$TEST_DIR/plugins"
    export PERF_RESULTS_DIR="$TEST_DIR/perf_results"
    
    mkdir -p "$TEST_PLUGIN_DIR" "$PERF_RESULTS_DIR"
    
    # Copy main script to test location
    cp collect_info.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR/collect_info.sh"
    
    # Create performance test plugins
    create_test_plugins
}

teardown() {
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
}

create_test_plugins() {
    # Fast plugin
    cat > "$TEST_PLUGIN_DIR/01_fast_plugin.sh" << 'EOF'
#!/bin/bash
echo '{"fast_plugin": "quick_data", "timestamp": "'$(date -Iseconds)'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/01_fast_plugin.sh"
    
    # Medium plugin
    cat > "$TEST_PLUGIN_DIR/02_medium_plugin.sh" << 'EOF'
#!/bin/bash
sleep 0.1
echo '{"medium_plugin": "moderate_data", "timestamp": "'$(date -Iseconds)'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/02_medium_plugin.sh"
    
    # Slow plugin (for stress testing)
    cat > "$TEST_PLUGIN_DIR/03_slow_plugin.sh" << 'EOF'
#!/bin/bash
sleep 0.5
echo '{"slow_plugin": "heavy_data", "timestamp": "'$(date -Iseconds)'"}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/03_slow_plugin.sh"
    
    # Memory-intensive plugin
    cat > "$TEST_PLUGIN_DIR/04_memory_plugin.sh" << 'EOF'
#!/bin/bash
# Generate large data set
large_data=$(printf 'x%.0s' {1..10000})
echo '{"memory_plugin": "'$large_data'", "size": 10000}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/04_memory_plugin.sh"
    
    # CPU-intensive plugin
    cat > "$TEST_PLUGIN_DIR/05_cpu_plugin.sh" << 'EOF'
#!/bin/bash
# CPU-intensive calculation
result=$(seq 1 1000 | awk '{sum+=$1} END {print sum}')
echo '{"cpu_plugin": "calculated", "result": '$result'}'
EOF
    chmod +x "$TEST_PLUGIN_DIR/05_cpu_plugin.sh"
}

measure_execution_time() {
    local start_time=$(date +%s.%N)
    "$@"
    local end_time=$(date +%s.%N)
    echo "scale=3; $end_time - $start_time" | bc -l
}

@test "baseline execution time should be under 10 seconds" {
    cd "$TEST_DIR"
    
    local execution_time=$(measure_execution_time ./collect_info.sh -o baseline_perf.json)
    
    echo "Execution time: ${execution_time}s" >&3
    
    # Save baseline for comparison
    echo "$execution_time" > "$PERF_RESULTS_DIR/baseline_time.txt"
    
    # Should complete within 10 seconds
    local threshold=10.0
    local under_threshold=$(echo "$execution_time < $threshold" | bc -l)
    
    [ "$under_threshold" -eq 1 ]
}

@test "execution time should be consistent across multiple runs" {
    cd "$TEST_DIR"
    
    local times=()
    local iterations=5
    
    for i in $(seq 1 $iterations); do
        local exec_time=$(measure_execution_time ./collect_info.sh -o "consistency_$i.json")
        times+=("$exec_time")
        echo "Run $i: ${exec_time}s" >&3
    done
    
    # Calculate statistics
    local total=0
    for time in "${times[@]}"; do
        total=$(echo "$total + $time" | bc -l)
    done
    
    local average=$(echo "scale=3; $total / $iterations" | bc -l)
    local max_time=${times[0]}
    local min_time=${times[0]}
    
    for time in "${times[@]}"; do
        if (( $(echo "$time > $max_time" | bc -l) )); then
            max_time=$time
        fi
        if (( $(echo "$time < $min_time" | bc -l) )); then
            min_time=$time
        fi
    done
    
    local variance=$(echo "scale=3; $max_time - $min_time" | bc -l)
    local variance_percent=$(echo "scale=1; $variance / $average * 100" | bc -l)
    
    echo "Average: ${average}s, Variance: ${variance}s (${variance_percent}%)" >&3
    
    # Variance should be less than 50% of average time
    local acceptable_variance=$(echo "$variance_percent < 50" | bc -l)
    [ "$acceptable_variance" -eq 1 ]
}

@test "memory usage should remain stable during execution" {
    cd "$TEST_DIR"
    
    # Start memory monitoring
    {
        while true; do
            ps -o pid,rss --no-headers -C bash | awk '$1 == '$$' {print $2}' >> "$PERF_RESULTS_DIR/memory_usage.log" 2>/dev/null
            sleep 0.1
        done
    } &
    local monitor_pid=$!
    
    # Run the script
    ./collect_info.sh -o memory_stability.json
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    if [ -f "$PERF_RESULTS_DIR/memory_usage.log" ]; then
        local max_memory=$(sort -n "$PERF_RESULTS_DIR/memory_usage.log" | tail -1)
        local min_memory=$(sort -n "$PERF_RESULTS_DIR/memory_usage.log" | head -1)
        local avg_memory=$(awk '{sum+=$1; count++} END {print int(sum/count)}' "$PERF_RESULTS_DIR/memory_usage.log")
        
        echo "Memory usage - Min: ${min_memory}KB, Max: ${max_memory}KB, Avg: ${avg_memory}KB" >&3
        
        # Memory should not exceed 100MB (100,000 KB)
        [ "$max_memory" -lt 100000 ]
        
        # Memory variance should be reasonable (not more than 5x increase)
        local memory_ratio=$(echo "scale=2; $max_memory / $min_memory" | bc -l)
        local acceptable_ratio=$(echo "$memory_ratio < 5" | bc -l)
        [ "$acceptable_ratio" -eq 1 ]
    else
        skip "Could not monitor memory usage"
    fi
}

@test "concurrent execution should scale linearly" {
    cd "$TEST_DIR"
    
    # Test sequential execution
    local start_sequential=$(date +%s.%N)
    for i in {1..3}; do
        ./collect_info.sh -o "sequential_$i.json" >/dev/null
    done
    local end_sequential=$(date +%s.%N)
    local sequential_time=$(echo "$end_sequential - $start_sequential" | bc -l)
    
    # Test concurrent execution
    local start_concurrent=$(date +%s.%N)
    {
        ./collect_info.sh -o "concurrent_1.json" >/dev/null &
        ./collect_info.sh -o "concurrent_2.json" >/dev/null &
        ./collect_info.sh -o "concurrent_3.json" >/dev/null &
        wait
    }
    local end_concurrent=$(date +%s.%N)
    local concurrent_time=$(echo "$end_concurrent - $start_concurrent" | bc -l)
    
    echo "Sequential: ${sequential_time}s, Concurrent: ${concurrent_time}s" >&3
    
    # Concurrent should be faster than sequential (allowing for some overhead)
    local efficiency=$(echo "scale=2; $concurrent_time / $sequential_time" | bc -l)
    local acceptable_efficiency=$(echo "$efficiency < 0.8" | bc -l)  # At least 20% improvement
    
    echo "Concurrency efficiency: $efficiency" >&3
    [ "$acceptable_efficiency" -eq 1 ]
}

@test "performance should not degrade with plugin count" {
    cd "$TEST_DIR"
    
    local times=()
    
    # Test with increasing number of plugins
    for plugin_count in 1 3 5; do
        # Enable only the first N plugins
        for i in $(seq 1 5); do
            if [ $i -le $plugin_count ]; then
                chmod +x "$TEST_PLUGIN_DIR/0${i}_"*".sh"
            else
                chmod -x "$TEST_PLUGIN_DIR/0${i}_"*".sh" 2>/dev/null || true
            fi
        done
        
        local exec_time=$(measure_execution_time ./collect_info.sh -o "plugin_count_${plugin_count}.json")
        times+=("$exec_time")
        
        echo "Plugins: $plugin_count, Time: ${exec_time}s" >&3
    done
    
    # Performance should scale roughly linearly (not exponentially)
    local time_1=${times[0]}
    local time_3=${times[1]}
    local time_5=${times[2]}
    
    # Time for 5 plugins should be less than 3x time for 1 plugin
    local scaling_factor=$(echo "scale=2; $time_5 / $time_1" | bc -l)
    local acceptable_scaling=$(echo "$scaling_factor < 3" | bc -l)
    
    echo "Scaling factor (5 plugins vs 1): $scaling_factor" >&3
    [ "$acceptable_scaling" -eq 1 ]
}

@test "JSON output size should be reasonable" {
    cd "$TEST_DIR"
    
    ./collect_info.sh -o output_size_test.json
    
    if [ -f output_size_test.json ]; then
        local file_size=$(wc -c < output_size_test.json)
        echo "Output file size: $file_size bytes" >&3
        
        # Output should be reasonable (less than 10MB)
        [ "$file_size" -lt 10485760 ]
        
        # Output should contain actual data (more than 100 bytes)
        [ "$file_size" -gt 100 ]
        
        # Should be valid JSON
        jq . output_size_test.json >/dev/null
    else
        fail "Output file not created"
    fi
}

@test "script should handle high frequency execution" {
    cd "$TEST_DIR"
    
    local start_time=$(date +%s.%N)
    local iterations=20
    local failures=0
    
    for i in $(seq 1 $iterations); do
        if ! ./collect_info.sh -o "frequency_$i.json" >/dev/null 2>&1; then
            ((failures++))
        fi
        
        # Very brief pause to simulate high-frequency usage
        sleep 0.05
    done
    
    local end_time=$(date +%s.%N)
    local total_time=$(echo "$end_time - $start_time" | bc -l)
    local avg_time=$(echo "scale=3; $total_time / $iterations" | bc -l)
    local success_rate=$(echo "scale=1; ($iterations - $failures) / $iterations * 100" | bc -l)
    
    echo "High frequency test - Avg time: ${avg_time}s, Success rate: ${success_rate}%" >&3
    
    # Should maintain high success rate
    local acceptable_success=$(echo "$success_rate >= 90" | bc -l)
    [ "$acceptable_success" -eq 1 ]
    
    # Average time should remain reasonable
    local acceptable_time=$(echo "$avg_time < 5" | bc -l)
    [ "$acceptable_time" -eq 1 ]
}

@test "performance should be acceptable under system load" {
    cd "$TEST_DIR"
    
    # Create artificial system load
    {
        # CPU load
        yes > /dev/null &
        local cpu_load_pid=$!
        
        # I/O load
        dd if=/dev/zero of="$TEST_DIR/load_file" bs=1M count=100 >/dev/null 2>&1 &
        local io_load_pid=$!
        
        # Wait a moment for load to establish
        sleep 1
        
        # Measure performance under load
        local exec_time=$(measure_execution_time ./collect_info.sh -o load_test.json)
        
        # Clean up load generators
        kill $cpu_load_pid $io_load_pid 2>/dev/null || true
        wait $cpu_load_pid $io_load_pid 2>/dev/null || true
        rm -f "$TEST_DIR/load_file"
        
        echo "Execution time under load: ${exec_time}s" >&3
        
        # Should complete within reasonable time even under load
        local acceptable_time=$(echo "$exec_time < 30" | bc -l)
        [ "$acceptable_time" -eq 1 ]
    }
}

@test "performance regression detection" {
    cd "$TEST_DIR"
    
    # Get current execution time
    local current_time=$(measure_execution_time ./collect_info.sh -o regression_test.json)
    
    # Check if we have a baseline
    if [ -f "$PERF_RESULTS_DIR/baseline_time.txt" ]; then
        local baseline_time=$(cat "$PERF_RESULTS_DIR/baseline_time.txt")
        local regression_percent=$(echo "scale=1; ($current_time - $baseline_time) / $baseline_time * 100" | bc -l)
        
        echo "Current: ${current_time}s, Baseline: ${baseline_time}s, Regression: ${regression_percent}%" >&3
        
        # Should not regress more than 20%
        local acceptable_regression=$(echo "$regression_percent < 20" | bc -l)
        [ "$acceptable_regression" -eq 1 ]
    else
        echo "No baseline found, establishing baseline: ${current_time}s" >&3
        echo "$current_time" > "$PERF_RESULTS_DIR/baseline_time.txt"
    fi
}

@test "resource cleanup should be effective" {
    cd "$TEST_DIR"
    
    # Count initial files/processes
    local initial_files=$(find /tmp -name "*collect_info*" 2>/dev/null | wc -l)
    local initial_processes=$(pgrep -c "collect_info" || echo 0)
    
    # Run script multiple times
    for i in {1..5}; do
        ./collect_info.sh -o "cleanup_$i.json" >/dev/null &
    done
    wait
    
    # Wait for cleanup
    sleep 2
    
    # Count final files/processes
    local final_files=$(find /tmp -name "*collect_info*" ! -path "$TEST_DIR/*" 2>/dev/null | wc -l)
    local final_processes=$(pgrep -c "collect_info" || echo 0)
    
    echo "Temp files - Initial: $initial_files, Final: $final_files" >&3
    echo "Processes - Initial: $initial_processes, Final: $final_processes" >&3
    
    # Should not leave excessive temporary files
    local file_increase=$((final_files - initial_files))
    [ "$file_increase" -lt 10 ]
    
    # Should not leave running processes
    [ "$final_processes" -eq "$initial_processes" ]
}

@test "performance metrics collection" {
    cd "$TEST_DIR"
    
    # Collect comprehensive performance metrics
    local start_time=$(date +%s.%N)
    local start_memory=$(ps -o rss= -p $$ | tr -d ' ')
    
    ./collect_info.sh -o metrics_test.json
    
    local end_time=$(date +%s.%N)
    local end_memory=$(ps -o rss= -p $$ | tr -d ' ')
    
    local execution_time=$(echo "$end_time - $start_time" | bc -l)
    local memory_delta=$((end_memory - start_memory))
    
    # Create performance metrics report
    cat > "$PERF_RESULTS_DIR/performance_metrics.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "execution_time_seconds": $execution_time,
  "memory_delta_kb": $memory_delta,
  "output_file_size": $(wc -c < metrics_test.json),
  "plugin_count": $(find "$TEST_PLUGIN_DIR" -name "*.sh" -executable | wc -l)
}
EOF
    
    echo "Performance metrics saved to: $PERF_RESULTS_DIR/performance_metrics.json" >&3
    
    # Basic sanity checks
    [ -f "$PERF_RESULTS_DIR/performance_metrics.json" ]
    local valid_json=$(jq . "$PERF_RESULTS_DIR/performance_metrics.json" >/dev/null 2>&1 && echo "true" || echo "false")
    [ "$valid_json" = "true" ]
}