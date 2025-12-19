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
#   --quick                Skip dependency checking (much faster)
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

# Cleanup trap for unexpected exits
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "❌ Script exited unexpectedly with error code $exit_code"
        if [[ -n "${SAFE_INSTALL_PATH:-}" ]] && [[ -f "$SAFE_INSTALL_PATH" ]]; then
            echo "   You can rollback changes with: ./conda_rollback.sh"
        fi
    fi
}
trap cleanup EXIT

# Global variables
VERBOSITY="default"  # default, summary, verbose
TARGET_ENV=""
CONDA_ONLY=false
PIP_ONLY=false
QUICK_MODE=false
CHECK_DUPLICATES=false
HEALTH_CHECK_AFTER=false
EXPORT_AFTER=false
REFRESH_CACHE=false
NON_INTERACTIVE=false

# Cache directory
CACHE_DIR=""
CACHE_TTL=3600  # 1 hour in seconds

# Color codes (following toolkit patterns) - reserved for future use
# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# NC='\033[0m'  # No Color

# Risk levels
RISK_LOW="LOW"
RISK_MEDIUM="MEDIUM"
RISK_HIGH="HIGH"

test_version_parsing() {
    echo "Testing version parsing..."

    # Test cases
    local tests=(
        "1.2.3|2.0.0|major|HIGH"
        "1.2.3|1.3.0|minor|MEDIUM"
        "1.2.3|1.2.4|patch|LOW"
        "2.0.0|2.1.0|minor|MEDIUM"
    )

    for test in "${tests[@]}"; do
        IFS='|' read -r current latest expected_change expected_risk <<< "$test"

        local actual_change
        actual_change=$(compare_versions "$current" "$latest")
        local actual_risk
        actual_risk=$(calculate_base_risk "$actual_change")

        if [[ "$actual_change" == "$expected_change" ]] && [[ "$actual_risk" == "$expected_risk" ]]; then
            echo "✅ $current → $latest: $actual_change ($actual_risk)"
        else
            echo "❌ $current → $latest: expected $expected_change/$expected_risk, got $actual_change/$actual_risk"
        fi
    done

    exit 0
}

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
                # Reserved for future batch mode implementation
                echo "⚠️  Warning: --batch mode not yet implemented"
                shift
                ;;
            --quick)
                QUICK_MODE=true
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
            --test)
                test_version_parsing
                ;;
            -h|--help)
                head -n 25 "$0" | grep "^#" | sed 's/^# //' | sed 's/^#//'
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

check_internet_connectivity() {
    echo "🌐 Checking internet connectivity..."

    # Try multiple hosts for reliability
    local hosts=("8.8.8.8" "1.1.1.1" "pypi.org")
    local connected=false

    for host in "${hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &>/dev/null 2>&1; then
            connected=true
            break
        fi
    done

    if [[ "$connected" == false ]]; then
        echo "⚠️  Warning: No internet connectivity detected"
        echo "   - PyPI API queries will be unavailable"
        echo "   - Security checks will be skipped"
        echo "   - Updates will rely on local conda/pip caches only"
        echo ""

        if [[ "$NON_INTERACTIVE" != true ]]; then
            read -p "Continue without internet? [y/N]: " -n 1 -r response
            echo ""
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi

        return 1
    fi

    echo "   ✅ Internet connection available"
    return 0
}

check_required_tools() {
    echo "🔧 Checking required tools..."
    local missing_tools=()

    # Check conda/mamba
    if ! command -v conda &> /dev/null && ! command -v mamba &> /dev/null; then
        echo "❌ Neither conda nor mamba found"
        echo "   This script requires conda or mamba to be installed"
        exit 1
    fi
    echo "   ✅ conda/mamba available"

    # Check pip (warning only)
    if ! command -v pip &> /dev/null; then
        echo "   ⚠️  pip not found in PATH (pip updates will be skipped)"
    else
        echo "   ✅ pip available"
    fi

    # Check jq (warning only, will degrade gracefully)
    if ! command -v jq &> /dev/null; then
        echo "   ⚠️  jq not found (will use text parsing fallback)"
        missing_tools+=("jq")
    else
        echo "   ✅ jq available"
    fi

    # Check curl or wget for PyPI API
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo "   ⚠️  Neither curl nor wget found (PyPI API unavailable)"
        missing_tools+=("curl/wget")
    else
        echo "   ✅ curl/wget available"
    fi

    # Display warnings for missing optional tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️  Missing optional tools: ${missing_tools[*]}"
        echo "   Some features will be unavailable or use fallbacks"
    fi

    echo ""
}

