#!/usr/bin/env bash
# Common library functions for Python Environment Toolkit
# Source this file in scripts: source "$(dirname "$0")/lib/common.sh"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Detect operating system
detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)   echo "linux" ;;
        *)        echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# Cross-platform sed in-place editing
# Usage: sed_inplace "pattern" "file"
sed_inplace() {
    local pattern=$1
    local file=$2

    if [[ "$OS_TYPE" == "macos" ]]; then
        # BSD sed requires the appended text for a\ commands on separate lines.
        # Detect simple append commands and rewrite them into the BSD-friendly form.
        if [[ "$pattern" == /* && "$pattern" == */a\\* ]]; then
            local before_append=${pattern%%a\\*}
            local append_payload=${pattern#*a\\}
            # Convert escaped \n sequences into real newlines for multi-line appends.
            append_payload=${append_payload//\\n/$'\n'}

            local append_lines=()
            while IFS= read -r line; do
                append_lines+=("$line")
            done <<<"$append_payload"

            if [[ "$append_payload" == *$'\n' ]]; then
                if [[ ${#append_lines[@]} -gt 0 ]]; then
                    local last_index=$(( ${#append_lines[@]} - 1 ))
                    if [[ "${append_lines[$last_index]}" != "" ]]; then
                        append_lines+=("")
                    fi
                else
                    append_lines+=("")
                fi
            fi

            # Ensure at least one line is provided to sed even if payload was empty.
            if [[ ${#append_lines[@]} -eq 0 ]]; then
                append_lines+=("")
            fi

            # BSD sed syntax: sed -i '' -e '/addr/a\' -e 'line1' -e 'line2'
            local sed_args=("sed" "-i" "" "-e" "${before_append}a\\")
            for line in "${append_lines[@]}"; do
                sed_args+=("-e" "$line")
            done
            sed_args+=("$file")
            "${sed_args[@]}"
            return
        fi

        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

# Load version info
if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    source "$SCRIPT_DIR/VERSION"
else
    TOOLKIT_VERSION="unknown"
    TOOLKIT_DATE="unknown"
    TOOLKIT_COMMIT="unknown"
    TOOLKIT_NAME="Python Environment Toolkit"
fi

# Display version information
show_version() {
    cat << EOF
${TOOLKIT_NAME} v${TOOLKIT_VERSION}
Released: ${TOOLKIT_DATE}
Commit: ${TOOLKIT_COMMIT}
Platform: ${OS_TYPE}
EOF
}

# Enhanced error messages with suggestions
error_env_not_found() {
    local env_name=$1

    print_error "Environment '${env_name}' not found"
    echo ""

    # Try fuzzy matching
    local suggestions
    suggestions=$(conda env list 2>/dev/null | awk 'NR>3 && $1 !~ /^#/ {print $1}' | grep -i "${env_name:0:3}" | head -3)

    if [[ -n "$suggestions" ]]; then
        echo "💡 Did you mean one of these?"
        echo "$suggestions" | sed 's/^/  - /'
        echo ""
    fi

    echo "📋 Available environments:"
    conda env list 2>/dev/null | awk 'NR>3 && $1 !~ /^#/ {print "  - " $1}' | head -10
    echo ""
    echo "📚 To create a new environment:"
    echo "  ./create_ml_env.sh ${env_name} --template pytorch-gpu"
}

# Enhanced error for missing commands
error_command_not_found() {
    local cmd=$1
    local package=${2:-$cmd}

    print_error "Required command '${cmd}' not found"
    echo ""
    echo "📦 Installation instructions:"

    case "$cmd" in
        conda|mamba)
            echo "  Download from: https://docs.conda.io/en/latest/miniconda.html"
            ;;
        jq)
            echo "  Ubuntu/Debian: sudo apt-get install jq"
            echo "  macOS: brew install jq"
            echo "  Or: https://stedolan.github.io/jq/download/"
            ;;
        shellcheck)
            echo "  Ubuntu/Debian: sudo apt-get install shellcheck"
            echo "  macOS: brew install shellcheck"
            echo "  Or: https://github.com/koalaman/shellcheck#installing"
            ;;
        *)
            echo "  Package: ${package}"
            echo "  Check your system's package manager"
            ;;
    esac
    echo ""
}

# Enhanced error for invalid flags
error_invalid_flag() {
    local flag=$1
    local script_name=$2

    print_error "Unknown option: ${flag}"
    echo ""
    echo "💡 Run for help: ${script_name} --help"
    echo ""
}

# Check if conda environment exists
validate_conda_env() {
    local env_name=$1

    if [[ -z "$env_name" ]]; then
        return 0
    fi

    if [[ "$env_name" == "base" ]]; then
        return 0
    fi

    if conda env list 2>/dev/null | awk 'NR>3 {print $1}' | grep -q "^${env_name}$"; then
        return 0
    else
        error_env_not_found "$env_name"
        return 1
    fi
}

# Check for required dependencies
check_required_dependency() {
    local cmd=$1
    local package=${2:-$cmd}

    if ! command -v "$cmd" &>/dev/null; then
        error_command_not_found "$cmd" "$package"
        return 1
    fi
    return 0
}

# Check for optional dependencies
check_optional_dependency() {
    local cmd=$1
    local feature=$2

    if ! command -v "$cmd" &>/dev/null; then
        print_warning "${cmd} not found: ${feature} will be unavailable"
        return 1
    fi
    return 0
}

# Fuzzy match for typos
suggest_similar_command() {
    local input=$1
    shift
    local valid_commands=("$@")

    for cmd in "${valid_commands[@]}"; do
        # Simple fuzzy match: check if first 3 chars match
        if [[ "${cmd:0:3}" == "${input:0:3}" ]]; then
            echo "💡 Did you mean: ${cmd}?"
            return 0
        fi
    done

    return 1
}

# Safe exit with cleanup
safe_exit() {
    local exit_code=${1:-0}
    local message=${2:-""}

    if [[ -n "$message" ]]; then
        if [[ $exit_code -eq 0 ]]; then
            print_success "$message"
        else
            print_error "$message"
        fi
    fi

    exit "$exit_code"
}

# Check if running in CI environment
is_ci() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]
}

# Check if output supports colors
supports_color() {
    [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && ! is_ci
}
