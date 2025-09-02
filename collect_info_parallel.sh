#!/bin/bash
# Parallel Collection Script - Fixes Sequential Processing DoS Risk
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/plugins"
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}

log_info() {
    echo "[$(date '+%H:%M:%S')] INFO: $1" >&2
}

# Execute plugins in parallel with dependency resolution
execute_plugins_parallel() {
    local arch="${1:-x86_64}"
    local temp_dir="/tmp/parallel_collection_$$"
    mkdir -p "$temp_dir"
    
    log_info "Starting parallel execution (max $MAX_PARALLEL_JOBS jobs)"
    
    # Start plugins in parallel
    local job_count=0
    for plugin in "$PLUGINS_DIR"/*.sh; do
        if [[ -x "$plugin" ]]; then
            local plugin_name=$(basename "$plugin" .sh)
            
            # Execute in background
            (
                timeout 30 "$plugin" "$arch" > "$temp_dir/$plugin_name.json" 2>/dev/null || 
                echo '{"error": "execution_failed", "plugin": "'$plugin_name'"}' > "$temp_dir/$plugin_name.json"
            ) &
            
            ((job_count++))
            
            # Limit concurrent jobs
            if [[ $job_count -ge $MAX_PARALLEL_JOBS ]]; then
                wait
                job_count=0
            fi
        fi
    done
    
    # Wait for remaining jobs
    wait
    
    # Combine results
    local combined='{'
    local first=true
    
    for result_file in "$temp_dir"/*.json; do
        if [[ -f "$result_file" ]]; then
            local plugin_name=$(basename "$result_file" .json)
            local content=$(cat "$result_file")
            
            if [[ "$first" == true ]]; then
                first=false
            else
                combined+=','
            fi
            
            combined+='"'$plugin_name'": '$content
        fi
    done
    
    combined+='}'
    echo "$combined"
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Main execution with performance monitoring
main() {
    local output_file="${1:-system_info.json}"
    local arch="${2:-x86_64}"
    
    local start_time=$(date +%s.%N)
    
    # Execute parallel collection
    result=$(execute_plugins_parallel "$arch")
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    
    # Add metadata
    local final_result=$(echo "$result" | jq --arg duration "$duration" --arg timestamp "$(date -Iseconds)" '. + {
        "metadata": {
            "collection_duration": $duration,
            "collection_timestamp": $timestamp,
            "parallel_execution": true,
            "max_concurrent_jobs": '$MAX_PARALLEL_JOBS'
        }
    }' 2>/dev/null || echo "$result")
    
    echo "$final_result" > "$output_file"
    log_info "Collection completed in ${duration}s, saved to $output_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
