# Technical Implementation Guide

This document provides in-depth technical details about the `collect_info.sh` bash system information collection tool, including architecture implementation, plugin system details, and internal workings.

## Overview

The `collect_info.sh` tool is a sophisticated bash script that implements a plugin-based architecture for system information collection. It supports multiple CPU architectures and provides structured JSON output with integrity verification.

## System Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    collect_info.sh                          │
│                   (Main Orchestrator)                       │
├─────────────────────────────────────────────────────────────┤
│ 1. Architecture Detection (detect_arch())                  │
│ 2. Plugin Discovery (scan plugins/ directory)              │
│ 3. Plugin Execution (sequential, ordered by filename)      │
│ 4. JSON Aggregation (merge plugin outputs)                 │
│ 5. Output Management (stdout or file)                      │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Plugin Ecosystem                         │
├─────────────────────────────────────────────────────────────┤
│ plugins/10_os_info.sh     - OS/Distribution Detection      │
│ plugins/20_hardware_info.sh - Hardware Information         │
│ plugins/25_virtualization_info.sh - VM/Container Detection │
│ plugins/30_ip_info.sh     - Network Interface Details      │
│ plugins/31_network_stats.sh - Network Statistics/Routing   │
│ plugins/32_lldp_neighbors.sh - LLDP/ARP/Bridge Information │
│ plugins/40_packages_execs.sh - Package and Executable Info │
│ plugins/50_uptime_info.sh - System Uptime Information      │
└─────────────────────────────────────────────────────────────┘
```

## Architecture Detection Engine

### Detection Algorithm

```bash
detect_arch() {
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) echo "x86_64" ;; 
    aarch64|arm64) echo "arm64" ;; 
    i386|i686) echo "i386" ;; 
    ppc64le) echo "ppc64le" ;; 
    s390x) echo "s390x" ;; 
    riscv64) echo "riscv64" ;; 
    mips64) echo "mips64" ;; 
    armv7l|armv8l|arm) echo "aarch32" ;; 
    sparc64) echo "sparc64" ;; 
    loongarch64) echo "loongarch64" ;; 
    *) echo "$arch" ;;
  esac
}
```

### Architecture Mapping Strategy

The system normalizes various `uname -m` outputs to standardized architecture identifiers:

| Raw `uname -m` | Normalized | Market Context |
|----------------|------------|----------------|
| `x86_64`, `amd64` | `x86_64` | Intel/AMD 64-bit (dominant server/desktop) |
| `aarch64`, `arm64` | `arm64` | Apple Silicon, AWS Graviton, server ARM |
| `i386`, `i686` | `i386` | Legacy 32-bit x86 |
| `ppc64le` | `ppc64le` | IBM POWER (enterprise) |
| `s390x` | `s390x` | IBM Z mainframes |
| `riscv64` | `riscv64` | RISC-V 64-bit (emerging open ISA) |
| `mips64` | `mips64` | MIPS 64-bit (embedded/networking) |
| `armv7l`, `armv8l`, `arm` | `aarch32` | ARM 32-bit (IoT/embedded) |
| `sparc64` | `sparc64` | Oracle SPARC systems |
| `loongarch64` | `loongarch64` | Chinese LoongArch architecture |

## Data Integrity and Security Implementation

### CRC32 Hashing System

The system implements optional CRC32 hashing for data integrity verification:

```bash
# CRC32 hash calculation using cksum (most backwards compatible)
calculate_crc32() {
    local input="$1"
    if command -v cksum >/dev/null 2>&1; then
        echo "$input" | cksum | awk '{print $1}'
    else
        echo "unavailable"
    fi
}

