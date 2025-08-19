# Automation Nation - Bash System Information Collection Tool

**A robust, plugin-based bash script for comprehensive system information collection with multi-architecture support**

## Overview

This repository contains `collect_info.sh` - a sophisticated bash script that collects comprehensive system information through a modular plugin architecture. The tool is designed for testing and development with a focus on reliability, performance, and cross-platform compatibility.

## Key Features

- 🔍 **Plugin-Based Architecture**: Modular design with 8 specialized collection plugins
- 🏗️ **Multi-Architecture Support**: Works across 10 major CPU architectures
- 📋 **JSON Output**: Structured data with metadata and integrity verification
- 🧪 **Comprehensive Testing**: Full BATS test suite for reliability
- ⚡ **Performance Variants**: Multiple optimized versions available
- 🔒 **Security Features**: Configurable privilege escalation with safety controls

## Quick Start

### Basic Usage

```bash
# Run basic system information collection
./collect_info.sh

# Save output to file
./collect_info.sh -o system_info.json

# View help
./collect_info.sh -h
```

### Running Tests

```bash
# Run all BATS tests
bats test/integration/collect_info_test.bats
bats test/plugins/*.bats

# Run specific plugin tests
bats test/plugins/20_hardware_info_test.bats
```

## Architecture

### Supported Architectures
- x86_64 (Intel/AMD 64-bit)
- arm64/aarch64 (ARM 64-bit)
- i386/i686 (Intel 32-bit)
- ppc64le (PowerPC 64-bit Little Endian)
- s390x (IBM System z)
- riscv64 (RISC-V 64-bit)
- mips64 (MIPS 64-bit)
- aarch32 (ARM 32-bit)
- sparc64 (SPARC 64-bit)
- loongarch64 (LoongArch 64-bit)

### Plugin System

```
plugins/
├── 10_os_info.sh              # OS and distribution detection
├── 20_hardware_info.sh         # CPU, memory, disk, hardware
├── 25_virtualization_info.sh   # VM and container detection
├── 30_ip_info.sh              # Network interfaces and IP info
├── 31_network_stats.sh         # Network statistics
├── 32_lldp_neighbors.sh        # Network discovery (LLDP/ARP)
├── 40_packages_execs.sh        # Software inventory
└── 50_uptime_info.sh          # System metrics and uptime
```

## Performance Variants

- **`collect_info.sh`** - Standard version with full features
- **`collect_info_fast.sh`** - Parallel execution for speed
- **`collect_info_optimized.sh`** - Simplified optimized version
- **`collect_info_ultra_optimized.sh`** - Minimal overhead version

## Testing Framework

This project uses [BATS](https://github.com/bats-core/bats-core) for testing:

### Test Structure
```
test/
├── integration/
│   └── collect_info_test.bats    # Main orchestrator tests
└── plugins/
    ├── 10_os_info_test.bats      # OS plugin tests
    ├── 20_hardware_info_test.bats # Hardware plugin tests
    ├── 30_ip_info_test.bats      # Network plugin tests
    └── ...                       # Additional plugin tests
```

### Test Categories
- **Architecture Detection Tests** - Validates architecture detection across platforms
- **Plugin Discovery Tests** - Tests plugin loading and execution order
- **JSON Validation Tests** - Ensures output format compliance
- **Error Condition Tests** - Tests error handling and graceful degradation
- **Integration Tests** - End-to-end workflow validation

## Development

### Prerequisites
- Bash 4.0+ (most modern Unix-like systems)
- BATS testing framework
- Standard Unix utilities (awk, sed, grep, etc.)
- Optional: jq for JSON validation

### Installing BATS
```bash
# Ubuntu/Debian
sudo apt install bats

# macOS with Homebrew
brew install bats-core

# From source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Development Workflow
1. Make changes to scripts or plugins
2. Run relevant BATS tests
3. Test on target architectures
4. Update documentation as needed

### Adding New Plugins
1. Create numbered plugin file (e.g., `60_new_plugin.sh`)
2. Follow plugin contract (see TECHNICAL.md)
3. Add corresponding test file
4. Update documentation

## Security Considerations

- **Privilege Escalation**: Configurable sudo support (disabled by default)
- **Input Validation**: All inputs validated before processing
- **Output Sanitization**: JSON output properly escaped
- **File Permissions**: Strict permissions on temporary files
- **CRC32 Verification**: Optional integrity checking of output

## Configuration

Environment variables:
- `ENABLE_HASHING=1` - Enable CRC32 integrity verification (default: 1)
- `ENABLE_SUDO_SUPPORT=0` - Enable sudo for privileged operations (default: 0)
- `DEBUG=1` - Enable debug output for troubleshooting

## Output Format

The tool outputs structured JSON with the following format:

```json
{
  "collection_metadata": {
    "timestamp": "2024-01-01T12:00:00Z",
    "detected_architecture": "x86_64",
    "collection_duration_ms": 1234,
    "plugin_count": 8
  },
  "plugin_function_name": {
    "data": { /* plugin data */ },
    "collection_timestamp": "2024-01-01T12:00:01Z"
  }
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the full test suite
5. Submit a pull request

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Documentation

- [DEVELOPMENT.md](DEVELOPMENT.md) - Development workflow and contribution guidelines
- [TESTING.md](TESTING.md) - Testing framework documentation and best practices
- [TECHNICAL.md](TECHNICAL.md) - Technical implementation details and plugin development