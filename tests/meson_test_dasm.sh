#!/bin/sh
# Functional test for spike-dasm: verify it correctly disassembles ebreak
set -e
spike_dasm="$1"
out=$(echo "DASM(00100073)" | "$spike_dasm")
echo "$out" | grep -q "ebreak" || { echo "Expected 'ebreak', got: $out"; exit 1; }