detect_environment() {
    if [[ -n "$TARGET_ENV" ]]; then
        # Verify named environment exists
        if ! conda env list | grep -q "^${TARGET_ENV} "; then
            echo "❌ Environment '$TARGET_ENV' not found"
            echo ""
            echo "Available environments:"
            conda env list | tail -n +3 | awk '{print "   - " $1}'
            exit 1
        fi
        ENV_NAME="$TARGET_ENV"
    else
        # Use active environment
        if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "$CONDA_DEFAULT_ENV" == "base" ]]; then
            echo "❌ No conda environment active (or in base)"
            echo "   Activate an environment or use --name flag"
            echo ""
            echo "Available environments:"
            conda env list | tail -n +3 | awk '{print "   - " $1}'
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
        # Try to create cache directory with error handling
        if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
            echo "⚠️  Warning: Could not create cache directory at $CACHE_DIR"
            echo "   Falling back to temporary location"
            CACHE_DIR=$(mktemp -d)
            echo "📁 Using temporary cache directory: $CACHE_DIR"
        else
            echo "📁 Created cache directory: $CACHE_DIR"
        fi
    fi

    # Validate cache directory is writable
    if [[ ! -w "$CACHE_DIR" ]]; then
        echo "❌ Cache directory is not writable: $CACHE_DIR"
        CACHE_DIR=$(mktemp -d)
        echo "📁 Using temporary cache directory: $CACHE_DIR"
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

    # Check if cache file is readable
    if [[ ! -r "$cache_file" ]]; then
        echo "⚠️  Warning: Cache file not readable: $cache_file" >&2
        return 1
    fi

    # Validate cache file is not corrupt (must be valid JSON for API caches)
    if [[ "$cache_file" == *"pypi"* ]]; then
        if ! grep -q "{" "$cache_file" 2>/dev/null; then
            # Corrupt cache, delete it
            rm -f "$cache_file" 2>/dev/null
            return 1
        fi
    fi

    # Use find for cross-platform compatibility
    # Check if file was modified within CACHE_TTL seconds
    if find "$cache_file" -mmin -$((CACHE_TTL / 60)) 2>/dev/null | grep -q .; then
        return 0
    fi

    return 1
}

parse_semver() {
    local version=$1

    # Remove leading 'v' if present
    version=${version#v}

    # Extract major.minor.patch using regex
    if [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
    elif [[ $version =~ ^([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} 0"
    elif [[ $version =~ ^([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]} 0 0"
    else
        # Non-semver version (e.g., "2023.1", "latest")
        echo "0 0 0"
    fi
}

compare_versions() {
    local current=$1
    local latest=$2

    read -r curr_major curr_minor curr_patch <<< "$(parse_semver "$current")"
    read -r new_major new_minor new_patch <<< "$(parse_semver "$latest")"

    # Determine version bump type
    if [[ $new_major -gt $curr_major ]]; then
        echo "major"
    elif [[ $new_minor -gt $curr_minor ]]; then
        echo "minor"
    elif [[ $new_patch -gt $curr_patch ]]; then
        echo "patch"
    else
        echo "unknown"
    fi
}

calculate_base_risk() {
    local version_change=$1

    case "$version_change" in
        major)
            echo "$RISK_HIGH"
            ;;
        minor)
            echo "$RISK_MEDIUM"
            ;;
        patch)
            echo "$RISK_LOW"
            ;;
        *)
            echo "$RISK_MEDIUM"  # Unknown version scheme, be cautious
            ;;
    esac
}

elevate_risk() {
    local current_risk=$1
    local levels=${2:-1}  # How many levels to elevate

    case "$current_risk" in
        "$RISK_LOW")
            if [[ $levels -ge 2 ]]; then
                echo "$RISK_HIGH"
            else
                echo "$RISK_MEDIUM"
            fi
            ;;
        "$RISK_MEDIUM")
            echo "$RISK_HIGH"
            ;;
        "$RISK_HIGH")
            echo "$RISK_HIGH"  # Already at max
            ;;
    esac
}

lower_risk() {
    local current_risk=$1

    case "$current_risk" in
        "$RISK_HIGH")
            echo "$RISK_MEDIUM"
            ;;
        "$RISK_MEDIUM")
            echo "$RISK_LOW"
            ;;
        "$RISK_LOW")
            echo "$RISK_LOW"  # Already at min
            ;;
    esac
}

