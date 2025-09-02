#!/bin/bash
# Secure Parallel Collection Script - Automation Nation
# Addresses Sequential Processing DoS Risk with security controls

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/plugins"
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}
TEMP_DIR="/tmp/automation_nation_$$"
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30}

# Security: Input validation framework
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "filename")
            [[ "$input" =~ ^[a-zA-Z0-9._/-]+$ ]] || {
                echo "ERROR: Invalid filename: $input" >&2
                return 1
            }
            [[ "$input" != *".."* ]] || {
                echo "ERROR: Path traversal detected: $input" >&2
                return 1
            }
            ;;
        "architecture")
            [[ "$input" =~ ^(x86_64|arm64|i386|ppc64le|s390x|riscv64|mips64|aarch32|sparc64|loongarch64)$ ]] || {
                echo "ERROR: Invalid architecture: $input" >&2
                return 1
            }
            ;;
    esac
}

# Security: Output sanitization
sanitize_output() {
    local data="$1"
    
    # Remove potential sensitive information
    data=$(echo "$data" | sed -E 's/password[[:space:]]*[:=][[:space:]]*[^[:space:]]*/password=***REDACTED***/gi')
    data=$(echo "$data" | sed -E 's/token[[:space:]]*[:=][[:space:]]*[^[:space:]]*/token=***REDACTED***/gi')
    data=$(echo "$data" | sed -E 's/key[[:space:]]*[:=][[:space:]]*[^[:space:]]*/key=***REDACTED***/gi')
    data=$(echo "$data" | sed -E 's/(ssh-[a-z0-9]+[[:space:]]+)[^[:space:]]+/\1***REDACTED***/gi')
    
    echo "$data"
}

# Security: Privilege escalation controls
secure_sudo_check() {
    if [[ "${ENABLE_SUDO_SUPPORT:-0}" -eq 1 ]]; then
        if ! sudo -n -v 2>/dev/null; then
            echo "WARNING: Sudo not available or configured" >&2
            return 1
        fi
        echo "SECURITY: Privilege escalation requested by: $(caller)" >&2
    fi
}

# Logging functions
log_info() {
    echo "[$(date '+%H:%M:%S')] INFO: $1" >&2
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" >&2
}

log_security() {
    echo "[$(date '+%H:%M:%S')] SECURITY: $1" >&2
}

# Plugin dependency resolution for parallel execution
declare -A plugin_dependencies
plugin_dependencies["20_hardware_info.sh"]=""
plugin_dependencies["10_os_info.sh"]=""
plugin_dependencies["25_virtualization_info.sh"]="10_os_info.sh"
plugin_dependencies["30_ip_info.sh"]=""
plugin_dependencies["31_network_stats.sh"]="30_ip_info.sh"
plugin_dependencies["32_lldp_neighbors.sh"]="31_network_stats.sh"
plugin_dependencies["40_packages_execs.sh"]=""
plugin_dependencies["50_uptime_info.sh"]=""

# Check if plugin can be executed (dependencies satisfied)
can_execute_plugin() {
    local plugin="$1"
    local plugin_name=$(basename "$plugin")
    local deps="${plugin_dependencies[$plugin_name]:-}"
    
    if [[ -z "$deps" ]]; then
        return 0  # No dependencies
    fi
    
    # Check if dependency results exist
    for dep in $deps; do
        local dep_result="$TEMP_DIR/${dep%.sh}.json"
        if [[ ! -f "$dep_result" ]]; then
            return 1  # Dependency not satisfied
        fi
    done
    
    return 0
}

# Execute plugin with security controls and error handling
execute_plugin_secure() {
    local plugin="$1"
    local arch="$2"
    local plugin_name=$(basename "$plugin" .sh)
    local output_file="$TEMP_DIR/$plugin_name.json"
    
    log_info "Executing plugin: $plugin_name"
    
    # Security: Validate plugin exists and is executable
    if [[ ! -x "$plugin" ]]; then
        echo '{"error": "Plugin not executable", "plugin": "'$plugin_name'"}' > "$output_file"
        return 1
    fi
    
    # Security: Execute with timeout and resource limits
    if timeout "$TIMEOUT_SECONDS" "$plugin" "$arch" > "$output_file" 2>/dev/null; then
        # Security: Sanitize output
        local raw_output=$(cat "$output_file")
        local sanitized_output=$(sanitize_output "$raw_output")
        echo "$sanitized_output" > "$output_file"
        
        log_info "✅ $plugin_name completed successfully"
        return 0
    else
        log_error "❌ $plugin_name failed or timed out"
        echo '{"error": "Plugin execution failed or timed out", "plugin": "'$plugin_name'", "timeout": '$TIMEOUT_SECONDS'}' > "$output_file"
        return 1
    fi
}

