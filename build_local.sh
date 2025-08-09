#!/bin/bash
# Build script that compiles locally and creates a minimal Docker image

set -e

echo "🔧 Building Automation Nation using local Rust toolchain..."

# Ensure we have the required binaries
echo "📋 Checking for Rust toolchain..."
if ! command -v cargo &> /dev/null; then
    echo "❌ Cargo not found. Please install Rust: https://rustup.rs/"
    exit 1
fi

# Add musl target for static linking to avoid GLIBC issues
echo "🔗 Setting up musl target for static linking..."
if ! rustup target list --installed | grep -q "x86_64-unknown-linux-musl"; then
    echo "📦 Installing musl target..."
    rustup target add x86_64-unknown-linux-musl
fi

# Build the release binaries locally with musl for static linking
echo "🔨 Building statically linked Rust binaries..."
cargo build --release --target x86_64-unknown-linux-musl --bin web_server --bin ci_runner

# Check if binaries were built successfully
if [ ! -f "target/x86_64-unknown-linux-musl/release/web_server" ] || [ ! -f "target/x86_64-unknown-linux-musl/release/ci_runner" ]; then
    echo "❌ Failed to build required binaries"
    exit 1
fi

echo "✅ Local build completed successfully"

# Create target/release directory and copy musl binaries there for Docker build
mkdir -p target/release
cp target/x86_64-unknown-linux-musl/release/web_server target/release/
cp target/x86_64-unknown-linux-musl/release/ci_runner target/release/

# Build minimal Docker image
echo "🐳 Building minimal Docker image..."
docker build -f Dockerfile.minimal -t automation-nation .

echo "✅ Docker image built successfully!"
echo ""
echo "🚀 You can now run the container with:"
echo "   docker run -d --name automation-nation -p 3000:3000 automation-nation"
echo ""
echo "🔧 Or update docker-compose.yml to use the new build process"