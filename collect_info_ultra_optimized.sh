#!/bin/bash
# Optimized system information collection script
# Focuses on minimal dependencies and maximum runtime execution speed

# Performance optimization settings
ENABLE_PARALLEL=${ENABLE_PARALLEL:-1}
ENABLE_FAST_MODE=${ENABLE_FAST_MODE:-1}
MAX_CONCURRENT_PLUGINS=${MAX_CONCURRENT_PLUGINS:-4}
PLUGIN_TIMEOUT=${PLUGIN_TIMEOUT:-10}

# Configure limits for speed
MAX_PACKAGES=${MAX_PACKAGES:-15}
MAX_EXECUTABLES=${MAX_EXECUTABLES:-10}
ENABLE_HASHING=${ENABLE_HASHING:-0}  # Disabled by default for speed
ENABLE_SUDO_SUPPORT=${ENABLE_SUDO_SUPPORT:-0}  # Disabled by default for speed

# Use optimized plugin directory
PLUGIN_DIR="${PLUGIN_DIR:-./plugins}"
OPTIMIZED_PLUGIN_DIR="./plugins_optimized"

# Create optimized plugins directory if it doesn't exist
if [[ ! -d "$OPTIMIZED_PLUGIN_DIR" ]]; then
    mkdir -p "$OPTIMIZED_PLUGIN_DIR"
fi

# Core architecture detection (minimal dependencies)
detect_arch() {
    local arch=""
    
    # Try uname first (most reliable, minimal dependencies)
    if command -v uname >/dev/null 2>&1; then
        arch=$(uname -m 2>/dev/null)
    fi
    
    # Fallback to /proc/cpuinfo if available
    if [[ -z "$arch" ]] && [[ -r /proc/cpuinfo ]]; then
        arch=$(awk '/^processor/{arch=1} /^Architecture/{print $3; exit} END{if(!arch) print "unknown"}' /proc/cpuinfo 2>/dev/null)
    fi
    
    # Final fallback
    if [[ -z "$arch" ]]; then
        arch="unknown"
    fi
    
    echo "$arch"
}

