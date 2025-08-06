#!/bin/bash
# Plugin: Collect hardware information (JSON output)
# Accepts architecture as first argument for future arch-specific logic

ARCH="$1"

CPU=$(lscpu 2>/dev/null | grep 'Model name' | awk -F: '{print $2}' | xargs)
MEM=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
DISK=$(df -h --output=size / | awk 'NR==2 {print $1}')

CPU=${CPU:-"Unknown"}
MEM=${MEM:-"Unknown"}
DISK=${DISK:-"Unknown"}

echo "{\n  \"hardware_info\": {\n    \"cpu\": \"$CPU\",
    \"memory\": \"$MEM\",
    \"disk\": \"$DISK\",
    \"architecture\": \"$ARCH\"\n  }\n}"