#!/bin/bash
# collect_info.sh: Discover and run plugins, merge JSON output for supported architectures

set -e
ARCH_LIST=(x86_64 arm64 i386 ppc64le s390x riscv64 mips64 aarch32 sparc64 loongarch64)
ARCH=$(uname -m)

is_supported=false
for a in "${ARCH_LIST[@]}"; do
  if [[ "$ARCH" == "$a" ]]; then
    is_supported=true
    break
  fi
done

if ! $is_supported; then
  echo "Error: $ARCH not in supported architectures" >&2
  exit 1
fi

PLUGIN_DIR="$(dirname "$0")/plugins"
JSON_OUT="{}"

for plugin in $(ls "$PLUGIN_DIR"/*.sh | sort); do
  OUT=$($plugin "$ARCH")
  JSON_OUT=$(jq -s '.[0] * .[1]' <(echo "$JSON_OUT") <(echo "$OUT"))
done

echo "$JSON_OUT"