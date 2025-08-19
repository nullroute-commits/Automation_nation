# Automation Nation - System Information Collection Tool

**A sophisticated bash-based system information collection tool with plugin architecture**

## Overview

Automation Nation's core focus is the `collect_info.sh` system information collection tool - a robust, plugin-based bash script that gathers comprehensive system information across multiple architectures and platforms. This repository contains the core bash script, its plugins, comprehensive testing infrastructure, and performance optimization variants.

### Core Capabilities

- **🔍 System Information Collection**: Plugin-based architecture for modular data collection
- **🏗️ Multi-Architecture Support**: Works across 10 major CPU architectures (x86_64, arm64, i386, ppc64le, s390x, riscv64, mips64, aarch32, sparc64, loongarch64)
- **📋 Plugin System**: 8 specialized plugins for different aspects of system information
- **🧪 Comprehensive Testing**: Full test suite with integration and performance testing
- **⚡ Performance Variants**: Optimized versions for different use cases (fast, optimized)
- **🔒 Security Features**: Configurable sudo support and CRC32 integrity verification

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    collect_info.sh - Core System               │
├─────────────────────────────────────────────────────────────────┤
│  Main Orchestrator (collect_info.sh)                           │
│  ├── Plugin discovery and execution                            │
│  ├── JSON output generation                                    │
│  ├── Architecture detection (10 supported architectures)      │
│  └── CRC32 integrity verification                              │
├─────────────────────────────────────────────────────────────────┤
│  Plugin System (plugins/)                                      │
│  ├── 10_os_info.sh           - OS and distribution detection   │
│  ├── 20_hardware_info.sh     - CPU, memory, disk, hardware    │
│  ├── 25_virtualization_info.sh - VM and container detection   │
│  ├── 30_ip_info.sh           - Network interfaces             │
│  ├── 31_network_stats.sh     - Network statistics             │
│  ├── 32_lldp_neighbors.sh    - Network discovery (LLDP/ARP)   │
│  ├── 40_packages_execs.sh    - Software inventory             │
│  └── 50_uptime_info.sh       - System metrics                 │
├─────────────────────────────────────────────────────────────────┤
│  Performance Variants                                          │
│  ├── collect_info_fast.sh    - Parallel execution optimized   │
│  ├── collect_info_optimized.sh - Simple optimized version     │
│  └── Performance testing suite                                 │
├─────────────────────────────────────────────────────────────────┤
│  Testing Infrastructure                                        │
│  ├── BATS integration tests (test/integration/)               │
│  ├── Plugin-specific tests (test/plugins/)                    │
│  ├── Performance testing (perf_*.sh, bash_perf_suite.sh)     │
│  └── Comprehensive test suite (comprehensive_test_suite.sh)   │
└─────────────────────────────────────────────────────────────────┘
```
## Features

### System Information Collection
- **Plugin-based Architecture**: Extensible design with 8 specialized plugins for easy addition of new data collectors
- **Multi-Architecture Support**: Supports 10 major CPU architectures (x86_64, ARM64, RISC-V, etc.)
- **JSON Output**: Structured, machine-readable output format with CRC32 integrity verification
- **Cross-Platform**: Works on Linux, macOS, and other Unix-like systems
- **Privilege Management**: Optional sudo support with graceful fallbacks
- **Performance Optimization**: Multiple performance variants (fast, optimized) with comprehensive benchmarking

### Testing Infrastructure
- **BATS Integration Tests**: 12 comprehensive integration tests covering core functionality
- **Plugin-Specific Tests**: 174 individual plugin tests across all 8 plugins
- **Performance Testing**: Dedicated performance test suites and regression testing
- **Cross-Architecture Testing**: Validation across all 10 supported architectures
- **Comprehensive Test Runner**: Automated test suite with detailed reporting

## Supported Architectures

The system supports the following architectures based on Q4 2024 market data:

1. **x86_64** (AMD64) - Intel/AMD 64-bit
2. **arm64** (aarch64) - ARM 64-bit (Apple Silicon, AWS Graviton, etc.)
3. **i386** (i686) - Intel/AMD 32-bit
4. **ppc64le** - PowerPC 64-bit Little Endian (IBM POWER)
5. **s390x** - IBM Z/Architecture (mainframes)
6. **riscv64** - RISC-V 64-bit (emerging open architecture)
7. **mips64** - MIPS 64-bit (embedded systems, routers)
8. **aarch32** - ARM 32-bit (Raspberry Pi, embedded systems)
9. **sparc64** - SPARC 64-bit (Oracle systems)
10. **loongarch64** - LoongArch 64-bit (Chinese architecture)

## Repository Structure

```
Automation_nation/
├── collect_info.sh                     # Main system information collector
├── collect_info_fast.sh                # Parallel execution optimized version
├── collect_info_optimized.sh           # Simple optimized version
├── plugins/                            # System information collection plugins
│   ├── 10_os_info.sh                   # OS and distribution information
│   ├── 20_hardware_info.sh             # Hardware details (CPU, memory, PCIe, USB, GPU)
│   ├── 25_virtualization_info.sh       # VM/container platform detection
│   ├── 30_ip_info.sh                   # Network interface information
│   ├── 31_network_stats.sh             # Network statistics and routing
│   ├── 32_lldp_neighbors.sh            # LLDP/ARP/bridge discovery
│   ├── 40_packages_execs.sh            # Package and executable inventory
│   └── 50_uptime_info.sh               # System uptime and load
├── test/                               # Testing infrastructure
│   ├── integration/                    # Integration tests
│   │   └── collect_info_test.bats      # BATS integration tests
│   └── plugins/                        # Plugin-specific tests
│       ├── 10_os_info_test.bats        # OS information plugin tests
│       ├── 20_hardware_info_test.bats  # Hardware information plugin tests
│       ├── 25_virtualization_info_test.bats # Virtualization detection tests
│       ├── 30_ip_info_test.bats        # Network interface tests
│       ├── 31_network_stats_test.bats  # Network statistics tests
│       ├── 32_lldp_neighbors_test.bats # Network discovery tests
│       ├── 40_packages_execs_test.bats # Package plugin tests
│       └── 50_uptime_info_test.bats    # Uptime plugin tests
├── comprehensive_test_suite.sh         # Main test runner
├── bash_perf_suite.sh                  # Performance testing suite
├── perf_analysis.sh                    # Performance analysis tools
├── perf_test_suite.sh                  # Performance regression testing
├── performance_test.sh                 # Basic performance tests
├── simple_perf_test.sh                 # Simple performance benchmarks
└── README.md                           # This file
```
## Quick Start

### Prerequisites

- **Bash 4.0+** (standard on most modern Unix-like systems)
- **Standard Unix utilities** (awk, grep, sed, etc.)
- **BATS** (for running tests - optional)
- **Git** (for repository management)

### Basic Usage

The simplest way to use the system information collector:

```bash
# Clone the repository
git clone https://github.com/nullroute-commits/Automation_nation.git
cd Automation_nation