check_conda_dependencies() {
    local package=$1
    local new_version=$2
    local env_name=$3

    # Run conda install dry-run to see what would change
    local dry_run_output
    if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
        dry_run_output=$(conda install --dry-run "${package}=${new_version}" 2>&1 || true)
    else
        dry_run_output=$(conda install -n "$env_name" --dry-run "${package}=${new_version}" 2>&1 || true)
    fi

    # Count how many packages would be affected
    local affected_count=0
    local affected_packages=()

    # Parse output for UPDATED, DOWNGRADED, or new packages
    while IFS= read -r line; do
        if [[ $line == *"UPDATED"* ]] || [[ $line == *"DOWNGRADED"* ]] || [[ $line == *"installed"* ]]; then
            # Extract package names (this is a simplified parser)
            local pkg_name
            pkg_name=$(echo "$line" | awk '{print $1}')
            if [[ -n "$pkg_name" ]] && [[ "$pkg_name" != "$package" ]]; then
                affected_packages+=("$pkg_name")
                ((affected_count++))
            fi
        fi
    done <<< "$dry_run_output"

    echo "$affected_count|${affected_packages[*]}"
}

check_pip_dependencies() {
    local package=$1
    local new_version=$2
    local env_name=$3

    # For pip, we can use --dry-run (though it's less reliable)
    local pip_cmd="pip"
    local env_python=""

    if [[ "$env_name" != "$CONDA_DEFAULT_ENV" ]]; then
        local env_path
        env_path=$(conda env list | grep "^${env_name} " | awk '{print $NF}')
        if [[ -n "$env_path" ]]; then
            env_python="${env_path}/bin/python"
            pip_cmd="$env_python -m pip"
        fi
    fi

    # Try to get dependency info (basic implementation)
    local affected_count=0
    local affected_packages=()

    # Use pip show to get dependencies
    local deps_output
    deps_output=$(eval "$pip_cmd show $package 2>/dev/null" | grep "Requires:" || echo "")

    if [[ -n "$deps_output" ]]; then
        # Count dependencies
        affected_count=$(echo "$deps_output" | tr ',' '\n' | grep -c . || echo 0)
    fi

    echo "$affected_count|${affected_packages[*]}"
}

query_pypi_api() {
    local package=$1
    local version=$2  # Optional, defaults to latest

    # Use cache if available
    local cache_file
    cache_file=$(get_cache_file "$package" "pypi")

    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    # Check if we have the tools needed
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        # Silently fail - we already warned about this in check_required_tools
        return 1
    fi

    # Query PyPI JSON API
    local pypi_url="https://pypi.org/pypi/${package}/json"
    local response
    local fetch_failed=false

    # Try to fetch with timeout - handle network failures gracefully
    if command -v curl &> /dev/null; then
        response=$(curl -s -f --max-time 5 --connect-timeout 3 "$pypi_url" 2>/dev/null || echo "")
        if [[ -z "$response" ]]; then
            fetch_failed=true
        fi
    elif command -v wget &> /dev/null; then
        response=$(wget -qO- --timeout=5 --tries=1 "$pypi_url" 2>/dev/null || echo "")
        if [[ -z "$response" ]]; then
            fetch_failed=true
        fi
    fi

    # Handle network/API failures gracefully
    if [[ "$fetch_failed" == true ]] || [[ -z "$response" ]]; then
        # Don't spam warnings for every package - this is normal when offline
        return 1
    fi

    # Check for HTTP errors
    if [[ "$response" == *"404"* ]] || [[ "$response" == *"error"* ]]; then
        return 1
    fi

    # Validate response looks like JSON
    if ! echo "$response" | grep -q "{"; then
        return 1
    fi

    # Cache the response (handle write failures)
    if ! echo "$response" > "$cache_file" 2>/dev/null; then
        # Cache write failed, but we can still return the data
        echo "$response"
        return 0
    fi

    echo "$response"
    return 0
}

