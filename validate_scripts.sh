#!/usr/bin/env bash
# ---------------------------------------------------------------------
# validate_scripts.sh - Validate all shell scripts using shellcheck
#
# Usage:
#   ./validate_scripts.sh            # Check all scripts
#   ./validate_scripts.sh --fix      # Show suggestions for fixes
#   ./validate_scripts.sh --strict   # Use strict checking
#
# Requirements:
#   - shellcheck (install: apt-get install shellcheck or brew install shellcheck)
# ---------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
# BLUE='\033[0;34m'  # Unused, reserved for future use
NC='\033[0m' # No Color

# Flags
STRICT_MODE=false
SHOW_FIXES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict|-s)
            STRICT_MODE=true
            shift
            ;;
        --fix|-f)
            SHOW_FIXES=true
            shift
            ;;
        --help|-h)
            sed -n '2,10p' "$0" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    echo -e "${RED}❌ Error: shellcheck is not installed${NC}"
    echo ""
    echo "Install shellcheck:"
    echo "  - Ubuntu/Debian: sudo apt-get install shellcheck"
    echo "  - macOS: brew install shellcheck"
    echo "  - Other: https://github.com/koalaman/shellcheck#installing"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Shell Script Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find all shell scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get list of scripts (excluding examples and docs directories)
mapfile -t SCRIPTS < <(find . -maxdepth 1 -name "*.sh" -type f | sort)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No shell scripts found${NC}"
    exit 0
fi

echo "Found ${#SCRIPTS[@]} scripts to validate"
echo ""

# Shellcheck options
SHELLCHECK_OPTS=(
    --color=always
    --shell=bash
)

if [[ "$STRICT_MODE" == true ]]; then
    SHELLCHECK_OPTS+=(
        --severity=style
    )
else
    SHELLCHECK_OPTS+=(
        --severity=warning
    )
fi

if [[ "$SHOW_FIXES" == true ]]; then
    SHELLCHECK_OPTS+=(
        --format=diff
    )
fi

# Counters
total=0
passed=0
failed=0
warnings=0

# Validate each script
for script in "${SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    ((total++))

    echo -n "Checking $script_name... "

    # Run shellcheck
    if output=$(shellcheck "${SHELLCHECK_OPTS[@]}" "$script" 2>&1); then
        echo -e "${GREEN}✓ PASS${NC}"
        ((passed++))
    else
        # Check if warnings or errors
        if echo "$output" | grep -q "^In.*line.*:$"; then
            if [[ "$STRICT_MODE" == true ]] || echo "$output" | grep -q "error:"; then
                echo -e "${RED}✗ FAIL${NC}"
                ((failed++))
            else
                echo -e "${YELLOW}⚠ WARNINGS${NC}"
                ((warnings++))
            fi

            echo ""
            echo "$output"
            echo ""
        else
            echo -e "${GREEN}✓ PASS${NC}"
            ((passed++))
        fi
    fi
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total scripts: $total"
echo -e "${GREEN}Passed:  $passed${NC}"
echo -e "${YELLOW}Warnings: $warnings${NC}"
echo -e "${RED}Failed:   $failed${NC}"
echo ""

if [[ $failed -eq 0 && $warnings -eq 0 ]]; then
    echo -e "${GREEN}✅ All scripts passed validation!${NC}"
    exit 0
elif [[ $failed -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  All scripts passed but with warnings${NC}"
    echo "Run with --strict to treat warnings as errors"
    exit 0
else
    echo -e "${RED}❌ Some scripts failed validation${NC}"
    echo ""
    echo "💡 Tips:"
    echo "  - Run with --fix to see suggested fixes"
    echo "  - Check shellcheck wiki for detailed explanations:"
    echo "    https://www.shellcheck.net/wiki/"
    exit 1
fi
