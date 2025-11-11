#!/usr/bin/env bash
# Integration test: channel_manager.sh basic functionality

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Testing channel_manager.sh..."

# Check if script exists and is executable
if [[ ! -x "channel_manager.sh" ]]; then
    echo "SKIP: channel_manager.sh not executable"
    exit 0
fi

# Check if conda is available
if ! command -v conda &>/dev/null; then
    echo "SKIP: conda not available"
    exit 0
fi

failed=0

# Test 1: Script runs with help
if ! ./channel_manager.sh help &>/dev/null; then
    echo "FAIL: channel_manager.sh help failed"
    ((failed++))
fi

# Test 2: Script can list channels
if ! ./channel_manager.sh list &>/dev/null; then
    echo "FAIL: channel_manager.sh list failed"
    ((failed++))
fi

# Test 3: Script fails with invalid command
if ./channel_manager.sh invalid_command_xyz &>/dev/null; then
    echo "FAIL: channel_manager.sh should fail with invalid command"
    ((failed++))
fi

if [[ $failed -eq 0 ]]; then
    echo "✓ channel_manager.sh basic tests passed"
    exit 0
else
    echo "✗ $failed channel_manager.sh tests failed"
    exit 1
fi
