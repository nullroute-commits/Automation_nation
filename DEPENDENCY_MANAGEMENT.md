# Dependency Management Guide

## Overview

The Automation Nation project includes a comprehensive modular dependency management system implemented entirely in bash. This system ensures reliable execution of all plugins by validating dependencies, providing graceful fallbacks, and offering detailed reporting.

## Architecture

### Core Components

1. **dependency_manager.sh** - Central dependency management engine
2. **Plugin Dependency Specifications** - Embedded dependency declarations in plugins
3. **Integration Layer** - collect_info.sh integration for automatic validation
4. **Test Suite** - Comprehensive validation and testing framework

### Dependency Types

The system supports seven different types of dependencies:

| Type | Description | Example |
|------|-------------|---------|
| `command` | External commands/binaries | `command:git` |
| `file` | Files or directories | `file:/proc/cpuinfo` |
| `capability` | System capabilities | `capability:read_proc` |
| `plugin` | Plugin dependencies | `plugin:10_os_info` |
| `environment` | Environment variables | `environment:HOME` |
| `package` | System packages | `package:openssh-client` |
| `permission` | Permission requirements | `permission:network_admin` |

## Plugin Dependency Specification

### Declaration Format

Dependencies are declared in plugin files using comment directives:

```bash
#!/bin/bash
# Plugin description
# DEPENDS: command:git
# DEPENDS: file:/proc/version
# DEPENDS: capability:read_proc

ARCH="$1"
# Plugin implementation...
```

### Best Practices

1. **Essential Dependencies**: Only declare truly required dependencies
2. **Graceful Degradation**: Handle missing optional dependencies in plugin code
3. **Clear Documentation**: Use descriptive comments for complex dependencies
4. **Testing**: Test plugins with and without dependencies

## Usage

### Basic Commands

```bash
# Check all dependencies
./dependency_manager.sh check

# Check specific dependency
./dependency_manager.sh check command:git

# Validate plugin dependencies
./dependency_manager.sh validate plugins/10_os_info.sh

# Generate dependency report
./dependency_manager.sh report json
./dependency_manager.sh report text

# Show help
./dependency_manager.sh help
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_DEPENDENCY_CACHING` | 1 | Enable dependency result caching |
| `DEPENDENCY_CHECK_TIMEOUT` | 30 | Timeout for dependency checks (seconds) |
| `PLUGIN_DIR` | ./plugins | Plugin directory path |
| `DEPENDENCY_CACHE_FILE` | /tmp/dependency_cache.json | Cache file location |

### Integration with collect_info.sh

The main collection script automatically uses dependency management when available:

```bash
# Enable dependency validation (default)
export ENABLE_DEPENDENCY_VALIDATION=1

# Disable dependency validation
export ENABLE_DEPENDENCY_VALIDATION=0

# Run collection with dependency management
./collect_info.sh
```

## Configuration Examples

### Development Environment

```bash
# Enable all features for development
export ENABLE_DEPENDENCY_VALIDATION=1
export ENABLE_DEPENDENCY_CACHING=1
export DEPENDENCY_CHECK_TIMEOUT=60

./collect_info.sh -o development_report.json
```

### Production Environment

```bash
# Optimized for production with caching
export ENABLE_DEPENDENCY_VALIDATION=1
export ENABLE_DEPENDENCY_CACHING=1
export DEPENDENCY_CHECK_TIMEOUT=30
export DEPENDENCY_CACHE_FILE=/var/cache/automation_deps.json

./collect_info.sh -o production_report.json
```

### Minimal Environment

```bash
# Disable dependency validation for minimal setups
export ENABLE_DEPENDENCY_VALIDATION=0

./collect_info.sh -o minimal_report.json
```

## Plugin-Specific Dependencies

### OS Information Plugin (10_os_info.sh)
- `command:uname` - Architecture detection
- `file:/etc/os-release` - OS identification
- `capability:read_proc` - Process filesystem access

### Hardware Information Plugin (20_hardware_info.sh)
- `file:/proc/cpuinfo` - CPU information
- `file:/proc/meminfo` - Memory information
- `command:df` - Disk space information
- `command:lspci` - PCIe device information
- `command:lsusb` - USB device information
- `command:bc` - Mathematical calculations

### Virtualization Plugin (25_virtualization_info.sh)
- `command:docker` - Docker container detection
- `command:podman` - Podman container detection
- `command:kubectl` - Kubernetes client
- `file:/proc/self/cgroup` - Container detection
- `command:systemd-detect-virt` - Virtualization detection

### Network Plugins (30_ip_info.sh, 31_network_stats.sh, 32_lldp_neighbors.sh)
- `command:ip` - Network interface management
- `command:ss` / `command:netstat` - Network statistics
- `command:arp` - ARP table information
- `command:lldpctl` - LLDP neighbor discovery
- `command:brctl` - Bridge information
- `file:/proc/net/route` - Routing information