extract_release_info() {
    local package=$1
    local version=$2
    local pypi_data=$3

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "no_security_info|unknown|"
        return 0
    fi

    # Extract release-specific information
    local has_security_fix=false
    local release_type="unknown"

    # Get classifiers for the package (not version-specific, but useful)
    local classifiers_json
    classifiers_json=$(echo "$pypi_data" | jq -r '.info.classifiers[]?' 2>/dev/null || echo "")

    # Check for security-related classifiers
    if echo "$classifiers_json" | grep -qi "security"; then
        has_security_fix=true
    fi

    # Check release description for security keywords
    local description
    description=$(echo "$pypi_data" | jq -r ".releases[\"$version\"][0].comment_text // .info.description // empty" 2>/dev/null || echo "")

    if echo "$description" | grep -qiE "(security|vulnerability|CVE-|exploit)"; then
        has_security_fix=true
        release_type="security"
    elif echo "$description" | grep -qiE "(bug|fix|bugfix)"; then
        release_type="bugfix"
    elif echo "$description" | grep -qiE "(feature|enhancement|new)"; then
        release_type="feature"
    fi

    # Get vulnerability warnings if available (some packages include this)
    if echo "$pypi_data" | jq -e '.vulnerabilities' &>/dev/null; then
        has_security_fix=true
        release_type="security"
    fi

    # Output format: has_security_fix|release_type|additional_info
    if [[ "$has_security_fix" == true ]]; then
        echo "true|$release_type|Security-related update detected"
    else
        echo "false|$release_type|No security indicators found"
    fi
}

check_pypi_security() {
    local package=$1
    local new_version=$2

    # Query PyPI API
    local pypi_data
    if ! pypi_data=$(query_pypi_api "$package" "$new_version"); then
        echo "false|unknown|API unavailable"
        return 0
    fi

    if [[ -z "$pypi_data" ]]; then
        echo "false|unknown|API unavailable"
        return 0
    fi

    # Extract release information
    extract_release_info "$package" "$new_version" "$pypi_data"
}

assess_package_risk() {
    local pkg_manager=$1
    local package=$2
    local current_version=$3
    local latest_version=$4
    local env_name=$5

    # Step 1: Base risk from version change
    local version_change
    version_change=$(compare_versions "$current_version" "$latest_version")
    local risk
    risk=$(calculate_base_risk "$version_change")
    local risk_factors=("Version: $version_change")

    # Step 2: Check dependency impact (skip in quick mode - this is slow)
    local dep_count=0
    local dep_packages=""
    if [[ "$QUICK_MODE" != true ]]; then
        local dep_info
        if [[ "$pkg_manager" == "conda" ]]; then
            dep_info=$(check_conda_dependencies "$package" "$latest_version" "$env_name")
        else
            dep_info=$(check_pip_dependencies "$package" "$latest_version" "$env_name")
        fi

        IFS='|' read -r dep_count dep_packages <<< "$dep_info"

        if [[ $dep_count -gt 0 ]]; then
            risk_factors+=("Dependencies: $dep_count affected")

            if [[ $dep_count -ge 4 ]]; then
                risk=$(elevate_risk "$risk" 2)
            elif [[ $dep_count -ge 1 ]]; then
                risk=$(elevate_risk "$risk" 1)
            fi
        fi
    fi

    # Step 3: Check for security fixes (pip packages only, skip in quick mode)
    local security_info="false|unknown|"
    if [[ "$QUICK_MODE" != true ]] && [[ "$pkg_manager" == "pip" ]]; then
        security_info=$(check_pypi_security "$package" "$latest_version")
        IFS='|' read -r has_security release_type _ <<< "$security_info"

        if [[ "$has_security" == "true" ]]; then
            risk_factors+=("Security: $release_type fix detected")
            # Lower risk for security updates (encourages applying them)
            risk=$(lower_risk "$risk")
        elif [[ "$release_type" != "unknown" ]]; then
            risk_factors+=("Release type: $release_type")
        fi
    fi

    # Output: risk|version_change|dep_count|dep_packages|risk_factors|security_info
    local risk_factors_str
    risk_factors_str=$(IFS=';'; echo "${risk_factors[*]}")
    echo "$risk|$version_change|$dep_count|$dep_packages|$risk_factors_str|$security_info"
}

get_conda_updates() {
    local env_name=$1

    echo "🔍 Checking conda packages..." >&2

    # Use conda list --outdated (FAST - single command for all packages)
    local outdated_output
    if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
        outdated_output=$(conda list --outdated 2>/dev/null || echo "")
    else
        outdated_output=$(conda list -n "$env_name" --outdated 2>/dev/null || echo "")
    fi

    # Check if command failed
    if [[ -z "$outdated_output" ]]; then
        echo "⚠️  Warning: Could not list outdated conda packages" >&2
        return 1
    fi

    # Parse text format: skip header lines, format as "conda|package|current|latest"
    # Format: Name  Version  Build  Channel  Latest
    echo "$outdated_output" | tail -n +4 | awk '{if (NF >= 4) print "conda|" $1 "|" $2 "|" $NF}'
}

