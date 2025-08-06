#!/usr/bin/env bats
# Main script tests for collect_info.sh

@test "Fails for unsupported arch" {
  run bash collect_info.sh <<< 'unsupported'
  [ "$status" -eq 1 ]
}

@test "Runs and outputs JSON for supported arch" {
  run bash collect_info.sh
  echo "$output" | jq .
}