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
            --test)
                test_version_parsing
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

    # Query PyPI JSON API
    local pypi_url="https://pypi.org/pypi/${package}/json"
    local response

    # Try to fetch with timeout
    if command -v curl &> /dev/null; then
        response=$(curl -s -f --max-time 5 "$pypi_url" 2>/dev/null || echo "")
    elif command -v wget &> /dev/null; then
        response=$(wget -qO- --timeout=5 "$pypi_url" 2>/dev/null || echo "")
    else
        echo "⚠️  Warning: Neither curl nor wget available for PyPI API" >&2
        return 1
    fi

    if [[ -z "$response" ]] || [[ "$response" == *"404"* ]]; then
        return 1
    fi

    # Cache the response
    echo "$response" > "$cache_file"
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
    local has_vuln_warning=false
    if echo "$pypi_data" | jq -e '.vulnerabilities' &>/dev/null; then
        has_vuln_warning=true
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
    pypi_data=$(query_pypi_api "$package" "$new_version")

    if [[ $? -ne 0 ]] || [[ -z "$pypi_data" ]]; then
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

    # Step 2: Check dependency impact
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

    # Step 3: Check for security fixes (pip packages only)
    local security_info="false|unknown|"
    if [[ "$pkg_manager" == "pip" ]]; then
        security_info=$(check_pypi_security "$package" "$latest_version")
        IFS='|' read -r has_security release_type security_msg <<< "$security_info"

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

    echo "🔍 Checking conda packages..."

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "⚠️  Warning: jq not installed, falling back to text parsing"
        local outdated_output
        if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
            outdated_output=$(conda list --outdated 2>/dev/null || echo "")
        else
            outdated_output=$(conda list -n "$env_name" --outdated 2>/dev/null || echo "")
        fi

        # Parse text format: skip header lines, format as "conda|package|current|latest"
        echo "$outdated_output" | tail -n +4 | awk '{if (NF >= 4) print "conda|" $1 "|" $2 "|" $NF}'
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
    local cache_file
    cache_file=$(get_cache_file "$package" "conda")

    # Check cache first
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return
    fi

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
        local result="conda|$package|$current_version|$latest_version"
        echo "$result" | tee "$cache_file"
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
            return
        fi
        pip_cmd="${env_path}/bin/pip"
        if [[ ! -f "$pip_cmd" ]]; then
            echo "⚠️  Warning: pip not found in environment $env_name" >&2
            return
        fi
    fi

    # Check if pip is available
    if ! command -v "$pip_cmd" &> /dev/null; then
        echo "⚠️  Warning: pip not available in environment" >&2
        return
    fi

    # Get outdated packages using pip list --outdated
    local outdated_output
    outdated_output=$($pip_cmd list --outdated --format=json 2>/dev/null || echo "[]")

    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        echo "⚠️  Warning: jq not installed, skipping pip updates" >&2
        return
    fi

    # Parse JSON output
    echo "$outdated_output" | jq -r '.[] | "pip|\(.name)|\(.version)|\(.latest_version)"'
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
    local risk_factors=$9
    local security_info="${10:-false|unknown|}"

    # Parse security info
    IFS='|' read -r has_security release_type security_msg <<< "$security_info"

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

    # Collect pip updates
    if [[ "$CONDA_ONLY" != true ]]; then
        while IFS='|' read -r pkg_manager package current latest; do
            updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_pip_updates "$ENV_NAME")
    fi

    echo ""
    echo "📊 Found ${#updates[@]} package(s) with updates available"

    if [[ ${#updates[@]} -eq 0 ]]; then
        echo "   ✅ All packages are up to date!"
        exit 0
    fi

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
                approved_updates+=("$update|$risk")
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
                    approved_updates+=("$update|$risk")
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
    echo "📊 Summary:"
    echo "   ✅ Approved: ${#approved_updates[@]}"
    echo "   ⏭️  Skipped: ${#skipped_updates[@]}"

    if [[ ${#approved_updates[@]} -eq 0 ]]; then
        echo ""
        echo "No packages to update. Exiting."
        exit 0
    fi

    # Display approved updates
    echo ""
    echo "The following packages will be updated:"
    for approved in "${approved_updates[@]}"; do
        IFS='|' read -r pkg_manager package current latest risk <<< "$approved"
        echo "   - $package: $current → $latest [$risk]"
    done

    echo ""
    echo "✅ Update approval complete. Ready to install ${#approved_updates[@]} package(s)."
    echo ""
    echo "Note: Use safe_install.sh integration for actual installation (coming in next task)"
}

# Run main
main "$@"