check_conda_package_update() {
    local package=$1
    local env_name=$2
    local cache_file
    cache_file=$(get_cache_file "$package" "conda")

    # Check cache first
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return
    fi

    # Skip empty package names
    if [[ -z "$package" ]]; then
        return
    fi

    # Get current version with error handling
    local current_version
    if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
        current_version=$(conda list "^${package}$" --json 2>/dev/null | jq -r '.[0].version' 2>/dev/null)
    else
        current_version=$(conda list -n "$env_name" "^${package}$" --json 2>/dev/null | jq -r '.[0].version' 2>/dev/null)
    fi

    # Validate current version
    if [[ -z "$current_version" ]] || [[ "$current_version" == "null" ]]; then
        return  # Package not found in environment
    fi

    # Search for latest version with timeout and error handling
    local latest_version
    if ! latest_version=$(timeout 10 conda search "$package" --json 2>/dev/null | jq -r ".[\"$package\"][-1].version" 2>/dev/null); then
        # Search failed - could be network issue or package not in current channels
        return
    fi

    # Validate result
    if [[ -z "$latest_version" ]] || [[ "$latest_version" == "null" ]]; then
        return
    fi

    # Only report if versions differ
    if [[ "$current_version" != "$latest_version" ]]; then
        local result="conda|$package|$current_version|$latest_version"
        # Try to cache, but don't fail if we can't
        echo "$result" | tee "$cache_file" 2>/dev/null || echo "$result"
    fi
}

get_pip_updates() {
    local env_name=$1

    echo "🔍 Checking pip packages..." >&2

    # Activate environment if needed
    local pip_cmd="pip"
    if [[ "$env_name" != "$CONDA_DEFAULT_ENV" ]]; then
        # Get conda environment path and use its pip
        local env_path
        env_path=$(conda env list | grep "^${env_name} " | awk '{print $NF}')
        if [[ -z "$env_path" ]]; then
            echo "⚠️  Warning: Could not find environment path for $env_name" >&2
            return 1
        fi
        pip_cmd="${env_path}/bin/pip"
        if [[ ! -f "$pip_cmd" ]]; then
            # pip not installed in this environment - this is normal
            return 0
        fi
    fi

    # Check if pip is available
    if ! command -v "$pip_cmd" &> /dev/null && [[ ! -x "$pip_cmd" ]]; then
        # pip not available - skip silently (already warned in pre-flight checks)
        return 0
    fi

    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        # Already warned in pre-flight checks
        return 0
    fi

    # Get outdated packages using pip list --outdated with error handling
    local outdated_output
    outdated_output=$(timeout 30 "$pip_cmd" list --outdated --format=json 2>/dev/null || echo "[]")

    # Validate JSON output
    if [[ -z "$outdated_output" ]] || ! echo "$outdated_output" | jq empty 2>/dev/null; then
        echo "⚠️  Warning: Could not retrieve pip package list" >&2
        return 1
    fi

    # Parse JSON output with error handling
    echo "$outdated_output" | jq -r '.[] | "pip|\(.name)|\(.version)|\(.latest_version)"' 2>/dev/null
}