# Hash plugin output for integrity
hash_plugin_output() {
    local output="$1"
    if [[ "$ENABLE_HASHING" -eq 1 ]]; then
        calculate_crc32 "$output"
    else
        echo "disabled"
    fi
}
```

### Security Features

1. **Privilege Escalation Control**: `ENABLE_SUDO_SUPPORT` (default: disabled)
2. **Input Validation**: All inputs validated before processing
3. **Path Safety**: Working directory isolation for plugin execution
4. **Output Sanitization**: JSON output properly escaped

## Plugin System Implementation

### Plugin Discovery

```bash
discover_plugins() {
    local plugin_dir="$1"
    
    if [[ ! -d "$plugin_dir" ]]; then
        echo "Error: Plugin directory '$plugin_dir' not found" >&2
        exit 2
    fi
    
    # Find executable files, sort by filename for predictable order
    find "$plugin_dir" -type f -executable -name "*.sh" | sort
}
```

### Plugin Execution Protocol

#### Input Contract
- **Argument 1**: Detected architecture string (required)
- **Environment**: Clean environment with standard PATH
- **Working Directory**: Plugin's directory context

#### Output Contract
- **Format**: Valid JSON object `{"key": "value", ...}`
- **Structure**: Self-contained object (no arrays at root level)
- **Encoding**: UTF-8 text output to stdout
- **Error Handling**: stderr for warnings, non-zero exit for failures

#### Example Plugin Structure

```bash
#!/bin/bash
# Plugin: 20_hardware_info.sh
# Purpose: Collect hardware information

set -e

if [ $# -eq 0 ]; then
    echo "Architecture parameter required" >&2
    exit 1
fi

ARCH="$1"

get_hardware_info() {
    local arch="$1"
    local cpu_model="unknown"
    local memory_total="unknown"
    
    # Architecture-specific detection
    case "$arch" in
        x86_64)
            if [[ -f /proc/cpuinfo ]]; then
                cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | sed 's/^ *//')
            fi
            ;;
        arm64)
            if [[ -f /proc/cpuinfo ]]; then
                cpu_model=$(grep -E "(model name|Processor|Hardware)" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | sed 's/^ *//')
            fi
            ;;
        *)
            # Generic detection for other architectures
            if [[ -f /proc/cpuinfo ]]; then
                cpu_model=$(grep -E "(model name|cpu|processor)" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | sed 's/^ *//')
            fi
            ;;
    esac
    
    # Memory detection
    if [[ -f /proc/meminfo ]]; then
        memory_total=$(grep "MemTotal:" /proc/meminfo | awk '{print $2 " " $3}')
    fi
    
    # JSON output
    cat << EOF
{
    "cpu_model": "$cpu_model",
    "memory_total": "$memory_total",
    "architecture": "$arch"
}
EOF
}

get_hardware_info "$ARCH"
```

### JSON Aggregation

The main script merges plugin outputs using a bash-based JSON merger:

```bash
merge_json_outputs() {
    local outputs=("$@")
    local merged='{"collection_metadata": {}}'
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Add metadata
    merged=$(echo "$merged" | jq --arg ts "$timestamp" \
        '.collection_metadata.timestamp = $ts')
    
    # Merge each plugin output
    for output in "${outputs[@]}"; do
        if [[ -n "$output" ]]; then
            # Extract function name from plugin file for key
            local plugin_key="${output##*/}"
            plugin_key="${plugin_key%.sh}"
            
            merged=$(echo "$merged" | jq --arg key "$plugin_key" \
                --argjson data "$output" '.[$key] = $data')
        fi
    done
    
    echo "$merged"
}
```

## Performance Characteristics

### Execution Flow

1. **Architecture Detection**: ~1ms (single `uname -m` call)
2. **Plugin Discovery**: ~10ms (filesystem scan)
3. **Plugin Execution**: Variable (depends on system complexity)
   - OS Info: ~50ms
   - Hardware Info: ~100-500ms (depending on hardware enumeration)
   - Network Info: ~100-300ms (depending on interface count)
4. **JSON Aggregation**: ~10-50ms (depends on output size)

### Performance Optimization Strategies

#### 1. Parallel Execution (`collect_info_fast.sh`)
```bash
# Execute plugins in parallel using background processes
for plugin in "${PLUGINS[@]}"; do
    "$plugin" "$ARCH" > "${TEMP_DIR}/$(basename "$plugin").json" &