### Package Information Plugin (40_packages_execs.sh)
- `command:dpkg` - Debian package management
- `command:rpm` - Red Hat package management
- `command:find` - File system search
- `command:which` - Executable location

### System Uptime Plugin (50_uptime_info.sh)
- `file:/proc/uptime` - System uptime
- `file:/proc/loadavg` - Load average
- `command:uptime` - Uptime command
- `command:who` - User session information

## Fallback Mechanisms

The dependency manager implements several fallback strategies:

1. **Command Alternatives**: Multiple commands for same functionality
2. **Graceful Degradation**: Plugins continue with reduced functionality
3. **Warning Messages**: Clear indication when dependencies are missing
4. **Cache Persistence**: Dependency status caching for performance

## Testing

### Automated Testing

Run the comprehensive test suite:

```bash
./test_dependency_manager.sh
```

### Manual Validation

Test specific scenarios:

```bash
# Test with missing dependencies
command -v nonexistent_command || echo "Expected missing"

# Test plugin validation
./dependency_manager.sh validate plugins/10_os_info.sh

# Test fallback behavior
ENABLE_DEPENDENCY_VALIDATION=0 ./collect_info.sh
```

## Troubleshooting

### Common Issues

1. **Dependency Manager Not Found**
   ```bash
   # Check if dependency_manager.sh exists and is executable
   ls -la dependency_manager.sh
   chmod +x dependency_manager.sh
   ```

2. **Permission Denied**
   ```bash
   # Check file permissions
   ls -la plugins/
   chmod +x plugins/*.sh
   ```

3. **Missing System Commands**
   ```bash
   # Check system dependencies
   ./dependency_manager.sh check command:git
   sudo apt-get install git  # On Debian/Ubuntu
   ```

4. **Cache Issues**
   ```bash
   # Clear dependency cache
   rm -f /tmp/dependency_cache.json
   ```

### Debug Mode

Enable verbose logging:

```bash
# Set debug environment
export DEPENDENCY_DEBUG=1

# Run with detailed output
./dependency_manager.sh check 2>&1 | head -50
```

## Performance Considerations

### Optimization Strategies

1. **Enable Caching**: Use `ENABLE_DEPENDENCY_CACHING=1`
2. **Reasonable Timeouts**: Set appropriate `DEPENDENCY_CHECK_TIMEOUT`
3. **Selective Validation**: Disable validation in production if stable
4. **Cache Management**: Regularly clean old cache files

### Performance Metrics

- **Initialization**: < 2 seconds for full dependency scan
- **Plugin Validation**: < 1 second per plugin
- **Cache Loading**: < 0.1 seconds
- **Memory Usage**: < 10MB total

## Security Considerations

### Best Practices

1. **Input Validation**: All dependency specifications are validated
2. **Path Safety**: File paths are sanitized before checking
3. **Command Safety**: Commands are checked with `command -v`
4. **Privilege Escalation**: Sudo usage is controlled and logged
5. **Cache Security**: Cache files are created with safe permissions

### Security Features

- No arbitrary code execution from dependency specifications
- Safe handling of file paths and command names
- Controlled sudo usage with fallback to unprivileged execution
- Audit trail of dependency checks and validation

## Advanced Usage

### Custom Dependency Types

The system can be extended with custom dependency types by modifying the `check_dependency` function in `dependency_manager.sh`.

### Integration with CI/CD

```bash
# In CI pipeline
./dependency_manager.sh check
if [ $? -ne 0 ]; then
    echo "Dependency validation failed"
    exit 1
fi

# Run collection
./collect_info.sh -o ci_report.json
```

### Monitoring Integration

```bash
# Generate monitoring-friendly output
./dependency_manager.sh report json > /var/log/dependencies.json

# Check for critical missing dependencies
./dependency_manager.sh check | grep -q "unavailable" && \
    echo "WARNING: Missing dependencies detected"
```

## Future Enhancements

1. **Dependency Graphs**: Visualize dependency relationships
2. **Auto-Installation**: Automatic dependency installation
3. **Version Constraints**: Support for version-specific dependencies
4. **Remote Dependencies**: Support for network-based dependencies
5. **Notification System**: Alert on dependency changes

## Support

For issues with dependency management:

1. Check the troubleshooting section above
2. Run the test suite: `./test_dependency_manager.sh`
3. Enable debug mode for detailed logging
4. Review plugin-specific dependency documentation
5. Validate system capabilities with: `./dependency_manager.sh check`

The dependency management system is designed to be robust, efficient, and maintainable while providing comprehensive coverage for all system information collection needs.