format_update_display() {
    local verbosity=$1
    local pkg_manager=$2
    local package=$3
    local current=$4
    local latest=$5
    local risk=$6
    local version_change=$7
    local dep_count=$8
    local risk_factors_str=$9
    local security_info="${10:-false|unknown|}"

    # Parse security info
    IFS='|' read -r has_security release_type _ <<< "$security_info"

    case "$verbosity" in
        summary)
            # Compact one-liner
            local risk_short
            case "$risk" in
                "$RISK_LOW") risk_short="LOW" ;;
                "$RISK_MEDIUM") risk_short="MED" ;;
                "$RISK_HIGH") risk_short="HI " ;;
            esac
            local sec_indicator=""
            if [[ "$has_security" == "true" ]]; then
                sec_indicator=" 🔒"
            fi
            echo "📦 $package $current→$latest [$risk_short] ${version_change^}${sec_indicator}"
            ;;
        verbose)
            # Detailed breakdown
            echo "📦 $package: $current → $latest"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Risk Score: $risk"
            echo "├─ Version change: ${version_change^} [$risk]"
            if [[ $dep_count -gt 0 ]]; then
                echo "├─ Dependency impact: $dep_count packages affected"
            fi
            if [[ "$pkg_manager" == "pip" ]]; then
                if [[ "$has_security" == "true" ]]; then
                    echo "├─ Security: 🔒 $release_type fix detected"
                elif [[ "$release_type" != "unknown" ]]; then
                    echo "├─ Release type: $release_type"
                fi
            fi
            echo "└─ Package manager: $pkg_manager"
            ;;
        *)
            # Default compact mode
            echo "📦 $package: $current → $latest [$risk RISK]"
            local reason="${version_change^} version bump"
            if [[ $dep_count -gt 0 ]]; then
                reason="$reason + $dep_count dependency changes"
            fi
            if [[ "$has_security" == "true" ]]; then
                reason="$reason (🔒 security fix)"
            fi
            echo "   Reason: $reason"
            ;;
    esac
}

prompt_user_decision() {
    local package=$1
    local show_details=${2:-false}

    if [[ "$NON_INTERACTIVE" == true ]]; then
        echo "approve"  # Auto-approve in non-interactive mode
        return
    fi

    while true; do
        echo ""
        if [[ "$show_details" == true ]]; then
            echo -n "   [a]pprove  [s]kip  [q]uit: "
        else
            echo -n "   [a]pprove  [s]kip  [d]etails  [q]uit: "
        fi
        read -r decision

        case "$decision" in
            a|A)
                echo "approve"
                return
                ;;
            s|S)
                echo "skip"
                return
                ;;
            d|D)
                if [[ "$show_details" == false ]]; then
                    echo "details"
                    return
                fi
                ;;
            q|Q)
                echo "quit"
                return
                ;;
            *)
                echo "   Invalid choice. Please enter a, s, d, or q."
                ;;
        esac
    done
}

verify_safe_install_available() {
    local script_dir
    script_dir=$(cd "$(dirname "$0")" && pwd)
    local safe_install_path="${script_dir}/safe_install.sh"

    if [[ ! -f "$safe_install_path" ]]; then
        echo "⚠️  Warning: safe_install.sh not found in $script_dir"
        echo "   Updates will be performed without automatic rollback capability"
        echo "   Continue anyway? [y/N]: "

        if [[ "$NON_INTERACTIVE" != true ]]; then
            read -n 1 -r response
            echo ""
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi

        return 1
    fi

    echo "$safe_install_path"
    return 0
}

execute_update() {
    local pkg_manager=$1
    local package=$2
    local version=$3
    local use_safe_install=$4

    echo "🔄 Installing $package $version via $pkg_manager..."

    local exit_code=0
    local error_msg=""

    if [[ "$use_safe_install" == true ]] && [[ -n "$SAFE_INSTALL_PATH" ]]; then
        # Use safe_install.sh for automatic rollback capability
        if [[ "$pkg_manager" == "conda" ]]; then
            if ! "$SAFE_INSTALL_PATH" "${package}=${version}" --yes 2>&1; then
                exit_code=$?
                error_msg="safe_install.sh failed"
            fi
        else
            if ! "$SAFE_INSTALL_PATH" --pip "${package}==${version}" --yes 2>&1; then
                exit_code=$?
                error_msg="safe_install.sh failed"
            fi
        fi
    else
        # Direct installation without safe_install.sh
        local install_output
        if [[ "$pkg_manager" == "conda" ]]; then
            install_output=$(conda install -y "${package}=${version}" 2>&1)
            exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                # Check for common error patterns
                if echo "$install_output" | grep -qi "PackagesNotFoundError\|ResolvePackageNotFound"; then
                    error_msg="Package version not found in channels"
                elif echo "$install_output" | grep -qi "conflict\|incompatible"; then
                    error_msg="Dependency conflict detected"
                elif echo "$install_output" | grep -qi "network\|connection\|timeout"; then
                    error_msg="Network error"
                else
                    error_msg="Installation failed"
                fi
            fi
        else
            install_output=$(pip install "${package}==${version}" 2>&1)
            exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                # Check for common pip error patterns
                if echo "$install_output" | grep -qi "No matching distribution\|could not find"; then
                    error_msg="Package version not found on PyPI"
                elif echo "$install_output" | grep -qi "conflict\|incompatible"; then
                    error_msg="Dependency conflict detected"
                elif echo "$install_output" | grep -qi "network\|connection\|timeout"; then
                    error_msg="Network error"
                else
                    error_msg="Installation failed"
                fi
            fi
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo "✅ Successfully installed $package $version"
        return 0
    else
        echo "❌ Failed to install $package $version"
        if [[ -n "$error_msg" ]]; then
            echo "   Reason: $error_msg"
        fi
        return 1
    fi
}