done
wait  # Wait for all background processes
```

#### 2. Command Optimization
- Use built-in bash features over external commands when possible
- Cache results within plugins to avoid repeated system calls
- Minimize subprocess creation

#### 3. Memory Management
- Stream processing for large outputs
- Temporary file cleanup
- Efficient string manipulation

## Error Handling Strategy

### Error Classification

1. **Fatal Errors** (exit with non-zero code)
   - Missing plugins directory
   - No executable plugins found
   - Critical system access failures

2. **Recoverable Errors** (continue with degraded functionality)
   - Individual plugin failures
   - Missing optional system files
   - Command not found for non-critical features

3. **Warnings** (note in output but continue)
   - Optional feature unavailable
   - Incomplete data collection
   - Performance degradation

### Error Handling Implementation

```bash
execute_plugin() {
    local plugin="$1"
    local arch="$2"
    local output
    local exit_code
    
    if ! output=$("$plugin" "$arch" 2>/dev/null); then
        exit_code=$?
        echo "Warning: Plugin $plugin failed with exit code $exit_code" >&2
        echo '{"error": "plugin_execution_failed", "exit_code": '$exit_code'}'
        return 1
    fi
    
    # Validate JSON output
    if ! echo "$output" | jq . >/dev/null 2>&1; then
        echo "Warning: Plugin $plugin produced invalid JSON" >&2
        echo '{"error": "invalid_json_output"}'
        return 1
    fi
    
    echo "$output"
}
```

## Testing Framework Architecture

### BATS Testing Structure

```
test/
├── integration/
│   └── collect_info_test.bats          # Main orchestrator tests
└── plugins/
    ├── 10_os_info_test.bats           # OS plugin tests
    ├── 20_hardware_info_test.bats     # Hardware plugin tests  
    ├── 30_ip_info_test.bats           # Network interface tests
    ├── 31_network_stats_test.bats     # Network statistics tests
    ├── 32_lldp_neighbors_test.bats    # LLDP/ARP plugin tests
    ├── 40_packages_execs_test.bats    # Package/executable tests
    └── 50_uptime_info_test.bats       # Uptime plugin tests
```

### Test Environment Isolation

```bash
setup() {
    export ORIGINAL_PATH="$PATH"
    export TEST_DIR="/tmp/collect_info_test"
    export TEST_PLUGIN_DIR="$TEST_DIR/plugins"
    mkdir -p "$TEST_PLUGIN_DIR"
    cp collect_info.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR/collect_info.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
    export PATH="$ORIGINAL_PATH"
}
```

### Test Categories

1. **Architecture Detection Tests**
   - Validates all 10 supported architectures
   - Tests `detect_arch()` function mapping
   - Verifies architecture parameter passing

2. **Plugin Discovery Tests** 
   - Executable file detection
   - Ordering verification
   - Missing directory handling

3. **JSON Validation Tests**
   - Output format compliance
   - Merge algorithm correctness
   - Invalid JSON handling

4. **Error Condition Tests**
   - Missing plugins directory (exit code 2)
   - No executable plugins (exit code 3)
   - Malformed plugin output (graceful degradation)

5. **Integration Tests**
   - End-to-end workflow validation
   - Output file generation (-o option)
   - Command-line argument processing

## Extension Points

### Custom Plugin Development

#### Minimum Viable Plugin

```bash
#!/bin/bash
set -e

