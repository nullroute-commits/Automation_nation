# Development Guide

This guide covers the development workflow, contribution guidelines, and best practices for the `collect_info.sh` bash system information collection tool.

## Development Environment Setup

### Prerequisites

- Unix-like operating system (Linux, macOS, BSD, etc.)
- Bash 4.0 or later
- BATS testing framework
- Standard Unix utilities: `awk`, `sed`, `grep`, `find`, `xargs`
- Optional tools for enhanced development:
  - `jq` - JSON validation and formatting
  - `shellcheck` - Bash script linting
  - `shfmt` - Bash script formatting

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd Automation_nation
   ```

2. **Install BATS testing framework**:
   ```bash
   # Ubuntu/Debian
   sudo apt install bats
   
   # macOS with Homebrew
   brew install bats-core
   
   # CentOS/RHEL/Rocky
   sudo dnf install bats
   
   # From source
   git clone https://github.com/bats-core/bats-core.git
   cd bats-core
   sudo ./install.sh /usr/local
   ```

3. **Install optional development tools**:
   ```bash
   # Ubuntu/Debian
   sudo apt install jq shellcheck
   
   # macOS with Homebrew
   brew install jq shellcheck shfmt
   ```

4. **Verify installation**:
   ```bash
   ./collect_info.sh -h
   bats --version
   bats test/integration/collect_info_test.bats
   ```

## Development Workflow

### 1. Making Changes

#### Core Script Changes
When modifying `collect_info.sh`:

1. **Test locally first**:
   ```bash
   ./collect_info.sh | jq .  # Validate JSON output
   ```

2. **Run core tests**:
   ```bash
   bats test/integration/collect_info_test.bats
   ```

3. **Test on multiple architectures if possible**:
   ```bash
   # Test architecture detection
   for arch in x86_64 arm64 i386; do
     echo "Testing $arch"
     # Use emulation or cross-compilation if available
   done
   ```

#### Plugin Development
When adding or modifying plugins:

1. **Follow the plugin naming convention**: `NN_descriptive_name.sh`
2. **Implement the plugin contract** (see Plugin Development section)
3. **Add corresponding tests**: `test/plugins/NN_descriptive_name_test.bats`
4. **Test the plugin in isolation**:
   ```bash
   ./plugins/20_hardware_info.sh x86_64 | jq .
   ```

### 2. Testing Strategy

#### Test Levels

1. **Unit Tests** - Individual plugin tests
2. **Integration Tests** - Main orchestrator functionality
3. **End-to-End Tests** - Full workflow validation
4. **Cross-Platform Tests** - Architecture and OS compatibility

#### Running Tests

```bash
# Run all tests
bats test/integration/*.bats test/plugins/*.bats

# Run specific test suites
bats test/integration/collect_info_test.bats
bats test/plugins/20_hardware_info_test.bats

# Run tests with verbose output
bats -t test/integration/collect_info_test.bats

# Run tests and capture output
bats test/integration/collect_info_test.bats 2>&1 | tee test_results.log
```

#### Writing Tests

Follow the BATS testing patterns used in existing tests:

```bash
#!/usr/bin/env bats

# Test setup
setup() {
    export TEST_DIR="/tmp/my_test"
    mkdir -p "$TEST_DIR"
    cp script.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR/script.sh"
}

# Test cleanup
teardown() {
    rm -rf "$TEST_DIR"
}

@test "script should produce valid JSON" {
    cd "$TEST_DIR"
    run ./script.sh
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}
```

### 3. Code Quality

#### Bash Best Practices

1. **Use strict mode**:
   ```bash
   set -e  # Exit on any error
   set -u  # Error on undefined variables (when appropriate)
   ```

2. **Quote variables**:
   ```bash
   echo "$variable"  # Good
   echo $variable    # Bad
   ```

3. **Use functions for reusable code**:
   ```bash
   get_cpu_info() {
       local arch="$1"
       # Function implementation
   }
   ```

4. **Handle errors gracefully**:
   ```bash
   if ! command -v jq >/dev/null 2>&1; then
       echo '{"error": "jq not available"}' >&2
       return 1
   fi
   ```

#### Linting

Use `shellcheck` to catch common issues:

```bash
# Check main script
shellcheck collect_info.sh

# Check all plugins
shellcheck plugins/*.sh

# Check test files
shellcheck test/plugins/*.bats
```

#### Formatting

Use consistent formatting:

```bash
# Format with shfmt (if available)
shfmt -w -i 4 collect_info.sh plugins/*.sh
```

## Plugin Development

### Plugin Contract

Each plugin must follow these requirements:

#### 1. Input Contract
- **Argument 1**: Architecture string (required)
- **Environment**: Clean environment with standard PATH
- **Working Directory**: Can be any location

#### 2. Output Contract
- **Format**: Valid JSON object `{"key": "value", ...}`
- **Structure**: Self-contained object (no arrays at root level)
- **Encoding**: UTF-8 text output to stdout
- **Error Handling**: stderr for warnings, non-zero exit for failures

#### 3. Plugin Template

```bash
#!/bin/bash
# Plugin: NN_plugin_name.sh
# Purpose: Brief description of what this plugin collects

set -e

# Check for required argument
if [ $# -eq 0 ]; then
    echo "Architecture parameter required" >&2
    exit 1
fi

ARCH="$1"

# Main collection function
get_plugin_data() {
    local arch="$1"
    
    # Initialize result object
    local result='{"plugin_name": "example"}'
    
    # Collect data based on architecture
    case "$arch" in
        x86_64|amd64)
            # x86_64 specific collection
            ;;
        arm64|aarch64)
            # ARM64 specific collection
            ;;
        *)
            # Generic collection for other architectures
            ;;
    esac
    
    echo "$result"
}

# Execute main function
get_plugin_data "$ARCH"
```

### Plugin Testing Template

```bash
#!/usr/bin/env bats

# Tests for NN_plugin_name.sh

setup() {
    export TEST_DIR="/tmp/plugin_test"
    mkdir -p "$TEST_DIR"
    cp plugins/NN_plugin_name.sh "$TEST_DIR/"
    chmod +x "$TEST_DIR/NN_plugin_name.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "plugin should require architecture parameter" {
    cd "$TEST_DIR"
    run ./NN_plugin_name.sh
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Architecture parameter required" ]]
}

@test "plugin should produce valid JSON output" {
    cd "$TEST_DIR"
    run ./NN_plugin_name.sh x86_64
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null
}

@test "plugin should handle different architectures" {
    cd "$TEST_DIR"
    
    for arch in x86_64 arm64 i386; do
        run ./NN_plugin_name.sh "$arch"
        [ "$status" -eq 0 ]
        echo "$output" | jq . > /dev/null
    done
}
```

## Performance Optimization

### Profiling

1. **Basic timing**:
   ```bash
   time ./collect_info.sh >/dev/null
   ```

2. **Plugin-level timing**:
   ```bash
   for plugin in plugins/*.sh; do
       echo "Testing $plugin"
       time "$plugin" x86_64 >/dev/null
   done
   ```

3. **Memory usage**:
   ```bash
   /usr/bin/time -v ./collect_info.sh >/dev/null
   ```

### Optimization Guidelines

1. **Minimize external command calls**
2. **Use bash built-ins when possible**
3. **Cache results within plugins**
4. **Use efficient text processing patterns**
5. **Avoid unnecessary file I/O**

## Architecture Support

### Adding New Architecture Support

1. **Update `detect_arch()` function** in `collect_info.sh`
2. **Update plugin logic** to handle the new architecture
3. **Add test cases** for the new architecture
4. **Update documentation**

### Testing Cross-Architecture

Use emulation when native hardware isn't available:

```bash
# Using QEMU user emulation (if available)
qemu-aarch64 ./collect_info.sh

# Using Docker multi-arch
docker run --rm -v "$PWD:/app" arm64v8/ubuntu:20.04 /app/collect_info.sh
```

## Debugging

### Debug Mode

Enable debug output:

```bash
DEBUG=1 ./collect_info.sh
```

### Common Issues

1. **JSON validation failures**:
   ```bash
   ./collect_info.sh | jq . 2>&1 | head -20
   ```

2. **Plugin execution issues**:
   ```bash
   bash -x ./plugins/20_hardware_info.sh x86_64
   ```

3. **Permission issues**:
   ```bash
   ls -la plugins/
   find plugins/ -type f ! -executable
   ```

## Contribution Guidelines

### Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes following the development guidelines
4. **Test** thoroughly using BATS
5. **Commit** with clear, descriptive messages
6. **Push** to your fork (`git push origin feature/amazing-feature`)
7. **Create** a Pull Request

### Commit Message Format

Use clear, descriptive commit messages:

```
feat: add support for LoongArch64 architecture

- Update detect_arch() function to recognize loongarch64
- Add LoongArch64-specific logic to hardware plugin
- Add test coverage for new architecture
- Update documentation

Closes #123
```

### Code Review Checklist

- [ ] All BATS tests pass
- [ ] New functionality includes tests
- [ ] Documentation updated
- [ ] No shellcheck warnings
- [ ] JSON output validated
- [ ] Cross-platform compatibility considered

## Release Process

### Version Management

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Tag releases with `git tag v1.2.3`
- Update changelog with release notes

### Testing Before Release

1. **Full test suite**:
   ```bash
   bats test/integration/*.bats test/plugins/*.bats
   ```

2. **Cross-platform validation**
3. **Performance regression testing**
4. **Documentation review**

## Support and Community

### Getting Help

- Check existing documentation
- Review test cases for examples
- Open an issue for bugs or feature requests

### Contributing Back

- Share improvements via pull requests
- Report bugs with detailed reproduction steps
- Suggest enhancements with use cases
- Help improve documentation