execute_approved_updates() {
    local -n approved_refs=$1  # Name reference to array
    local use_safe_install=$2

    local total=${#approved_refs[@]}
    local succeeded=0
    local failed=0
    local failed_packages=()

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "Executing $total approved update(s)..."
    echo "═══════════════════════════════════════════════"

    for update in "${approved_refs[@]}"; do
        IFS='|' read -r pkg_manager package current latest <<< "$update"

        if execute_update "$pkg_manager" "$package" "$latest" "$use_safe_install"; then
            ((succeeded++))
        else
            ((failed++))
            failed_packages+=("$package ($current → $latest)")

            # Ask if user wants to continue after failure
            if [[ "$NON_INTERACTIVE" != true ]]; then
                echo ""
                read -p "Continue with remaining updates? [Y/n]: " -n 1 -r response
                echo ""
                if [[ "$response" =~ ^[Nn]$ ]]; then
                    # Calculate skipped count
                    local skipped=$((total - succeeded - failed))
                    echo ""
                    echo "⏭️  Skipped remaining $skipped update(s)"
                    break
                fi
            fi
        fi
        echo ""
    done

    echo "═══════════════════════════════════════════════"
    echo "Update Summary:"
    echo "  ✅ Succeeded: $succeeded"
    echo "  ❌ Failed: $failed"
    echo "  📊 Total attempted: $total"

    # Show failed packages if any
    if [[ $failed -gt 0 ]]; then
        echo ""
        echo "Failed updates:"
        for pkg in "${failed_packages[@]}"; do
            echo "  - $pkg"
        done
    fi

    echo "═══════════════════════════════════════════════"

    # Return failure status if any updates failed
    [[ $failed -eq 0 ]]
}

main() {
    parse_arguments "$@"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 Smart Update - Intelligent Package Updater"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Pre-flight checks
    check_required_tools
    check_internet_connectivity || true  # Continue even if no internet
    echo ""

    detect_environment
    initialize_cache

    # Check for safe_install.sh
    local use_safe_install=true
    SAFE_INSTALL_PATH=$(verify_safe_install_available) || use_safe_install=false
    echo ""

    # Optional: Check for duplicates first
    if [[ "$CHECK_DUPLICATES" == true ]] && [[ -f "./find_duplicates.sh" ]]; then
        echo "🔍 Checking for conda/pip duplicates..."
        ./find_duplicates.sh
        echo ""
        if [[ "$NON_INTERACTIVE" != true ]]; then
            read -p "Continue with updates? [Y/n]: " -n 1 -r response
            echo ""
            if [[ "$response" =~ ^[Nn]$ ]]; then
                exit 0
            fi
        fi
    fi

    # Collect available updates
    local updates=()
    local conda_failed=false
    local pip_failed=false

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Scanning for available updates..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ "$PIP_ONLY" != true ]]; then
        if ! while IFS='|' read -r pkg_manager package current latest; do
            [[ -n "$package" ]] && updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_conda_updates "$ENV_NAME"); then
            conda_failed=true
            echo "⚠️  Warning: Failed to retrieve all conda updates" >&2
        fi
    fi

    if [[ "$CONDA_ONLY" != true ]]; then
        if ! while IFS='|' read -r pkg_manager package current latest; do
            [[ -n "$package" ]] && updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_pip_updates "$ENV_NAME"); then
            pip_failed=true
            echo "⚠️  Warning: Failed to retrieve all pip updates" >&2
        fi
    fi

    # Check if any updates available
    if [[ ${#updates[@]} -eq 0 ]]; then
        echo "✅ All packages are up to date!"

        # Show warnings if scans failed
        if [[ "$conda_failed" == true ]] || [[ "$pip_failed" == true ]]; then
            echo ""
            echo "⚠️  Note: Some package scans failed. This might be due to:"
            echo "   - Network connectivity issues"
            echo "   - Missing tools (jq, curl, wget)"
            echo "   - Repository/channel unavailability"
        fi

        exit 0
    fi

    echo "📊 Found ${#updates[@]} package(s) with updates available"
    echo ""

    # Interactive approval workflow
    local approved_updates=()
    local skipped_updates=()

    for update in "${updates[@]}"; do
        IFS='|' read -r pkg_manager package current latest <<< "$update"

        # Assess risk for this package
        local risk_assessment
        risk_assessment=$(assess_package_risk "$pkg_manager" "$package" "$current" "$latest" "$ENV_NAME")
        IFS='|' read -r risk version_change dep_count dep_packages risk_factors security_info <<< "$risk_assessment"

        # Display update in current verbosity mode
        echo ""
        format_update_display "$VERBOSITY" "$pkg_manager" "$package" "$current" "$latest" "$risk" "$version_change" "$dep_count" "$risk_factors" "$security_info"

        # Prompt for decision
        local decision
        decision=$(prompt_user_decision "$package" false)

        case "$decision" in
            approve)
                approved_updates+=("$update")
                echo "   ✅ Approved"
                ;;
            skip)
                skipped_updates+=("$update")
                echo "   ⏭️  Skipped"
                ;;
            details)
                # Show verbose view, then prompt again
                echo ""
                format_update_display "verbose" "$pkg_manager" "$package" "$current" "$latest" "$risk" "$version_change" "$dep_count" "$risk_factors" "$security_info"
                decision=$(prompt_user_decision "$package" true)

                if [[ "$decision" == "approve" ]]; then
                    approved_updates+=("$update")
                    echo "   ✅ Approved"
                elif [[ "$decision" == "skip" ]]; then
                    skipped_updates+=("$update")
                    echo "   ⏭️  Skipped"
                elif [[ "$decision" == "quit" ]]; then
                    echo ""
                    echo "❌ Update process cancelled by user"
                    exit 0
                fi
                ;;
            quit)
                echo ""
                echo "❌ Update process cancelled by user"
                exit 0
                ;;
        esac
    done

    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Approval Summary:"
    echo "   ✅ Approved: ${#approved_updates[@]}"
    echo "   ⏭️  Skipped: ${#skipped_updates[@]}"

    if [[ ${#approved_updates[@]} -eq 0 ]]; then
        echo ""
        echo "No packages to update. Exiting."
        exit 0
    fi

    # Execute approved updates
    local update_result=0
    execute_approved_updates approved_updates "$use_safe_install" || update_result=$?

    # Post-update actions
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Post-Update Actions"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Optional: Run health check after updates
    if [[ "$HEALTH_CHECK_AFTER" == true ]]; then
        if [[ -f "./health_check.sh" ]]; then
            echo "🏥 Running health check..."
            if ./health_check.sh --quick; then
                echo "✅ Health check passed"
            else
                echo "⚠️  Health check found issues (see above)"
            fi
            echo ""
        else
            echo "⚠️  health_check.sh not found, skipping health check"
            echo ""
        fi
    fi

    # Optional: Export environment after updates
    if [[ "$EXPORT_AFTER" == true ]]; then
        if [[ -f "./export_env.sh" ]]; then
            echo "💾 Exporting updated environment..."
            if ./export_env.sh; then
                echo "✅ Environment exported successfully"
            else
                echo "⚠️  Environment export failed"
            fi
            echo ""
        else
            echo "⚠️  export_env.sh not found, skipping export"
            echo ""
        fi
    fi

    # Final summary and recommendations
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✨ Update Process Complete"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ $update_result -eq 0 ]]; then
        echo "✅ All updates completed successfully!"
        echo ""
        echo "💡 Recommendations:"
        echo "   - Test your workflows to ensure compatibility"
        if [[ "$HEALTH_CHECK_AFTER" != true ]]; then
            echo "   - Consider running: ./health_check.sh"
        fi
        if [[ "$EXPORT_AFTER" != true ]]; then
            echo "   - Consider backing up: ./export_env.sh"
        fi
    else
        echo "⚠️  Some updates failed (see summary above)"
        echo ""
        echo "💡 Troubleshooting:"
        echo "   - Check error messages above for specific issues"
        echo "   - Try updating failed packages individually"
        echo "   - Review dependency conflicts with: ./find_duplicates.sh"
        if [[ "$use_safe_install" == true ]]; then
            echo "   - Rollback if needed: ./conda_rollback.sh"
        fi
        echo ""
        exit 1
    fi
}

# Run main
main "$@"