# Run basic system information collection
./collect_info.sh

# Save output to a file
./collect_info.sh -o system_info.json

# View help
./collect_info.sh -h
```

### Configuration Options

```bash
# Disable CRC32 hashing (faster execution)
ENABLE_HASHING=0 ./collect_info.sh

# Enable sudo support for privileged operations
ENABLE_SUDO_SUPPORT=1 ./collect_info.sh

# Use performance-optimized version
./collect_info_optimized.sh -o system_info.json
```

### Running Tests

```bash
# Install BATS testing framework (if not available)
# On Ubuntu/Debian: sudo apt-get install bats
# On macOS: brew install bats-core

# Run integration tests
bats test/integration/collect_info_test.bats

# Run all plugin tests
bats test/plugins/*.bats

# Run comprehensive test suite
./comprehensive_test_suite.sh

# Run performance tests
./bash_perf_suite.sh
```
## Output Format

The system information collector outputs structured JSON data:

```json
{
  "detected_architecture": "x86_64",
  "collection_metadata": {
    "timestamp": "2024-12-15T10:30:00Z",
    "plugin_count": 8,
    "hashing_enabled": 1,
    "sudo_support_enabled": 0,
    "sudo_available": 0
  },
  "get_os_info": {
    "data": {
      "os_name": "Ubuntu",
      "os_version": "24.04.2 LTS (Noble Numbat)",
      "distribution": "ubuntu",
      "distribution_version": "24.04",
      "kernel_version": "6.11.0-1018-azure",
      "architecture": "x86_64"
    },
    "collection_timestamp": "2024-12-15T10:30:00Z",
    "completion_timestamp": "2024-12-15T10:30:01Z",
    "plugin_file_hash": "357661178",
    "function_data_hash": "1130146781"
  },
  "get_hardware_info": {
    // ... hardware information
  },
  // ... other plugin outputs
}
```

## Plugin Development

### Adding a New Plugin

1. Create a numbered plugin file in the `plugins/` directory:
```bash
# Example: 60_custom_info.sh
#!/bin/bash
get_custom_info() {
    echo '{
        "custom_field": "custom_value",
        "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }'
}
get_custom_info
```

2. Make the plugin executable:
```bash
chmod +x plugins/60_custom_info.sh
```

3. Test the plugin:
```bash
./collect_info.sh -o test_output.json
cat test_output.json | jq '.get_custom_info'
```

4. Add tests for your plugin:
```bash
# Create test/plugins/60_custom_info_test.bats
```

## Performance Optimization

### Available Variants

- **collect_info.sh**: Standard version with full functionality
- **collect_info_optimized.sh**: Simplified version optimized for speed
- **collect_info_fast.sh**: Parallel execution version (fastest)

### Performance Tuning

```bash
# Disable hashing for faster execution
ENABLE_HASHING=0 ./collect_info.sh

# Use the optimized version for production
./collect_info_optimized.sh -o production_info.json

# Monitor performance
./bash_perf_suite.sh
```

## Contributing

Contributions are welcome! Please see the following guidelines:

1. **Fork the repository** and create a feature branch
2. **Add comprehensive tests** for new functionality using BATS framework
3. **Update documentation** for any changes to plugins or core functionality
4. **Ensure all tests pass** including integration and plugin tests
5. **Follow bash best practices** and existing code style
6. **Submit a pull request** with detailed description of changes

### Development Setup

```bash
# Clone and set up development environment
git clone https://github.com/nullroute-commits/Automation_nation.git
cd Automation_nation

# Test the core functionality
./collect_info.sh -o test_output.json

# Run the full test suite
./comprehensive_test_suite.sh

# Run performance tests
./bash_perf_suite.sh

# Commit your changes
git add .
git commit -m "Brief description of changes"
git push origin feature-branch
```

## Testing

### Test Coverage

- **Integration Tests**: 12 comprehensive tests covering core functionality
- **Plugin Tests**: 174 individual tests across all 8 plugins
- **Performance Tests**: Multiple performance testing suites with regression monitoring
- **Architecture Tests**: Cross-platform compatibility validation

### Test Structure

```
test/
├── integration/
│   └── collect_info_test.bats      # Core functionality tests
└── plugins/
    ├── 10_os_info_test.bats        # OS information tests
    ├── 20_hardware_info_test.bats  # Hardware detection tests
    ├── 25_virtualization_info_test.bats # VM/container tests
    ├── 30_ip_info_test.bats        # Network interface tests
    ├── 31_network_stats_test.bats  # Network statistics tests
    ├── 32_lldp_neighbors_test.bats # Network discovery tests
    ├── 40_packages_execs_test.bats # Package management tests
    └── 50_uptime_info_test.bats    # System metrics tests
```

## Documentation

- **Core Documentation**: `COLLECT_INFO_DEVELOPMENT.md` - Main tool documentation
- **Architecture Overview**: `COMPREHENSIVE_ARCHITECTURE_DOCUMENTATION.md` - System design
- **Technical Details**: `TECHNICAL.md` - Implementation specifics
- **Configuration Guide**: `CONFIGURATION.md` - Setup and tuning options

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with **Bash** for maximum compatibility across Unix-like systems
- Testing powered by [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System)
- Plugin architecture inspired by modern modular design principles
- Cross-platform compatibility across 10 major CPU architectures

---

**Automation Nation** - Comprehensive system information collection through modular bash scripting with enterprise-grade testing and multi-architecture support.
