#!/usr/bin/env bats
# Hardware info plugin test for 20_hardware_info.sh

ARCHS=(x86_64 arm64 i386 ppc64le s390x riscv64 mips64 aarch32 sparc64 loongarch64)

for arch in "${ARCHS[@]}"; do
  @test "20_hardware_info.sh outputs JSON for $arch" {
    run bash plugins/20_hardware_info.sh "$arch"
    echo "$output" | jq .
  }
done
