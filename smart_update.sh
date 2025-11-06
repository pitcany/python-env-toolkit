#!/usr/bin/env bash
#
# smart_update.sh - Intelligent package update assistant with risk-based decision making
#
# Usage:
#   ./smart_update.sh [OPTIONS]
#
# Options:
#   --verbose              Show detailed risk breakdown
#   --summary              Show minimal one-line output
#   --name ENV_NAME        Target specific environment
#   --conda-only           Only check conda packages
#   --pip-only             Only check pip packages
#   --batch                Show all updates first, then batch approval
#   --check-duplicates     Run find_duplicates.sh before starting
#   --health-check-after   Run health_check.sh after updates
#   --export-after         Export environment after updates
#   --refresh              Clear cache and refresh data
#   --yes                  Non-interactive mode (for testing)
#
# Examples:
#   ./smart_update.sh
#   ./smart_update.sh --verbose --name myenv
#   ./smart_update.sh --summary --conda-only

set -euo pipefail

# Global variables
VERBOSITY="default"  # default, summary, verbose
TARGET_ENV=""
CONDA_ONLY=false
PIP_ONLY=false
BATCH_MODE=false
CHECK_DUPLICATES=false
HEALTH_CHECK_AFTER=false
EXPORT_AFTER=false
REFRESH_CACHE=false
NON_INTERACTIVE=false

# Cache directory
CACHE_DIR=""
CACHE_TTL=3600  # 1 hour in seconds

# Color codes (following toolkit patterns)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Risk levels
RISK_LOW="LOW"
RISK_MEDIUM="MEDIUM"
RISK_HIGH="HIGH"

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSITY="verbose"
                shift
                ;;
            --summary)
                VERBOSITY="summary"
                shift
                ;;
            --name)
                TARGET_ENV="$2"
                shift 2
                ;;
            --conda-only)
                CONDA_ONLY=true
                shift
                ;;
            --pip-only)
                PIP_ONLY=true
                shift
                ;;
            --batch)
                BATCH_MODE=true
                shift
                ;;
            --check-duplicates)
                CHECK_DUPLICATES=true
                shift
                ;;
            --health-check-after)
                HEALTH_CHECK_AFTER=true
                shift
                ;;
            --export-after)
                EXPORT_AFTER=true
                shift
                ;;
            --refresh)
                REFRESH_CACHE=true
                shift
                ;;
            --yes)
                NON_INTERACTIVE=true
                shift
                ;;
            -h|--help)
                head -n 30 "$0" | grep "^#" | sed 's/^# //'
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

detect_environment() {
    if [[ -n "$TARGET_ENV" ]]; then
        # Verify named environment exists
        if ! conda env list | grep -q "^${TARGET_ENV} "; then
            echo "❌ Environment '$TARGET_ENV' not found"
            exit 1
        fi
        ENV_NAME="$TARGET_ENV"
    else
        # Use active environment
        if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "$CONDA_DEFAULT_ENV" == "base" ]]; then
            echo "❌ No conda environment active (or in base)"
            echo "   Activate an environment or use --name flag"
            exit 1
        fi
        ENV_NAME="$CONDA_DEFAULT_ENV"
    fi

    # Set cache directory
    CACHE_DIR="/tmp/smart_update_cache_${ENV_NAME}"

    echo "🧭 Environment: $ENV_NAME"
}

initialize_cache() {
    if [[ "$REFRESH_CACHE" == true ]] && [[ -d "$CACHE_DIR" ]]; then
        echo "🧹 Clearing cache..."
        rm -rf "$CACHE_DIR"
    fi

    if [[ ! -d "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR"
        echo "📁 Created cache directory: $CACHE_DIR"
    fi
}

get_cache_file() {
    local package=$1
    local cache_type=$2  # "pypi" or "conda"
    echo "${CACHE_DIR}/${cache_type}_${package}.json"
}

is_cache_valid() {
    local cache_file=$1

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    # Use find for cross-platform compatibility
    # Check if file was modified within CACHE_TTL seconds
    if find "$cache_file" -mmin -$((CACHE_TTL / 60)) 2>/dev/null | grep -q .; then
        return 0
    fi

    return 1
}

get_conda_updates() {
    local env_name=$1

    echo "🔍 Checking conda packages..."

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "⚠️  Warning: jq not installed, falling back to text parsing"
        # Fallback: use conda list --outdated without JSON
        if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
            conda list --outdated 2>/dev/null || echo ""
        else
            conda list -n "$env_name" --outdated 2>/dev/null || echo ""
        fi
        return
    fi

    # Use JSON output for reliable parsing
    local json_output
    if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
        json_output=$(conda list --json 2>/dev/null)
    else
        json_output=$(conda list -n "$env_name" --json 2>/dev/null)
    fi

    # Parse and check each package for updates
    echo "$json_output" | jq -r '.[] | select(.channel != "pypi") | .name' | while read -r package; do
        check_conda_package_update "$package" "$env_name"
    done
}

check_conda_package_update() {
    local package=$1
    local env_name=$2

    # Get current version
    local current_version
    if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
        current_version=$(conda list "^${package}$" --json 2>/dev/null | jq -r '.[0].version')
    else
        current_version=$(conda list -n "$env_name" "^${package}$" --json 2>/dev/null | jq -r '.[0].version')
    fi

    # Search for latest version
    local latest_version
    latest_version=$(conda search "$package" --json 2>/dev/null | jq -r ".[\"$package\"][-1].version" 2>/dev/null)

    if [[ -z "$latest_version" ]] || [[ "$latest_version" == "null" ]]; then
        return  # No update available or package not found
    fi

    if [[ "$current_version" != "$latest_version" ]]; then
        echo "conda|$package|$current_version|$latest_version"
    fi
}

main() {
    parse_arguments "$@"
    detect_environment
    initialize_cache

    local updates=()

    # Collect conda updates
    if [[ "$PIP_ONLY" != true ]]; then
        while IFS='|' read -r pkg_manager package current latest; do
            updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_conda_updates "$ENV_NAME")
    fi

    echo ""
    echo "📊 Found ${#updates[@]} conda package(s) with updates available"

    # Display updates for testing
    for update in "${updates[@]}"; do
        IFS='|' read -r pkg_manager package current latest <<< "$update"
        echo "   $package: $current → $latest"
    done
}

# Run main
main "$@"
