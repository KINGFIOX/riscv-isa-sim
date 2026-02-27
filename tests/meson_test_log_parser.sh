#!/bin/sh
# Functional test for spike-log-parser: verify it correctly parses ld instruction
set -e
spike_log_parser="$1"
out=$(echo "core 0: 0x000000008000c36c (0xfe843783)" | "$spike_log_parser")
echo "$out" | grep -q "ld" || { echo "Expected 'ld', got: $out"; exit 1; }
