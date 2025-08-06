#!/usr/bin/env bats

setup() {
  PLUGIN="plugins/50_uptime_info.sh"
}

@test "plugin outputs valid JSON given architecture" {
  run bash "$PLUGIN" "x86_64"
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null
}

@test "plugin architecture field equals input" {
  run bash "$PLUGIN" "arm64"
  arch=$(echo "$output" | jq -r .architecture)
  [ "$arch" = "arm64" ]
}

@test "plugin uptime_seconds is an integer and matches /proc/uptime" {
  run bash "$PLUGIN" "testarch"
  uptime=$(cat /proc/uptime | awk '{print int($1)}')
  plugin_uptime=$(echo "$output" | jq -r .uptime_seconds)
  [[ "$plugin_uptime" =~ ^[0-9]+$ ]]
  [ "$plugin_uptime" -eq "$uptime" ]
}