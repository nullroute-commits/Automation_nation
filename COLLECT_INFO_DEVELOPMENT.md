# collect_info.sh Development Branch

## Purpose

This branch is dedicated to the development and enhancement of the `collect_info.sh` system information collection tool - a core component of the Automation Nation platform.

## Tool Overview

`collect_info.sh` is a sophisticated shell script orchestrator that provides comprehensive system information collection through a plugin-based architecture.

### Key Features

- **Multi-Architecture Support**: Supports 10 major CPU architectures (x86_64, arm64, i386, ppc64le, s390x, riscv64, mips64, aarch32, sparc64, loongarch64)
- **Plugin-Based Architecture**: Modular design with 8 specialized plugins
- **JSON Output**: Structured data output with metadata and integrity verification
- **Cross-Platform Compatibility**: Works across Unix-like systems
- **Performance Optimized**: Multiple versions available (standard, fast, optimized)
- **Security Features**: Configurable sudo support and CRC32 hashing

### Plugin Architecture

The tool uses a numbered plugin system for predictable execution order:

```
plugins/
├── 10_os_info.sh              # OS and distribution detection
├── 20_hardware_info.sh         # CPU, memory, disk, hardware
├── 25_virtualization_info.sh   # VM and container detection
├── 30_ip_info.sh              # Network interfaces
├── 31_network_stats.sh         # Network statistics
├── 32_lldp_neighbors.sh        # Network discovery (LLDP/ARP)
├── 40_packages_execs.sh        # Software inventory
└── 50_uptime_info.sh          # System metrics
```

### Usage

```bash
# Basic usage
./collect_info.sh

# Save to file
./collect_info.sh -o system_info.json

# With hashing disabled
ENABLE_HASHING=0 ./collect_info.sh

# With sudo support enabled
ENABLE_SUDO_SUPPORT=1 ./collect_info.sh
```

### Development Focus Areas

This branch is specifically for:

1. **Plugin Development**: Adding new plugins or enhancing existing ones
2. **Architecture Support**: Extending support for additional CPU architectures
3. **Performance Optimization**: Improving collection speed and efficiency
4. **Feature Enhancement**: Adding new configuration options and capabilities
5. **Testing**: Expanding the comprehensive test suite
6. **Documentation**: Improving plugin documentation and examples

### Related Files

- `collect_info.sh` - Main orchestrator script
- `collect_info_fast.sh` - Parallel execution optimized version
- `collect_info_optimized.sh` - Simple optimized version
- `plugins/` - Plugin directory with all collection modules
- `test/` - Testing infrastructure
- `comprehensive_test_suite.sh` - Main test runner

### Testing

Run the comprehensive test suite:
```bash
./comprehensive_test_suite.sh
```

Run quick functionality test:
```bash
./collect_info.sh -o /tmp/test_output.json
```

### Architecture Alignment

This tool implements the documented plugin-based system information collection architecture as specified in:
- `COMPREHENSIVE_ARCHITECTURE_DOCUMENTATION.md`
- `wiki/Architecture-Overview.md`
- `TECHNICAL.md`

The implementation closely matches the documented design with full plugin architecture, multi-architecture support, JSON output, and comprehensive testing infrastructure.