# Minimal timestamp function
get_timestamp() {
    if command -v date >/dev/null 2>&1; then
        date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Fast plugin discovery with caching
discover_plugins() {
    local plugins=()
    local plugin_dir="$1"
    
    if [[ ! -d "$plugin_dir" ]]; then
        echo "Plugin directory not found: $plugin_dir" >&2
        return 1
    fi
    
    # Use optimized plugins if available, otherwise fall back to standard
    for file in "$plugin_dir"/*; do
        if [[ -x "$file" ]] && [[ -f "$file" ]]; then
            plugins+=("$file")
        fi
    done
    
    # Limit plugin count for speed if fast mode is enabled
    if [[ "$ENABLE_FAST_MODE" = "1" ]] && [[ ${#plugins[@]} -gt 6 ]]; then
        # Keep only essential plugins for fast mode
        local essential_plugins=()
        for plugin in "${plugins[@]}"; do
            local basename_plugin=$(basename "$plugin")
            case "$basename_plugin" in
                10_os_info.sh|20_hardware_info.sh|40_packages_execs*.sh|50_uptime_info.sh)
                    essential_plugins+=("$plugin")
                    ;;
            esac
        done
        plugins=("${essential_plugins[@]}")
    fi
    
    printf '%s\n' "${plugins[@]}"
}

# Optimized plugin execution
execute_plugin() {
    local plugin="$1"
    local arch="$2"
    local start_time plugin_name output
    
    plugin_name=$(basename "$plugin")
    start_time=$(date +%s.%N 2>/dev/null || echo "0")
    
    # Set environment for plugin optimization
    export USE_FAST_MODE="$ENABLE_FAST_MODE"
    export MAX_PACKAGES
    export MAX_EXECUTABLES
    
    # Execute with timeout
    if command -v timeout >/dev/null 2>&1; then
        output=$(timeout "$PLUGIN_TIMEOUT" "$plugin" "$arch" 2>/dev/null)
    else
        output=$("$plugin" "$arch" 2>/dev/null)
    fi
    
    local exit_code=$?
    local end_time=$(date +%s.%N 2>/dev/null || echo "0")
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$output" ]]; then
        echo "{\"error\": \"Plugin $plugin_name failed or timed out\"}" >&2
        return 1
    fi
    
    # Basic JSON validation (lightweight)
    if [[ ! "$output" =~ ^\{.*\}$ ]]; then
        echo "{\"error\": \"Plugin $plugin_name returned invalid JSON\"}" >&2
        return 1
    fi
    
    # Calculate execution time if possible
    local exec_time="unknown"
    if command -v bc >/dev/null 2>&1 && [[ "$start_time" != "0" ]] && [[ "$end_time" != "0" ]]; then
        exec_time=$(echo "($end_time - $start_time) * 1000" | bc 2>/dev/null | cut -d. -f1)
    fi
    
    # Extract function name for JSON key
    local function_name
    function_name=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$plugin" | head -1 | cut -d'(' -f1 2>/dev/null)
    if [[ -z "$function_name" ]]; then
        local basename_plugin=$(basename "$plugin" .sh)
        function_name="get_${basename_plugin#*_}"
    fi
    
    # Output plugin result with metadata
    cat << EOF
"$function_name": {
  "data": $output,
  "execution_time_ms": "$exec_time",
  "plugin_file": "$plugin_name",
  "timestamp": "$(get_timestamp)"
}
EOF
}

# Parallel plugin execution for speed
execute_plugins_parallel() {
    local plugins=("$@")
    local arch results temp_dir
    
    arch=$(detect_arch)
    temp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/collect_$$")
    results=()
    
    if [[ ! -d "$temp_dir" ]]; then
        mkdir -p "$temp_dir"
    fi
    
    # Execute plugins in parallel with concurrency limit
    local active_jobs=0
    local job_id=0
    
    for plugin in "${plugins[@]}"; do
        # Wait if we've hit the concurrency limit
        while [[ $active_jobs -ge $MAX_CONCURRENT_PLUGINS ]]; do
            wait -n 2>/dev/null
            ((active_jobs--))
        done
        
        # Execute plugin in background
        {
            execute_plugin "$plugin" "$arch" > "$temp_dir/plugin_$job_id.json" 2>/dev/null
            echo $? > "$temp_dir/plugin_$job_id.exit"
        } &
        
        ((active_jobs++))
        ((job_id++))
    done
    
    # Wait for all background jobs to complete
    wait
    
    # Collect results
    for ((i=0; i<job_id; i++)); do
        if [[ -f "$temp_dir/plugin_$i.json" ]] && [[ -f "$temp_dir/plugin_$i.exit" ]]; then
            local exit_code=$(cat "$temp_dir/plugin_$i.exit" 2>/dev/null)
            if [[ "$exit_code" = "0" ]]; then
                local content=$(cat "$temp_dir/plugin_$i.json" 2>/dev/null)
                if [[ -n "$content" ]]; then
                    results+=("$content")
                fi
            fi
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null
    
    printf '%s\n' "${results[@]}"
}

# Sequential plugin execution (fallback)
execute_plugins_sequential() {
    local plugins=("$@")
    local arch results
    
    arch=$(detect_arch)
    results=()
    
    for plugin in "${plugins[@]}"; do
        local result
        result=$(execute_plugin "$plugin" "$arch" 2>/dev/null)
        if [[ $? -eq 0 ]] && [[ -n "$result" ]]; then
            results+=("$result")
        fi
    done
    
    printf '%s\n' "${results[@]}"
}

# Main collection function
main() {
    local start_time arch plugins plugin_results
    
    start_time=$(get_timestamp)
    arch=$(detect_arch)
    
    # Discover plugins
    if [[ -d "$OPTIMIZED_PLUGIN_DIR" ]] && [[ "$(ls -A "$OPTIMIZED_PLUGIN_DIR" 2>/dev/null)" ]]; then
        mapfile -t plugins < <(discover_plugins "$OPTIMIZED_PLUGIN_DIR")
    else
        mapfile -t plugins < <(discover_plugins "$PLUGIN_DIR")
    fi
    
    if [[ ${#plugins[@]} -eq 0 ]]; then
        echo '{"error": "No executable plugins found", "architecture": "'$arch'"}' >&2
        exit 1
    fi
    
    # Execute plugins
    if [[ "$ENABLE_PARALLEL" = "1" ]] && command -v wait >/dev/null 2>&1; then
        mapfile -t plugin_results < <(execute_plugins_parallel "${plugins[@]}")
    else
        mapfile -t plugin_results < <(execute_plugins_sequential "${plugins[@]}")
    fi
    
    # Build final JSON output
    local collection_end_time
    collection_end_time=$(get_timestamp)
    
    echo "{"
    echo "  \"detected_architecture\": \"$arch\","
    echo "  \"collection_metadata\": {"
    echo "    \"timestamp\": \"$start_time\","
    echo "    \"completion_timestamp\": \"$collection_end_time\","
    echo "    \"plugin_count\": ${#plugins[@]},"
    echo "    \"successful_plugins\": ${#plugin_results[@]},"
    echo "    \"parallel_execution\": $ENABLE_PARALLEL,"
    echo "    \"fast_mode\": $ENABLE_FAST_MODE,"
    echo "    \"optimization_enabled\": true"
    echo "  },"
    
    # Output plugin results
    local first=true
    for result in "${plugin_results[@]}"; do
        if [[ "$first" = "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo "  $result"
    done
    
    echo "}"
}

# Execute main function
main "$@"