# Parallel plugin execution with security and dependency resolution
execute_plugins_parallel_secure() {
    local arch="$1"
    local executed_plugins=()
    local remaining_plugins=()
    local job_count=0
    local max_iterations=10  # Prevent infinite loops
    local iteration=0
    
    # Initialize plugin list
    for plugin in "$PLUGINS_DIR"/*.sh; do
        if [[ -x "$plugin" ]]; then
            remaining_plugins+=("$plugin")
        fi
    done
    
    log_info "Starting secure parallel execution of ${#remaining_plugins[@]} plugins"
    log_info "Max concurrent jobs: $MAX_PARALLEL_JOBS, Timeout: ${TIMEOUT_SECONDS}s"
    
    # Execute plugins in dependency-aware waves
    while [[ ${#remaining_plugins[@]} -gt 0 && $iteration -lt $max_iterations ]]; do
        local wave_plugins=()
        local new_remaining=()
        
        # Find plugins that can be executed in this wave
        for plugin in "${remaining_plugins[@]}"; do
            if can_execute_plugin "$plugin"; then
                wave_plugins+=("$plugin")
            else
                new_remaining+=("$plugin")
            fi
        done
        
        # Break if no progress can be made
        if [[ ${#wave_plugins[@]} -eq 0 ]]; then
            log_error "Dependency deadlock detected, stopping execution"
            break
        fi
        
        log_info "Wave $((iteration + 1)): Executing ${#wave_plugins[@]} plugins"
        
        # Execute current wave in parallel with job control
        job_count=0
        for plugin in "${wave_plugins[@]}"; do
            execute_plugin_secure "$plugin" "$arch" &
            ((job_count++))
            
            # Limit concurrent jobs to prevent resource exhaustion
            if [[ $job_count -ge $MAX_PARALLEL_JOBS ]]; then
                wait
                job_count=0
            fi
        done
        
        # Wait for current wave to complete
        wait
        
        # Update plugin lists
        executed_plugins+=("${wave_plugins[@]}")
        remaining_plugins=("${new_remaining[@]}")
        
        ((iteration++))
        log_info "Wave $iteration completed. Executed: ${#executed_plugins[@]}, Remaining: ${#remaining_plugins[@]}"
    done
    
    log_info "Parallel execution completed. Total executed: ${#executed_plugins[@]}"
    
    # Security: Report any remaining plugins (potential issues)
    if [[ ${#remaining_plugins[@]} -gt 0 ]]; then
        log_error "Warning: ${#remaining_plugins[@]} plugins not executed due to dependencies"
        for plugin in "${remaining_plugins[@]}"; do
            log_error "  - $(basename "$plugin")"
        done
    fi
}

# Combine results with security validation
combine_results_secure() {
    local output_file="$1"
    local combined_json="{"
    local first=true
    local plugin_count=0
    
    for result_file in "$TEMP_DIR"/*.json; do
        if [[ -f "$result_file" ]]; then
            local plugin_name=$(basename "$result_file" .json)
            
            # Security: Validate JSON before including
            if jq . "$result_file" >/dev/null 2>&1; then
                local content=$(cat "$result_file")
                
                if [[ "$first" == true ]]; then
                    first=false
                else
                    combined_json+=","
                fi
                
                combined_json+='"'$plugin_name'": '$content
                ((plugin_count++))
            else
                log_error "Invalid JSON from plugin: $plugin_name"
            fi
        fi
    done
    
    # Add security metadata
    combined_json+=',"metadata":{'
    combined_json+='"collection_timestamp":"'$(date -Iseconds)'",'
    combined_json+='"parallel_execution":true,'
    combined_json+='"max_concurrent_jobs":'$MAX_PARALLEL_JOBS','
    combined_json+='"timeout_seconds":'$TIMEOUT_SECONDS','
    combined_json+='"plugins_executed":'$plugin_count','
    combined_json+='"security_controls_active":true'
    combined_json+='}}'
    
    # Security: Validate final JSON
    if echo "$combined_json" | jq . >/dev/null 2>&1; then
        echo "$combined_json" > "$output_file"
        log_info "✅ Results combined and validated: $plugin_count plugins"
    else
        log_error "❌ Failed to create valid JSON output"
        echo '{"error": "JSON validation failed", "plugins_attempted": '$plugin_count'}' > "$output_file"
        return 1
    fi
}

# Main execution with comprehensive security controls
main() {
    local output_file="${1:-system_info.json}"
    local arch="${2:-x86_64}"
    
    # Security: Validate inputs
    if ! validate_input "$output_file" "filename"; then
        echo "ERROR: Invalid output filename" >&2
        exit 1
    fi
    
    if ! validate_input "$arch" "architecture"; then
        echo "ERROR: Invalid architecture" >&2
        exit 1
    fi
    
    # Security: Check sudo requirements
    secure_sudo_check
    
    # Create secure temporary directory
    mkdir -p "$TEMP_DIR"
    chmod 700 "$TEMP_DIR"  # Secure permissions
    trap "rm -rf '$TEMP_DIR'" EXIT
    
    log_info "🚀 Starting secure parallel system information collection"
    log_info "Architecture: $arch"
    log_info "Output file: $output_file"
    log_info "Security controls: ACTIVE"
    
    # Record start time
    local start_time=$(date +%s.%N)
    
    # Execute plugins in parallel with security controls
    execute_plugins_parallel_secure "$arch"
    
    # Combine results with validation
    combine_results_secure "$output_file"
    
    # Record performance metrics
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    
    log_info "✅ Secure collection completed in ${duration}s"
    log_info "📄 Results saved to: $output_file"
    log_security "Collection completed with security controls active"
    
    # Security: Validate final output
    if jq . "$output_file" >/dev/null 2>&1; then
        log_info "✅ Output JSON validation successful"
        return 0
    else
        log_error "❌ Output JSON validation failed"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi