#!/bin/bash
# Comprehensive Modular Dependency Management System
# Handles plugin dependencies, system capabilities, and graceful fallbacks
# Compatible with all system architectures and distributions

set -e

# Configuration
DEPENDENCY_CACHE_FILE="${DEPENDENCY_CACHE_FILE:-/tmp/dependency_cache.json}"
DEPENDENCY_CHECK_TIMEOUT="${DEPENDENCY_CHECK_TIMEOUT:-30}"
ENABLE_DEPENDENCY_CACHING="${ENABLE_DEPENDENCY_CACHING:-1}"
DEPENDENCY_MANAGER_VERSION="1.0.0"

# Dependency types
declare -A DEPENDENCY_TYPES=(
    ["command"]="External command/binary"
    ["package"]="System package"
    ["plugin"]="Plugin dependency"
    ["capability"]="System capability"
    ["environment"]="Environment variable"
    ["file"]="File or directory"
    ["permission"]="Permission requirement"
)

# Global dependency registry
declare -A DEPENDENCY_REGISTRY=()
declare -A DEPENDENCY_STATUS=()
declare -A DEPENDENCY_FALLBACKS=()

# Initialize dependency manager
init_dependency_manager() {
    log_info "Initializing Dependency Manager v${DEPENDENCY_MANAGER_VERSION}"
    
    # Create cache directory if needed
    local cache_dir
    cache_dir=$(dirname "$DEPENDENCY_CACHE_FILE")
    [[ ! -d "$cache_dir" ]] && mkdir -p "$cache_dir"
    
    # Load cached dependencies if enabled
    if [[ "$ENABLE_DEPENDENCY_CACHING" -eq 1 ]] && [[ -f "$DEPENDENCY_CACHE_FILE" ]]; then
        load_dependency_cache
    fi
    
    # Initialize system capabilities
    detect_system_capabilities
}

# Logging functions
log_info() {
    echo "[INFO $(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_warn() {
    echo "[WARN $(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_error() {
    echo "[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# System capability detection
detect_system_capabilities() {
    log_info "Detecting system capabilities..."
    
    # Detect operating system
    DEPENDENCY_REGISTRY["capability.os"]=$(detect_os_type)
    DEPENDENCY_STATUS["capability.os"]="available"
    
    # Detect architecture
    DEPENDENCY_REGISTRY["capability.arch"]=$(uname -m)
    DEPENDENCY_STATUS["capability.arch"]="available"
    
    # Detect privilege level
    if [[ $EUID -eq 0 ]]; then
        DEPENDENCY_REGISTRY["capability.root"]="true"
        DEPENDENCY_STATUS["capability.root"]="available"
    else
        DEPENDENCY_REGISTRY["capability.root"]="false"
        DEPENDENCY_STATUS["capability.root"]="unavailable"
    fi
    
    # Detect sudo availability
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        DEPENDENCY_REGISTRY["capability.sudo"]="true"
        DEPENDENCY_STATUS["capability.sudo"]="available"
    else
        DEPENDENCY_REGISTRY["capability.sudo"]="false"
        DEPENDENCY_STATUS["capability.sudo"]="unavailable"
    fi
    
    # Detect common capabilities
    local proc_readable=false
    if [[ -r /proc/version ]]; then
        proc_readable=true
    fi
    DEPENDENCY_REGISTRY["capability.read_proc"]="$proc_readable"
    DEPENDENCY_STATUS["capability.read_proc"]=$(if [[ "$proc_readable" == true ]]; then echo "available"; else echo "unavailable"; fi)
    
    local sys_readable=false
    if [[ -r /sys/class ]]; then
        sys_readable=true
    fi
    DEPENDENCY_REGISTRY["capability.read_sys"]="$sys_readable"
    DEPENDENCY_STATUS["capability.read_sys"]=$(if [[ "$sys_readable" == true ]]; then echo "available"; else echo "unavailable"; fi)
    
    # Detect common tools
    local common_tools=(
        "awk" "sed" "grep" "cut" "sort" "uniq" "head" "tail" 
        "bc" "jq" "curl" "wget" "git" "docker" "podman"
        "lsof" "netstat" "ss" "ip" "ifconfig" "lspci" "lsusb"
        "systemctl" "service" "ps" "top" "df" "mount"
    )
    
    for tool in "${common_tools[@]}"; do
        check_command_dependency "$tool"
    done
}

# Detect OS type
detect_os_type() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif command -v sw_vers >/dev/null 2>&1; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Register a dependency
register_dependency() {
    local dep_type="$1"
    local dep_name="$2"
    local dep_description="$3"
    local dep_fallback="$4"
    
    local dep_key="${dep_type}.${dep_name}"
    
    DEPENDENCY_REGISTRY["$dep_key"]="$dep_description"
    if [[ -n "$dep_fallback" ]]; then
        DEPENDENCY_FALLBACKS["$dep_key"]="$dep_fallback"
    fi
    
    # Check dependency immediately
    check_dependency "$dep_type" "$dep_name"
}

# Check a specific dependency
check_dependency() {
    local dep_type="$1"
    local dep_name="$2"
    local dep_key="${dep_type}.${dep_name}"
    
    case "$dep_type" in
        "command")
            check_command_dependency "$dep_name"
            ;;
        "package")
            check_package_dependency "$dep_name"
            ;;
        "plugin")
            check_plugin_dependency "$dep_name"
            ;;
        "capability")
            check_capability_dependency "$dep_name"
            ;;
        "environment")
            check_environment_dependency "$dep_name"
            ;;
        "file")
            check_file_dependency "$dep_name"
            ;;
        "permission")
            check_permission_dependency "$dep_name"
            ;;
        *)
            log_warn "Unknown dependency type: $dep_type"
            DEPENDENCY_STATUS["$dep_key"]="unknown"
            return 1
            ;;
    esac
}

# Check command dependency
check_command_dependency() {
    local cmd="$1"
    local dep_key="command.${cmd}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$(get_command_version "$cmd")
        DEPENDENCY_REGISTRY["$dep_key"]="$version"
        DEPENDENCY_STATUS["$dep_key"]="available"
        return 0
    else
        DEPENDENCY_STATUS["$dep_key"]="unavailable"
        return 1
    fi
}

# Get command version
get_command_version() {
    local cmd="$1"
    
    case "$cmd" in
        "git")
            git --version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown"
            ;;
        "docker")
            docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo "unknown"
            ;;
        "jq")
            jq --version 2>/dev/null | sed 's/jq-//' || echo "unknown"
            ;;
        "curl")
            curl --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown"
            ;;
        *)
            echo "available"
            ;;
    esac
}

# Check package dependency
check_package_dependency() {
    local package="$1"
    local dep_key="package.${package}"
    
    # Try different package managers
    if command -v dpkg >/dev/null 2>&1; then
        if dpkg -l "$package" >/dev/null 2>&1; then
            local version
            version=$(dpkg -l "$package" 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "unknown")
            DEPENDENCY_REGISTRY["$dep_key"]="$version"
            DEPENDENCY_STATUS["$dep_key"]="available"
            return 0
        fi
    elif command -v rpm >/dev/null 2>&1; then
        if rpm -q "$package" >/dev/null 2>&1; then
            local version
            version=$(rpm -q "$package" 2>/dev/null || echo "unknown")
            DEPENDENCY_REGISTRY["$dep_key"]="$version"
            DEPENDENCY_STATUS["$dep_key"]="available"
            return 0
        fi
    elif command -v brew >/dev/null 2>&1; then
        if brew list "$package" >/dev/null 2>&1; then
            DEPENDENCY_REGISTRY["$dep_key"]="installed"
            DEPENDENCY_STATUS["$dep_key"]="available"
            return 0
        fi
    fi
    
    DEPENDENCY_STATUS["$dep_key"]="unavailable"
    return 1
}

# Check plugin dependency
check_plugin_dependency() {
    local plugin="$1"
    local dep_key="plugin.${plugin}"
    local plugin_file="${PLUGIN_DIR:-./plugins}/${plugin}.sh"
    
    if [[ -f "$plugin_file" ]] && [[ -x "$plugin_file" ]]; then
        DEPENDENCY_REGISTRY["$dep_key"]="$plugin_file"
        DEPENDENCY_STATUS["$dep_key"]="available"
        return 0
    else
        DEPENDENCY_STATUS["$dep_key"]="unavailable"
        return 1
    fi
}

# Check capability dependency
check_capability_dependency() {
    local capability="$1"
    local dep_key="capability.${capability}"
    
    # Capability should already be detected in system capabilities
    if [[ -n "${DEPENDENCY_REGISTRY[$dep_key]}" ]]; then
        return 0
    else
        DEPENDENCY_STATUS["$dep_key"]="unavailable"
        return 1
    fi
}

# Check environment dependency
check_environment_dependency() {
    local env_var="$1"
    local dep_key="environment.${env_var}"
    
    if [[ -n "${!env_var}" ]]; then
        DEPENDENCY_REGISTRY["$dep_key"]="${!env_var}"
        DEPENDENCY_STATUS["$dep_key"]="available"
        return 0
    else
        DEPENDENCY_STATUS["$dep_key"]="unavailable"
        return 1
    fi
}

# Check file dependency
check_file_dependency() {
    local file_path="$1"
    # Create a safer key by replacing all non-alphanumeric chars with underscores
    local safe_path="${file_path//[^a-zA-Z0-9]/_}"
    local dep_key="file.${safe_path}"
    
    if [[ -e "$file_path" ]] || [[ -L "$file_path" ]]; then
        local file_info
        file_info=$(ls -la "$file_path" 2>/dev/null || echo "exists")
        DEPENDENCY_REGISTRY["$dep_key"]="$file_info"
        DEPENDENCY_STATUS["$dep_key"]="available"
        return 0
    else
        DEPENDENCY_STATUS["$dep_key"]="unavailable"
        return 1
    fi
}

# Check permission dependency
check_permission_dependency() {
    local permission="$1"
    local dep_key="permission.${permission}"
    
    case "$permission" in
        "read_proc")
            if [[ -r /proc/version ]]; then
                DEPENDENCY_STATUS["$dep_key"]="available"
                return 0
            fi
            ;;
        "read_sys")
            if [[ -r /sys/class ]]; then
                DEPENDENCY_STATUS["$dep_key"]="available"
                return 0
            fi
            ;;
        "network_admin")
            if [[ -n "${DEPENDENCY_REGISTRY['capability.root']}" ]] && [[ "${DEPENDENCY_REGISTRY['capability.root']}" == "true" ]]; then
                DEPENDENCY_STATUS["$dep_key"]="available"
                return 0
            elif [[ -n "${DEPENDENCY_REGISTRY['capability.sudo']}" ]] && [[ "${DEPENDENCY_REGISTRY['capability.sudo']}" == "true" ]]; then
                DEPENDENCY_STATUS["$dep_key"]="available"
                return 0
            fi
            ;;
    esac
    
    DEPENDENCY_STATUS["$dep_key"]="unavailable"
    return 1
}

# Execute with fallback
execute_with_fallback() {
    local dep_key="$1"
    shift
    local primary_command=("$@")
    
    # Check if dependency is available
    if [[ "${DEPENDENCY_STATUS[$dep_key]}" == "available" ]]; then
        "${primary_command[@]}"
        return $?
    else
        # Try fallback if available
        local fallback="${DEPENDENCY_FALLBACKS[$dep_key]}"
        if [[ -n "$fallback" ]]; then
            log_warn "Using fallback for $dep_key: $fallback"
            eval "$fallback"
            return $?
        else
            log_error "Dependency $dep_key unavailable and no fallback defined"
            return 1
        fi
    fi
}

# Generate dependency report
generate_dependency_report() {
    local output_format="${1:-text}"
    
    case "$output_format" in
        "json")
            generate_json_report
            ;;
        "text"|*)
            generate_text_report
            ;;
    esac
}

# Generate text report
generate_text_report() {
    echo "Dependency Management Report"
    echo "============================"
    echo "Generated: $(date)"
    echo ""
    
    for dep_type in "${!DEPENDENCY_TYPES[@]}"; do
        echo "${DEPENDENCY_TYPES[$dep_type]} Dependencies:"
        echo "$(printf '%*s' ${#DEPENDENCY_TYPES[$dep_type]} '' | tr ' ' '-')----------"
        
        local found_deps=false
        for dep_key in "${!DEPENDENCY_STATUS[@]}"; do
            if [[ "$dep_key" == "${dep_type}."* ]]; then
                found_deps=true
                local dep_name="${dep_key#${dep_type}.}"
                local status="${DEPENDENCY_STATUS[$dep_key]}"
                local info="${DEPENDENCY_REGISTRY[$dep_key]:-N/A}"
                
                printf "  %-20s %-12s %s\n" "$dep_name" "[$status]" "$info"
            fi
        done
        
        if [[ "$found_deps" == false ]]; then
            echo "  (No dependencies registered)"
        fi
        echo ""
    done
}

# Generate JSON report
generate_json_report() {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"dependency_manager_version\": \"$DEPENDENCY_MANAGER_VERSION\","
    echo "  \"dependencies\": {"
    
    local first=true
    for dep_key in "${!DEPENDENCY_STATUS[@]}"; do
        if [[ "$first" == false ]]; then
            echo ","
        fi
        first=false
        
        local status="${DEPENDENCY_STATUS[$dep_key]}"
        local info="${DEPENDENCY_REGISTRY[$dep_key]:-\"N/A\"}"
        local fallback="${DEPENDENCY_FALLBACKS[$dep_key]:-\"\"}"
        
        echo -n "    \"$dep_key\": {"
        echo -n "\"status\": \"$status\", "
        echo -n "\"info\": \"$info\""
        if [[ -n "$fallback" ]]; then
            echo -n ", \"fallback\": \"$fallback\""
        fi
        echo -n "}"
    done
    
    echo ""
    echo "  }"
    echo "}"
}

# Load dependency cache
load_dependency_cache() {
    if [[ -f "$DEPENDENCY_CACHE_FILE" ]]; then
        log_info "Loading dependency cache from $DEPENDENCY_CACHE_FILE"
        # Simple cache loading - in production this would be more sophisticated
        # For now, we'll always do fresh detection
    fi
}

# Save dependency cache
save_dependency_cache() {
    if [[ "$ENABLE_DEPENDENCY_CACHING" -eq 1 ]]; then
        log_info "Saving dependency cache to $DEPENDENCY_CACHE_FILE"
        generate_json_report > "$DEPENDENCY_CACHE_FILE"
    fi
}

# Validate plugin dependencies
validate_plugin_dependencies() {
    local plugin_file="$1"
    
    if [[ ! -f "$plugin_file" ]]; then
        log_error "Plugin file not found: $plugin_file"
        return 1
    fi
    
    # Extract dependency information from plugin file
    local dependencies
    dependencies=$(grep "^# DEPENDS:" "$plugin_file" 2>/dev/null || true)
    
    if [[ -z "$dependencies" ]]; then
        log_info "No dependencies declared for $(basename "$plugin_file")"
        return 0
    fi
    
    local failed_deps=0
    while IFS= read -r dep_line; do
        # Parse dependency line: # DEPENDS: type:name
        local dep_spec="${dep_line#*DEPENDS: }"
        local dep_type dep_name
        
        # Split on first colon only
        dep_type="${dep_spec%%:*}"
        dep_name="${dep_spec#*:}"
        
        register_dependency "$dep_type" "$dep_name" "Required by $(basename "$plugin_file")"
        
        # Create safe key for checking status
        local safe_name="${dep_name//[^a-zA-Z0-9]/_}"
        local dep_key="${dep_type}.${safe_name}"
        
        if [[ "${DEPENDENCY_STATUS[$dep_key]}" != "available" ]]; then
            log_warn "Dependency not available: $dep_type:$dep_name for $(basename "$plugin_file")"
            ((failed_deps++))
        else
            log_info "Dependency available: $dep_type:$dep_name for $(basename "$plugin_file")"
        fi
    done <<< "$dependencies"
    
    if [[ $failed_deps -eq 0 ]]; then
        log_info "All dependencies satisfied for $(basename "$plugin_file")"
    fi
    
    return $failed_deps
}

# Show help
show_help() {
    cat << EOF
Dependency Manager v${DEPENDENCY_MANAGER_VERSION}

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  check [type:name]     Check specific dependency or all dependencies
  report [format]       Generate dependency report (text|json)
  validate [plugin]     Validate plugin dependencies
  help                  Show this help

Options:
  --cache-file FILE     Dependency cache file (default: $DEPENDENCY_CACHE_FILE)
  --no-cache           Disable dependency caching
  --timeout SECONDS    Dependency check timeout (default: $DEPENDENCY_CHECK_TIMEOUT)

Environment Variables:
  ENABLE_DEPENDENCY_CACHING=0|1    Enable dependency caching (default: 1)
  DEPENDENCY_CHECK_TIMEOUT=N       Timeout for dependency checks (default: 30)
  PLUGIN_DIR=path                  Plugin directory (default: ./plugins)

Examples:
  $0 check                         # Check all dependencies
  $0 check command:git             # Check specific command
  $0 report json                   # Generate JSON report
  $0 validate plugins/10_os_info.sh # Validate plugin dependencies
EOF
}

# Main execution
main() {
    local command="${1:-check}"
    
    case "$command" in
        "check")
            init_dependency_manager
            if [[ -n "$2" ]]; then
                local dep_type dep_name
                dep_type="${2%%:*}"
                dep_name="${2#*:}"
                check_dependency "$dep_type" "$dep_name"
                local safe_name="${dep_name//[^a-zA-Z0-9]/_}"
                local dep_key="${dep_type}.${safe_name}"
                echo "Dependency $2: ${DEPENDENCY_STATUS[$dep_key]}"
            else
                log_info "Checking all dependencies..."
                generate_text_report
            fi
            save_dependency_cache
            ;;
        "report")
            init_dependency_manager
            generate_dependency_report "${2:-text}"
            ;;
        "validate")
            init_dependency_manager
            if [[ -n "$2" ]]; then
                validate_plugin_dependencies "$2"
            else
                log_error "Plugin file required for validation"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi