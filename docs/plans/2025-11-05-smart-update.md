# Smart Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an intelligent package update assistant that calculates risk scores and guides users through interactive approval decisions.

**Architecture:** Standalone bash script following the toolkit's error handling patterns (`set -euo pipefail`), with modular functions for package detection, risk scoring, PyPI API integration, and interactive prompts. Integrates with existing `safe_install.sh` for rollback capability.

**Tech Stack:** Bash 4+, conda/pip CLI tools, jq for JSON parsing, curl for PyPI API, existing toolkit scripts

---

## Task 1: Create Script Structure and Argument Parsing

**Files:**
- Create: `smart_update.sh`

**Step 1: Create script with header and error handling**

Create `smart_update.sh`:

```bash
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
```

**Step 2: Implement argument parsing function**

Add to `smart_update.sh`:

```bash
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
```

**Step 3: Implement environment detection function**

Add to `smart_update.sh`:

```bash
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
```

**Step 4: Add main function and script entry point**

Add to `smart_update.sh`:

```bash
main() {
    parse_arguments "$@"
    detect_environment

    echo "✅ Script initialized successfully"
    echo "   Verbosity: $VERBOSITY"
    echo "   Cache: $CACHE_DIR"
}

# Run main
main "$@"
```

**Step 5: Make executable and test basic functionality**

```bash
chmod +x smart_update.sh
./smart_update.sh --help
# Expected: Show usage information

# Test with no active environment
./smart_update.sh
# Expected: Error message about no active environment

# Test argument parsing
./smart_update.sh --verbose --conda-only
# Expected: Error (no active env) but should parse args correctly
```

**Step 6: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add script structure and argument parsing

- Add script header with comprehensive usage documentation
- Implement argument parsing for all command-line options
- Add environment detection with validation
- Set up global variables and color codes"
```

---

## Task 2: Implement Cache Management

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add cache initialization function**

Add after the `detect_environment` function:

```bash
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

    local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))

    if [[ $cache_age -gt $CACHE_TTL ]]; then
        return 1
    fi

    return 0
}
```

**Step 2: Update main function to initialize cache**

Update the `main` function:

```bash
main() {
    parse_arguments "$@"
    detect_environment
    initialize_cache

    echo "✅ Initialization complete"
}
```

**Step 3: Test cache functionality**

```bash
# Create test environment
conda create -n test-smart-update python=3.11 -y
conda activate test-smart-update

# Run script to create cache
./smart_update.sh

# Verify cache directory created
ls -la /tmp/smart_update_cache_test-smart-update/

# Test refresh flag
./smart_update.sh --refresh
# Expected: "Clearing cache..." message

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 4: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add cache management functionality

- Implement cache initialization and directory creation
- Add cache validation based on TTL
- Support --refresh flag to clear stale cache"
```

---

## Task 3: Implement Conda Package Detection

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add function to detect outdated conda packages**

Add before the `main` function:

```bash
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
```

**Step 2: Update main to call conda detection**

Update the `main` function:

```bash
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
```

**Step 3: Test conda detection**

```bash
# Create test environment with older packages
conda create -n test-smart-update python=3.10 numpy=1.23.0 -y
conda activate test-smart-update

# Run script
./smart_update.sh

# Expected: List of outdated packages (if any exist)

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 4: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add conda package update detection

- Implement JSON-based conda package version checking
- Add fallback for systems without jq
- Query conda search for latest versions
- Display outdated packages"
```

---

## Task 4: Implement Pip Package Detection

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add function to detect outdated pip packages**

Add after `check_conda_package_update`:

```bash
get_pip_updates() {
    local env_name=$1

    echo "🔍 Checking pip packages..."

    # Get list of outdated pip packages
    local pip_cmd="pip"

    # Check if we need to target a specific environment
    local pip_list_output
    if [[ "$env_name" == "$CONDA_DEFAULT_ENV" ]]; then
        pip_list_output=$(pip list --outdated --format=json 2>/dev/null || echo "[]")
    else
        # For named environment, we need to use that env's pip
        local env_python=$(conda env list | grep "^${env_name} " | awk '{print $2}')/bin/python
        pip_list_output=$("$env_python" -m pip list --outdated --format=json 2>/dev/null || echo "[]")
    fi

    # Check if jq is available
    if command -v jq &> /dev/null; then
        echo "$pip_list_output" | jq -r '.[] | "pip|\(.name)|\(.version)|\(.latest_version)"'
    else
        # Fallback: parse JSON manually (basic)
        echo "$pip_list_output" | grep -o '"name":"[^"]*","version":"[^"]*","latest_version":"[^"]*"' | \
            sed 's/"name":"\([^"]*\)","version":"\([^"]*\)","latest_version":"\([^"]*\)"/pip|\1|\2|\3/'
    fi
}
```

**Step 2: Update main to include pip updates**

Update the `main` function to collect both conda and pip updates:

```bash
main() {
    parse_arguments "$@"
    detect_environment
    initialize_cache

    local updates=()

    # Collect conda updates
    if [[ "$PIP_ONLY" != true ]]; then
        while IFS='|' read -r pkg_manager package current latest; do
            [[ -n "$package" ]] && updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_conda_updates "$ENV_NAME")
    fi

    # Collect pip updates
    if [[ "$CONDA_ONLY" != true ]]; then
        while IFS='|' read -r pkg_manager package current latest; do
            [[ -n "$package" ]] && updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_pip_updates "$ENV_NAME")
    fi

    echo ""
    if [[ ${#updates[@]} -eq 0 ]]; then
        echo "✅ All packages are up to date!"
        exit 0
    fi

    echo "📊 Found ${#updates[@]} package(s) with updates available"
    echo ""

    # Display updates for testing
    for update in "${updates[@]}"; do
        IFS='|' read -r pkg_manager package current latest <<< "$update"
        echo "   [$pkg_manager] $package: $current → $latest"
    done
}
```

**Step 3: Test pip detection**

```bash
# Create test environment with pip packages
conda create -n test-smart-update python=3.11 -y
conda activate test-smart-update
pip install requests==2.28.0  # Install older version

# Run script
./smart_update.sh

# Expected: Show requests update available

# Test flags
./smart_update.sh --conda-only
# Expected: No pip packages shown

./smart_update.sh --pip-only
# Expected: Only pip packages shown

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 4: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add pip package update detection

- Implement pip list --outdated parsing
- Support both active and named environments
- Add --conda-only and --pip-only filtering
- Display combined conda and pip updates"
```

---

## Task 5: Implement Semantic Version Parsing and Risk Scoring

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add semantic version parsing function**

Add after cache functions:

```bash
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
```

**Step 2: Add base risk calculation from semver**

Add after version comparison:

```bash
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
```

**Step 3: Test version parsing and risk calculation**

Add a test mode to the script for manual verification:

```bash
# Add this test function before main()
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

        local actual_change=$(compare_versions "$current" "$latest")
        local actual_risk=$(calculate_base_risk "$actual_change")

        if [[ "$actual_change" == "$expected_change" ]] && [[ "$actual_risk" == "$expected_risk" ]]; then
            echo "✅ $current → $latest: $actual_change ($actual_risk)"
        else
            echo "❌ $current → $latest: expected $expected_change/$expected_risk, got $actual_change/$actual_risk"
        fi
    done

    exit 0
}

# Add test flag to parse_arguments
# In the case statement, add:
#            --test)
#                test_version_parsing
#                ;;
```

**Step 4: Run tests**

```bash
./smart_update.sh --test
# Expected: All tests pass with ✅
```

**Step 5: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add semantic version parsing and risk scoring

- Implement semver parsing with major.minor.patch extraction
- Add version comparison to detect change type
- Calculate base risk from version bump (major=HIGH, minor=MEDIUM, patch=LOW)
- Add risk elevation and lowering helpers
- Include test mode for verification"
```

---

## Task 6: Implement Dependency Impact Analysis

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add conda dependency check function**

Add after risk calculation functions:

```bash
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
        if [[ $line =~ UPDATED|DOWNGRADED|installed ]]; then
            # Extract package names (this is a simplified parser)
            local pkg_name=$(echo "$line" | awk '{print $1}')
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
        env_python=$(conda env list | grep "^${env_name} " | awk '{print $2}')/bin/python
        pip_cmd="$env_python -m pip"
    fi

    # Try to get dependency info (basic implementation)
    local affected_count=0
    local affected_packages=()

    # Use pip show to get dependencies
    local deps_output=$(eval "$pip_cmd show $package 2>/dev/null" | grep "Requires:" || echo "")

    if [[ -n "$deps_output" ]]; then
        # Count dependencies
        affected_count=$(echo "$deps_output" | tr ',' '\n' | grep -v "^$" | wc -l)
    fi

    echo "$affected_count|${affected_packages[*]}"
}
```

**Step 2: Create comprehensive risk assessment function**

Add after dependency check functions:

```bash
assess_package_risk() {
    local pkg_manager=$1
    local package=$2
    local current_version=$3
    local latest_version=$4
    local env_name=$5

    # Step 1: Base risk from version change
    local version_change=$(compare_versions "$current_version" "$latest_version")
    local risk=$(calculate_base_risk "$version_change")
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

    # Output: risk|version_change|dep_count|dep_packages|risk_factors
    local risk_factors_str=$(IFS=';'; echo "${risk_factors[*]}")
    echo "$risk|$version_change|$dep_count|$dep_packages|$risk_factors_str"
}
```

**Step 3: Test dependency analysis**

```bash
# Create test environment
conda create -n test-smart-update python=3.11 numpy=1.23.0 -y
conda activate test-smart-update

# Manually test dependency check
# Add temporary debug code to main():
# assess_package_risk "conda" "numpy" "1.23.0" "1.26.0" "$ENV_NAME"

./smart_update.sh

# Verify dependency impact is calculated
# Expected: Should show affected packages if any

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 4: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add dependency impact analysis

- Implement conda dry-run parsing for dependency detection
- Add pip dependency checking via pip show
- Integrate dependency count into risk assessment
- Elevate risk based on number of affected packages
- Track which packages would be affected"
```

---

## Task 7: Implement PyPI Security and Release Info

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add PyPI API query function with caching**

Add after dependency functions:

```bash
query_pypi_api() {
    local package=$1
    local cache_file=$(get_cache_file "$package" "pypi")

    # Check cache first
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return
    fi

    # Query PyPI API
    local pypi_url="https://pypi.org/pypi/${package}/json"
    local response=$(curl -s -f -m 10 "$pypi_url" 2>/dev/null || echo "")

    if [[ -z "$response" ]]; then
        echo "{}"  # Return empty JSON on failure
        return
    fi

    # Cache the response
    echo "$response" > "$cache_file"
    echo "$response"
}

extract_release_info() {
    local package=$1
    local version=$2
    local pypi_json=$3

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "unknown||"
        return
    fi

    # Extract release info for specific version
    local release_info=$(echo "$pypi_json" | jq -r ".releases[\"$version\"][0] // {}")

    # Check for security-related classifiers
    local classifiers=$(echo "$pypi_json" | jq -r '.info.classifiers[]? // ""' 2>/dev/null)
    local has_security=false

    if echo "$classifiers" | grep -qi "security"; then
        has_security=true
    fi

    # Determine release type from version number and classifiers
    local release_type="features"
    if echo "$classifiers" | grep -qi "bug"; then
        release_type="bugfix"
    fi
    if [[ "$has_security" == true ]]; then
        release_type="security"
    fi

    echo "$release_type|$has_security|"
}
```

**Step 2: Integrate PyPI info into risk assessment**

Update `assess_package_risk` function:

```bash
assess_package_risk() {
    local pkg_manager=$1
    local package=$2
    local current_version=$3
    local latest_version=$4
    local env_name=$5

    # Step 1: Base risk from version change
    local version_change=$(compare_versions "$current_version" "$latest_version")
    local risk=$(calculate_base_risk "$version_change")
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

    # Step 3: Check PyPI for security info (pip packages only)
    local release_type="unknown"
    local has_security=false

    if [[ "$pkg_manager" == "pip" ]]; then
        local pypi_json=$(query_pypi_api "$package")
        IFS='|' read -r release_type has_security _ <<< "$(extract_release_info "$package" "$latest_version" "$pypi_json")"

        if [[ "$release_type" == "security" ]] || [[ "$has_security" == true ]]; then
            risk=$(lower_risk "$risk")
            risk_factors+=("Security fix")
        elif [[ "$release_type" == "bugfix" ]]; then
            risk_factors+=("Bug fixes")
        fi
    fi

    # Output: risk|version_change|dep_count|dep_packages|release_type|risk_factors
    local risk_factors_str=$(IFS=';'; echo "${risk_factors[*]}")
    echo "$risk|$version_change|$dep_count|$dep_packages|$release_type|$risk_factors_str"
}
```

**Step 3: Test PyPI integration**

```bash
# Test cache and API
conda create -n test-smart-update python=3.11 -y
conda activate test-smart-update
pip install requests==2.28.0

./smart_update.sh --refresh

# Verify:
# 1. Cache directory created
# 2. PyPI API called (check cache files)
# 3. Release info extracted

# Check cache files
ls -la /tmp/smart_update_cache_test-smart-update/

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 4: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add PyPI API integration for security info

- Implement PyPI API querying with caching
- Extract release classification (security, bugfix, features)
- Lower risk for security fixes
- Gracefully degrade when API unavailable or jq missing
- Honor cache TTL of 1 hour"
```

---

## Task 8: Implement Interactive Prompts (Compact Mode)

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add prompt display function (compact mode)**

Add after risk assessment:

```bash
display_update_compact() {
    local pkg_manager=$1
    local package=$2
    local current=$3
    local latest=$4
    local risk=$5
    local risk_reason=$6

    # Color code risk level
    local risk_color=""
    case "$risk" in
        "$RISK_LOW")
            risk_color="$GREEN"
            ;;
        "$RISK_MEDIUM")
            risk_color="$YELLOW"
            ;;
        "$RISK_HIGH")
            risk_color="$RED"
            ;;
    esac

    echo ""
    echo "📦 $package: $current → $latest [${risk_color}${risk}${NC}]"
    echo "   Reason: $risk_reason"
}

prompt_user_action() {
    local package=$1

    if [[ "$NON_INTERACTIVE" == true ]]; then
        echo "approve"  # Auto-approve in non-interactive mode
        return
    fi

    echo ""
    read -p "   [a]pprove  [s]kip  [d]etails  [q]uit: " -n 1 -r choice
    echo ""

    case "$choice" in
        a|A)
            echo "approve"
            ;;
        s|S)
            echo "skip"
            ;;
        d|D)
            echo "details"
            ;;
        q|Q)
            echo "quit"
            ;;
        *)
            echo "skip"  # Default to skip on invalid input
            ;;
    esac
}
```

**Step 2: Add summary mode display**

Add after compact display:

```bash
display_update_summary() {
    local pkg_manager=$1
    local package=$2
    local current=$3
    local latest=$4
    local risk=$5
    local risk_reason=$6

    # Abbreviate risk
    local risk_abbr=""
    case "$risk" in
        "$RISK_LOW") risk_abbr="LOW" ;;
        "$RISK_MEDIUM") risk_abbr="MED" ;;
        "$RISK_HIGH") risk_abbr="HI" ;;
    esac

    # Shorten risk reason
    local short_reason=$(echo "$risk_reason" | sed 's/Version: //' | sed 's/Dependencies: /deps:/')

    echo "📦 $package $current→$latest [$risk_abbr] $short_reason | [a/s/d/q]: "
}
```

**Step 3: Add verbose mode display**

Add after summary display:

```bash
display_update_verbose() {
    local pkg_manager=$1
    local package=$2
    local current=$3
    local latest=$4
    local risk=$5
    local version_change=$6
    local dep_count=$7
    local dep_packages=$8
    local release_type=$9
    local risk_factors=${10}

    echo ""
    echo "📦 $package: $current → $latest"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Risk Score: $risk"

    # Parse risk factors
    IFS=';' read -ra factors <<< "$risk_factors"
    for factor in "${factors[@]}"; do
        if [[ "$factor" =~ Version ]]; then
            echo "├─ $factor"
        elif [[ "$factor" =~ Dependencies ]]; then
            echo "├─ Dependency impact: $dep_count packages affected"
            if [[ -n "$dep_packages" ]]; then
                for dep in $dep_packages; do
                    echo "│  └─ $dep"
                done
            fi
        elif [[ "$factor" =~ Security ]]; then
            echo "├─ Security fix: Yes"
        elif [[ "$factor" =~ Bug ]]; then
            echo "├─ Release type: Bug fixes"
        fi
    done

    if [[ "$release_type" != "unknown" ]]; then
        echo "└─ Release type: $release_type"
    fi
}
```

**Step 4: Create main display router**

Add after verbose display:

```bash
display_update() {
    local verbosity=$1
    shift

    case "$verbosity" in
        summary)
            display_update_summary "$@"
            ;;
        verbose)
            display_update_verbose "$@"
            ;;
        *)
            display_update_compact "$@"
            ;;
    esac
}
```

**Step 5: Test interactive prompts**

```bash
# Create test environment
conda create -n test-smart-update python=3.11 numpy=1.23.0 -y
conda activate test-smart-update

# Test compact mode (default)
./smart_update.sh
# Interact with prompts: try 'a', 's', 'd', 'q'

# Test summary mode
./smart_update.sh --summary

# Test verbose mode
./smart_update.sh --verbose

# Test non-interactive
./smart_update.sh --yes
# Expected: Auto-approves all

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 6: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add interactive prompts with verbosity modes

- Implement compact display (default) with colored risk levels
- Add summary mode for minimal output
- Add verbose mode with detailed risk breakdown
- Implement user input handling (approve/skip/details/quit)
- Support non-interactive mode for testing"
```

---

## Task 9: Implement Update Execution with safe_install.sh Integration

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add safe_install.sh integration**

Add after prompt functions:

```bash
verify_safe_install_available() {
    local script_dir=$(dirname "$(readlink -f "$0")")
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

    if [[ "$use_safe_install" == true ]] && [[ -n "$SAFE_INSTALL_PATH" ]]; then
        # Use safe_install.sh for automatic rollback capability
        if [[ "$pkg_manager" == "conda" ]]; then
            "$SAFE_INSTALL_PATH" "${package}=${version}" --yes
        else
            "$SAFE_INSTALL_PATH" "${package}==${version}" --yes
        fi
    else
        # Direct installation without safe_install.sh
        if [[ "$pkg_manager" == "conda" ]]; then
            conda install -y "${package}=${version}"
        else
            pip install "${package}==${version}"
        fi
    fi

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "✅ Successfully installed $package $version"
        return 0
    else
        echo "❌ Failed to install $package $version"
        return 1
    fi
}
```

**Step 2: Add batch execution logic**

Add after execute_update:

```bash
execute_approved_updates() {
    local -n approved_refs=$1  # Name reference to array
    local use_safe_install=$2

    local total=${#approved_refs[@]}
    local succeeded=0
    local failed=0

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

            # Ask if user wants to continue after failure
            if [[ "$NON_INTERACTIVE" != true ]]; then
                echo ""
                read -p "Continue with remaining updates? [Y/n]: " -n 1 -r response
                echo ""
                if [[ "$response" =~ ^[Nn]$ ]]; then
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
    echo "  📊 Total: $total"
    echo "═══════════════════════════════════════════════"
}
```

**Step 3: Update main function to orchestrate everything**

Replace the `main` function with full implementation:

```bash
main() {
    parse_arguments "$@"
    detect_environment
    initialize_cache

    # Check for safe_install.sh
    local use_safe_install=true
    SAFE_INSTALL_PATH=$(verify_safe_install_available) || use_safe_install=false

    # Optional: Check for duplicates first
    if [[ "$CHECK_DUPLICATES" == true ]] && [[ -f "./find_duplicates.sh" ]]; then
        echo "🔍 Checking for conda/pip duplicates..."
        ./find_duplicates.sh
        echo ""
        read -p "Continue with updates? [Y/n]: " -n 1 -r response
        echo ""
        if [[ "$response" =~ ^[Nn]$ ]]; then
            exit 0
        fi
    fi

    # Collect available updates
    local updates=()

    if [[ "$PIP_ONLY" != true ]]; then
        while IFS='|' read -r pkg_manager package current latest; do
            [[ -n "$package" ]] && updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_conda_updates "$ENV_NAME")
    fi

    if [[ "$CONDA_ONLY" != true ]]; then
        while IFS='|' read -r pkg_manager package current latest; do
            [[ -n "$package" ]] && updates+=("$pkg_manager|$package|$current|$latest")
        done < <(get_pip_updates "$ENV_NAME")
    fi

    # Check if any updates available
    if [[ ${#updates[@]} -eq 0 ]]; then
        echo "✅ All packages are up to date!"
        exit 0
    fi

    echo "📊 Found ${#updates[@]} package(s) with updates available"
    echo ""

    # Process each update
    local approved_updates=()
    local skipped_updates=()

    for update in "${updates[@]}"; do
        IFS='|' read -r pkg_manager package current latest <<< "$update"

        # Assess risk
        local risk_assessment=$(assess_package_risk "$pkg_manager" "$package" "$current" "$latest" "$ENV_NAME")
        IFS='|' read -r risk version_change dep_count dep_packages release_type risk_factors <<< "$risk_assessment"

        # Build risk reason string
        local risk_reason=$(echo "$risk_factors" | sed 's/;/, /g')

        # Display update based on verbosity
        local current_verbosity="$VERBOSITY"

        while true; do
            if [[ "$current_verbosity" == "verbose" ]]; then
                display_update_verbose "$pkg_manager" "$package" "$current" "$latest" "$risk" \
                    "$version_change" "$dep_count" "$dep_packages" "$release_type" "$risk_factors"
            else
                display_update "$current_verbosity" "$pkg_manager" "$package" "$current" "$latest" "$risk" "$risk_reason"
            fi

            # Get user action
            local action=$(prompt_user_action "$package")

            case "$action" in
                approve)
                    approved_updates+=("$update")
                    break
                    ;;
                skip)
                    skipped_updates+=("$update")
                    break
                    ;;
                details)
                    # Toggle to verbose for this package
                    if [[ "$current_verbosity" != "verbose" ]]; then
                        current_verbosity="verbose"
                    else
                        current_verbosity="$VERBOSITY"
                    fi
                    ;;
                quit)
                    echo ""
                    echo "❌ Update process cancelled by user"
                    exit 0
                    ;;
            esac
        done
    done

    # Execute approved updates
    if [[ ${#approved_updates[@]} -gt 0 ]]; then
        execute_approved_updates approved_updates "$use_safe_install"
    else
        echo ""
        echo "No updates approved."
    fi

    # Optional: Run health check after updates
    if [[ "$HEALTH_CHECK_AFTER" == true ]] && [[ -f "./health_check.sh" ]]; then
        echo ""
        echo "🏥 Running health check..."
        ./health_check.sh --quick
    fi

    # Optional: Export environment after updates
    if [[ "$EXPORT_AFTER" == true ]] && [[ -f "./export_env.sh" ]]; then
        echo ""
        echo "💾 Exporting environment..."
        ./export_env.sh
    fi
}
```

**Step 4: Test full workflow**

```bash
# Create test environment
conda create -n test-smart-update python=3.11 numpy=1.23.0 -y
conda activate test-smart-update

# Test interactive workflow
./smart_update.sh
# Approve one package, skip another, try details, try quit

# Test with safe_install.sh integration
./smart_update.sh --verbose
# Approve update and verify it uses safe_install.sh

# Test batch execution
./smart_update.sh --yes
# Should auto-approve and execute all

# Verify updates applied
conda list | grep numpy

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 5: Commit**

```bash
git add smart_update.sh
git commit -m "feat: implement update execution with safe_install.sh

- Add safe_install.sh integration for automatic rollback
- Implement batch execution of approved updates
- Add success/failure tracking and reporting
- Support continuation after failures
- Integrate optional health check and export
- Complete interactive workflow with all features"
```

---

## Task 10: Add Error Handling and Edge Cases

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add internet connectivity check**

Add after initialize_cache:

```bash
check_internet_connectivity() {
    echo "🌐 Checking internet connectivity..."

    # Try to reach PyPI
    if ! curl -s -f -m 5 "https://pypi.org" > /dev/null 2>&1; then
        echo "⚠️  Warning: Cannot reach PyPI - security checks will be limited"
        return 1
    fi

    return 0
}
```

**Step 2: Add graceful degradation for missing dependencies**

Add early in main:

```bash
check_dependencies() {
    local missing_deps=()

    # Check for jq (optional but recommended)
    if ! command -v jq &> /dev/null; then
        echo "⚠️  Warning: jq not installed - JSON parsing will use fallback methods"
        echo "   Install jq for better reliability: conda install -c conda-forge jq"
    fi

    # Check for curl (required for PyPI API)
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ Missing required dependencies: ${missing_deps[*]}"
        echo "   Install with: conda install -c conda-forge ${missing_deps[*]}"
        exit 1
    fi
}
```

**Step 3: Add error handling for package conflicts**

Update `execute_update` with better error messages:

```bash
execute_update() {
    local pkg_manager=$1
    local package=$2
    local version=$3
    local use_safe_install=$4

    echo "🔄 Installing $package $version via $pkg_manager..."

    local install_output=""
    local exit_code=0

    if [[ "$use_safe_install" == true ]] && [[ -n "$SAFE_INSTALL_PATH" ]]; then
        if [[ "$pkg_manager" == "conda" ]]; then
            install_output=$("$SAFE_INSTALL_PATH" "${package}=${version}" --yes 2>&1) || exit_code=$?
        else
            install_output=$("$SAFE_INSTALL_PATH" "${package}==${version}" --yes 2>&1) || exit_code=$?
        fi
    else
        if [[ "$pkg_manager" == "conda" ]]; then
            install_output=$(conda install -y "${package}=${version}" 2>&1) || exit_code=$?
        else
            install_output=$(pip install "${package}==${version}" 2>&1) || exit_code=$?
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo "✅ Successfully installed $package $version"
        return 0
    else
        echo "❌ Failed to install $package $version"

        # Parse error for common issues
        if echo "$install_output" | grep -q "conflicts"; then
            echo "   Reason: Package conflict detected"
            echo "   Suggestion: Try updating conflicting packages first"
        elif echo "$install_output" | grep -q "not found"; then
            echo "   Reason: Package version not found"
            echo "   Suggestion: Check available versions with: conda search $package"
        else
            echo "   Error output:"
            echo "$install_output" | tail -n 5 | sed 's/^/   /'
        fi

        return 1
    fi
}
```

**Step 4: Add trap for cleanup on exit**

Add near the top of the script:

```bash
cleanup() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "❌ Script exited with error code $exit_code"

        if [[ -n "$SAFE_INSTALL_PATH" ]] && [[ -f "$SAFE_INSTALL_PATH" ]]; then
            echo "   You can rollback changes with: ./conda_rollback.sh"
        fi
    fi
}

trap cleanup EXIT
```

**Step 5: Update main to include checks**

Add to beginning of main function:

```bash
main() {
    parse_arguments "$@"

    # Dependency checks
    check_dependencies

    detect_environment
    initialize_cache

    # Internet connectivity check (warning only)
    check_internet_connectivity || true

    # ... rest of main function
}
```

**Step 6: Test error handling**

```bash
# Test missing jq (uninstall it temporarily if needed)
# conda remove jq -y
./smart_update.sh
# Expected: Warning about jq but continues

# Test without internet (disconnect or use airplane mode)
./smart_update.sh
# Expected: Warning about PyPI but continues

# Test with invalid package version
# (This would require modifying code temporarily to force an error)

# Test cancellation
conda create -n test-smart-update python=3.11 -y
conda activate test-smart-update
./smart_update.sh
# Press 'q' to quit
# Expected: Clean exit with message

# Cleanup
conda deactivate
conda remove -n test-smart-update --all -y
```

**Step 7: Commit**

```bash
git add smart_update.sh
git commit -m "feat: add comprehensive error handling

- Add internet connectivity checking with graceful degradation
- Implement dependency verification (curl required, jq optional)
- Enhance error messages for common failures
- Add cleanup trap for interrupted execution
- Parse install errors for actionable suggestions
- Maintain usability even when external services fail"
```

---

## Task 11: Update Documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md` (if exists, otherwise create it)

**Step 1: Update CLAUDE.md with smart_update.sh documentation**

Update the "#### 📦 Package Management" section in CLAUDE.md:

```bash
# Find the Package Management section and add the new entry
```

Add this entry after `safe_install.sh`:

```markdown
**smart_update.sh** - Intelligent package update assistant with risk-based decision making
- Analyzes available conda and pip package updates
- Calculates risk scores based on semver, dependency impacts, and security advisories
- Interactive approval workflow with configurable verbosity (--summary/default/--verbose)
- Integrates with safe_install.sh for automatic rollback capability
- PyPI security advisory checking with caching
- Supports both conda and pip packages
- Optional pre-check for duplicates and post-update health check
```

**Step 2: Add to Common Workflows section**

Add to the "Common Workflows" section:

```markdown
**Smart package updates:**
```bash
conda activate myenv
./smart_update.sh --verbose          # Review updates with full details
./smart_update.sh --check-duplicates # Check for conflicts first
./smart_update.sh --health-check-after --export-after  # Update, verify, backup
```

**Step 3: Create/update README.md**

If README doesn't exist, create it. Otherwise, add smart_update.sh to the features list:

```markdown
## Smart Update (`smart_update.sh`)

An intelligent package update assistant that takes the guesswork out of updating Python packages.

### Features

- **Risk-Based Assessment**: Automatically calculates update risk from semantic versioning, dependency impacts, and security advisories
- **Interactive Workflow**: Review each update with approve/skip/details/quit options
- **Configurable Verbosity**: Choose from summary, default, or verbose output modes
- **Safe Updates**: Integrates with `safe_install.sh` for automatic rollback capability
- **Security Awareness**: Checks PyPI for security advisories and bug fixes
- **Flexible Filtering**: Update only conda packages, only pip packages, or both
- **Health Integration**: Optional pre-check for duplicates and post-update health verification

### Quick Start

```bash
# Basic usage - interactive update review
conda activate myenv
./smart_update.sh

# Verbose mode for detailed risk breakdown
./smart_update.sh --verbose

# Check for package conflicts first
./smart_update.sh --check-duplicates

# Full workflow: check, update, verify, backup
./smart_update.sh --check-duplicates --health-check-after --export-after
```

### Risk Levels

- **LOW**: Patch version updates (1.2.3 → 1.2.4) with minimal dependencies affected
- **MEDIUM**: Minor version updates (1.2.x → 1.3.0) or patch updates affecting multiple packages
- **HIGH**: Major version updates (1.x → 2.0) or updates with significant dependency changes

Security fixes automatically lower risk level, while dependency conflicts increase it.

### Options

- `--verbose`: Show detailed risk breakdown for each package
- `--summary`: Minimal one-line output per package
- `--name ENV_NAME`: Target specific environment
- `--conda-only`: Only check conda packages
- `--pip-only`: Only check pip packages
- `--check-duplicates`: Run find_duplicates.sh before updating
- `--health-check-after`: Run health_check.sh after updates
- `--export-after`: Export environment after successful updates
- `--refresh`: Clear cache and refresh package data
```

**Step 4: Test documentation accuracy**

```bash
# Verify all examples work
conda create -n test-docs python=3.11 numpy=1.23.0 -y
conda activate test-docs

# Test each example from documentation
./smart_update.sh --verbose
./smart_update.sh --check-duplicates
./smart_update.sh --summary

# Verify help output matches documentation
./smart_update.sh --help

# Cleanup
conda deactivate
conda remove -n test-docs --all -y
```

**Step 5: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: add smart_update.sh documentation

- Add comprehensive description to CLAUDE.md
- Include in Package Management section
- Add to Common Workflows
- Create/update README with features, usage, and examples
- Document all command-line options
- Explain risk scoring system"
```

---

## Task 12: Final Testing and Polish

**Files:**
- Modify: `smart_update.sh`

**Step 1: Add final polish - colored output improvements**

Ensure consistent emoji and color usage throughout. Review all echo statements for:
- Consistent emoji usage (📦 for packages, ✅ for success, ❌ for errors, etc.)
- Proper color reset after colored text
- Readable spacing and separators

**Step 2: Add usage examples in help text**

Enhance the header comment in smart_update.sh:

```bash
# Examples:
#   ./smart_update.sh                           # Interactive review (default verbosity)
#   ./smart_update.sh --verbose                 # Detailed risk breakdown
#   ./smart_update.sh --summary --conda-only    # Quick scan of conda packages
#   ./smart_update.sh --check-duplicates \
#     --health-check-after --export-after       # Full workflow with verification
```

**Step 3: Comprehensive manual testing**

Create comprehensive test plan and execute:

```bash
# Test 1: Empty environment (no updates)
conda create -n test-empty python=3.11 -y
conda activate test-empty
./smart_update.sh
# Expected: "All packages are up to date!"
conda deactivate

# Test 2: Single package update
conda create -n test-single python=3.11 numpy=1.23.0 -y
conda activate test-single
./smart_update.sh --verbose
# Test approve, verify installation
conda deactivate

# Test 3: Multiple updates with different risks
conda create -n test-multi python=3.10 numpy=1.23.0 pandas=1.5.0 -y
conda activate test-multi
./smart_update.sh
# Test: approve one, skip one, details, quit
conda deactivate

# Test 4: Pip packages
conda create -n test-pip python=3.11 -y
conda activate test-pip
pip install requests==2.28.0 urllib3==1.26.0
./smart_update.sh --pip-only --verbose
conda deactivate

# Test 5: Mixed conda and pip
conda create -n test-mixed python=3.11 numpy=1.23.0 -y
conda activate test-mixed
pip install requests==2.28.0
./smart_update.sh
conda deactivate

# Test 6: Error scenarios
# - No active environment
conda deactivate
./smart_update.sh
# Expected: Error message

# - Invalid environment name
./smart_update.sh --name nonexistent-env
# Expected: Error message

# Test 7: Integration with other scripts
conda create -n test-integration python=3.11 numpy=1.23.0 -y
conda activate test-integration
./smart_update.sh --check-duplicates --health-check-after --export-after --verbose
# Verify all scripts run in sequence
conda deactivate

# Cleanup all test environments
conda remove -n test-empty --all -y
conda remove -n test-single --all -y
conda remove -n test-multi --all -y
conda remove -n test-pip --all -y
conda remove -n test-mixed --all -y
conda remove -n test-integration --all -y
```

**Step 4: Shellcheck linting**

```bash
# Install shellcheck if not available
# conda install -c conda-forge shellcheck

# Run shellcheck
shellcheck smart_update.sh

# Fix any issues reported
# Common fixes:
# - Quote variable expansions
# - Use [[ ]] instead of [ ]
# - Handle word splitting
```

**Step 5: Final commit**

```bash
git add smart_update.sh
git commit -m "polish: final improvements to smart_update.sh

- Enhance help text with more examples
- Ensure consistent emoji and color usage
- Fix shellcheck warnings
- Improve error messages and user feedback
- Verify all edge cases handled gracefully"
```

---

## Task 13: Merge to Main

**Files:**
- N/A (git operations)

**Step 1: Ensure all changes committed**

```bash
git status
# Expected: working tree clean
```

**Step 2: Switch to main and merge**

```bash
# Go back to main branch
cd /home/yannik/Work/tools  # Original repo location
git checkout main

# Merge feature branch
git merge --no-ff feature/smart-update -m "feat: add smart_update.sh - intelligent package update assistant

Complete implementation of smart_update.sh with:
- Risk-based update assessment (semver + dependencies + security)
- Interactive approval workflow with configurable verbosity
- Integration with safe_install.sh for rollback capability
- PyPI API integration for security advisories
- Comprehensive error handling and edge cases
- Full documentation in CLAUDE.md and README"
```

**Step 3: Test on main branch**

```bash
# Quick smoke test
conda create -n test-final python=3.11 numpy=1.23.0 -y
conda activate test-final
./smart_update.sh --verbose
conda deactivate
conda remove -n test-final --all -y
```

**Step 4: Clean up worktree**

```bash
# Remove the worktree
git worktree remove .worktrees/smart-update

# Delete the feature branch (optional)
git branch -d feature/smart-update
```

**Step 5: Final verification**

```bash
# Verify script is in main
ls -lh smart_update.sh

# Verify documentation updated
grep "smart_update.sh" CLAUDE.md

# Run tests one more time
./smart_update.sh --help
```

---

## Implementation Complete

This plan provides bite-sized tasks (2-5 minutes each) for implementing smart_update.sh. Each task includes:

- Exact file paths
- Complete code to add
- Verification steps
- Commit messages

The implementation follows:
- **TDD principles**: Test after each task
- **DRY**: Modular functions, no duplication
- **YAGNI**: Only features from the design document
- **Frequent commits**: After each completed task
- **Toolkit patterns**: Matches existing scripts' style and error handling

**Execution Options**: Use `superpowers:executing-plans` (separate session) or `superpowers:subagent-driven-development` (this session) to implement this plan.
