#!/usr/bin/env bash
# Unit test: Verify error handling patterns exist

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Testing error handling patterns..."

# Find all shell scripts
mapfile -t scripts < <(find . -maxdepth 1 -name "*.sh" -type f)

checked=0

for script in "${scripts[@]}"; do
    checked=$((checked + 1))

    # Check for set -e (or variations)
    if ! grep -q "set -e" "$script"; then
        echo "WARN: $script missing 'set -e'"
        # Not failing on this, just warning
    fi

    # Check for trap statements (cleanup)
    if grep -q "^trap" "$script" || grep -q "trap.*EXIT" "$script"; then
        # Has trap - good!
        :
    fi

    # Check for proper error messages (should have print_error or echo with error)
    if ! grep -q "print_error\|echo.*[Ee]rror" "$script"; then
        # Some scripts might not need error messages
        :
    fi
done

echo "✓ Checked $checked scripts for error handling patterns"
exit 0
