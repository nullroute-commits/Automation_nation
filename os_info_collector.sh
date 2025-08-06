#!/bin/bash
# Plugin: Collect OS information (JSON output)
# Accepts architecture as first argument for future arch-specific logic

ARCH="$1"

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  PRETTY_NAME=${PRETTY_NAME:-"$NAME $VERSION"}
else
  PRETTY_NAME="Unknown"
fi

echo "{\n  \"os_info\": {\n    \"kernel\": \"$(uname -s)\",\n    \"kernel_version\": \"$(uname -r)\",\n    \"architecture\": \"$ARCH\",\n    \"distro\": \"$PRETTY_NAME\"\n  }\n}"