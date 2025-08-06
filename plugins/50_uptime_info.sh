#!/bin/bash

# Bash uptime plugin

uptime_info() {
    uptime | awk -F'up ' '{ print $2 }' | awk -F',' '{ print $1 }'
}

uptime_info