# Argument validation
[ $# -eq 0 ] && { echo "Architecture parameter required" >&2; exit 1; }
ARCH="$1"

# Data collection
get_custom_data() {
    echo '{"custom_field": "custom_value"}'
}

# Execute and output
get_custom_data
```

#### Advanced Plugin Template

```bash
#!/bin/bash
# Plugin: 60_custom_info.sh
# Purpose: Custom system information collection
# Dependencies: Optional dependencies listed here

set -e

# Configuration
DEBUG=${DEBUG:-0}
ENABLE_FEATURE_X=${ENABLE_FEATURE_X:-1}

# Logging
debug_log() {
    [[ "$DEBUG" -eq 1 ]] && echo "DEBUG: $*" >&2
}

# Argument validation
if [ $# -eq 0 ]; then
    echo "Architecture parameter required" >&2
    exit 1
fi

ARCH="$1"
debug_log "Processing architecture: $ARCH"

# Feature detection
has_feature_x() {
    command -v feature_x_command >/dev/null 2>&1
}

# Data collection function
get_custom_info() {
    local arch="$1"
    local result='{}'
    
    # Architecture-specific logic
    case "$arch" in
        x86_64)
            debug_log "Using x86_64 specific collection"
            # x86_64 specific code
            ;;
        arm64)
            debug_log "Using ARM64 specific collection"
            # ARM64 specific code
            ;;
        *)
            debug_log "Using generic collection for $arch"
            # Generic code
            ;;
    esac
    
    # Optional feature collection
    if [[ "$ENABLE_FEATURE_X" -eq 1 ]] && has_feature_x; then
        debug_log "Collecting Feature X data"
        # Feature X collection
    fi
    
    echo "$result"
}

# Execute main function
get_custom_info "$ARCH"
```

### System Integration Patterns

#### Containerized Environments
- Detect container runtime (Docker, Podman, LXC)
- Adapt data collection for container constraints
- Handle missing /proc or /sys entries gracefully

#### Cloud Platform Integration
- AWS metadata service integration
- Azure metadata service support
- GCP metadata collection

#### Enterprise Environment Support
- LDAP/Active Directory integration
- SNMP data collection
- Enterprise monitoring system hooks

## Security Considerations

### Privilege Management

```bash
# Sudo wrapper with safety checks
safe_sudo() {
    if [[ "$ENABLE_SUDO_SUPPORT" -eq 1 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo "$@"
        else
            echo "Warning: sudo not available, skipping privileged operation" >&2
            return 1
        fi
    else
        echo "Warning: sudo support disabled, skipping privileged operation" >&2
        return 1
    fi
}
```

### Input Sanitization

```bash
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    echo "$input" | sed 's/[^a-zA-Z0-9._-]//g'
}
```

### Output Safety

```bash
json_escape() {
    local input="$1"
    # Escape JSON special characters
    echo "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n'
}
```

## Maintenance and Debugging

### Debug Mode Enhancement

Add to plugins for troubleshooting:

```bash
DEBUG=${DEBUG:-0}
debug_log() {
    [[ "$DEBUG" -eq 1 ]] && echo "DEBUG: $*" >&2
}

debug_log "Architecture detected: $ARCH"
debug_log "Data source: /proc/cpuinfo"
```

### Validation Tools

```bash
# Validate JSON output
./collect_info.sh | jq .

# Check plugin executable status
find plugins/ -type f ! -executable

# Test individual plugin
./plugins/10_os_info.sh x86_64 | jq .

# Performance profiling
time ./collect_info.sh >/dev/null

# Memory usage analysis
/usr/bin/time -v ./collect_info.sh >/dev/null
```

### Common Issues and Solutions

#### 1. JSON Validation Failures
```bash
# Debug JSON output line by line
./collect_info.sh > output.json
jq . output.json || {
    echo "JSON validation failed"
    cat output.json | head -20
}
```

#### 2. Plugin Execution Issues
```bash
# Test plugin isolation
bash -x ./plugins/20_hardware_info.sh x86_64

# Check plugin permissions
ls -la plugins/
find plugins/ -name "*.sh" ! -executable
```

#### 3. Architecture Detection Problems
```bash
# Test architecture detection
uname -m
./collect_info.sh | jq .collection_metadata.detected_architecture
```

#### 4. Performance Issues
```bash
# Profile plugin execution times
for plugin in plugins/*.sh; do
    echo "Timing $plugin:"
    time "$plugin" x86_64 >/dev/null
done
```

This technical documentation provides the foundation for understanding, maintaining, and extending the `collect_info.sh` system information collection tool.