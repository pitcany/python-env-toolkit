#!/usr/bin/env bash
# ---------------------------------------------------------------------
# channel_manager.sh - Manage conda channel priorities and configurations
#
# Usage:
#   ./channel_manager.sh list [env_name]              # List channels
#   ./channel_manager.sh add <channel> [env_name]     # Add channel
#   ./channel_manager.sh remove <channel> [env_name]  # Remove channel
#   ./channel_manager.sh priority <channel> [env_name] # Set channel priority
#   ./channel_manager.sh reset [env_name]             # Reset to defaults
#   ./channel_manager.sh detect-conflicts [env_name]  # Check for conflicts
#
# Features:
#   - List configured channels per environment
#   - Add/remove/prioritize channels
#   - Reset to defaults channel configuration
#   - Detect channel conflicts
#   - Suggest optimal channel order
# ---------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to show help
show_help() {
    sed -n '2,14p' "$0" | sed 's/^# //' | sed 's/^#//'
}

# Verify environment exists
verify_environment() {
    local env_name=$1

    if [[ -z "$env_name" ]]; then
        return 0
    fi

    if [[ "$env_name" == "base" ]]; then
        return 0
    fi

    if ! conda env list | grep -q "^${env_name} "; then
        print_error "Environment '$env_name' not found"
        echo ""
        echo "Available environments:"
        conda env list | grep -v "^#" | awk '{print "  - " $1}'
        exit 1
    fi
}

# List channels
list_channels() {
    local env_name=${1:-}
    local scope="global"

    if [[ -n "$env_name" ]]; then
        scope="environment: $env_name"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 Conda Channels ($scope)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local channels
    if [[ -n "$env_name" ]]; then
        # Get environment-specific channels
        channels=$(conda config --env --show channels 2>/dev/null || echo "")
    else
        # Get global channels
        channels=$(conda config --show channels 2>/dev/null || echo "")
    fi

    if [[ -z "$channels" ]]; then
        print_info "No custom channels configured (using defaults)"
        echo ""
        print_info "Default channels:"
        echo "  1. defaults"
        echo ""
        return
    fi

    # Parse and display channels with priority
    local priority=1
    echo -e "${CYAN}Priority  Channel${NC}"
    echo "─────────────────────────────────────────"

    echo "$channels" | grep -A 100 "channels:" | grep "^  -" | while read -r line; do
        channel=$(echo "$line" | sed 's/^  - //')
        printf "${GREEN}%8d${NC}  %s\n" "$priority" "$channel"
        ((priority++))
    done

    echo ""

    # Show channel priority setting
    local priority_setting
    priority_setting=$(conda config --show channel_priority 2>/dev/null | grep "channel_priority:" | awk '{print $2}')

    if [[ -n "$priority_setting" ]]; then
        echo "Channel Priority Mode: ${YELLOW}${priority_setting}${NC}"
        echo ""

        case "$priority_setting" in
            strict)
                print_info "Strict mode: Only packages from highest priority channel are considered"
                ;;
            flexible)
                print_info "Flexible mode: Highest version across all channels preferred"
                ;;
            disabled)
                print_warning "Disabled: No priority enforcement (not recommended)"
                ;;
        esac
        echo ""
    fi
}

# Add channel
add_channel() {
    local channel=$1
    local env_name=${2:-}
    local env_flag=""

    if [[ -z "$channel" ]]; then
        print_error "Channel name required"
        exit 1
    fi

    if [[ -n "$env_name" ]]; then
        env_flag="--env"
        verify_environment "$env_name"
        print_info "Adding channel '$channel' to environment: $env_name"
    else
        print_info "Adding channel '$channel' globally"
    fi

    if conda config $env_flag --add channels "$channel" 2>/dev/null; then
        print_success "Channel '$channel' added successfully"
        echo ""
        list_channels "$env_name"
    else
        print_error "Failed to add channel '$channel'"
        exit 1
    fi
}

# Remove channel
remove_channel() {
    local channel=$1
    local env_name=${2:-}
    local env_flag=""

    if [[ -z "$channel" ]]; then
        print_error "Channel name required"
        exit 1
    fi

    if [[ -n "$env_name" ]]; then
        env_flag="--env"
        verify_environment "$env_name"
        print_info "Removing channel '$channel' from environment: $env_name"
    else
        print_info "Removing channel '$channel' globally"
    fi

    if conda config $env_flag --remove channels "$channel" 2>/dev/null; then
        print_success "Channel '$channel' removed successfully"
        echo ""
        list_channels "$env_name"
    else
        print_error "Failed to remove channel '$channel' (may not be configured)"
        exit 1
    fi
}

# Set channel priority
set_priority() {
    local channel=$1
    local env_name=${2:-}
    local env_flag=""

    if [[ -z "$channel" ]]; then
        print_error "Channel name required"
        exit 1
    fi

    if [[ -n "$env_name" ]]; then
        env_flag="--env"
        verify_environment "$env_name"
        print_info "Setting '$channel' as highest priority in environment: $env_name"
    else
        print_info "Setting '$channel' as highest priority globally"
    fi

    # Remove and re-add at top (prepend)
    conda config $env_flag --remove channels "$channel" 2>/dev/null || true
    if conda config $env_flag --prepend channels "$channel" 2>/dev/null; then
        print_success "Channel '$channel' set as highest priority"
        echo ""
        list_channels "$env_name"
    else
        print_error "Failed to set priority for channel '$channel'"
        exit 1
    fi
}

# Reset channels to defaults
reset_channels() {
    local env_name=${1:-}
    local env_flag=""
    local scope="global"

    if [[ -n "$env_name" ]]; then
        env_flag="--env"
        scope="environment: $env_name"
        verify_environment "$env_name"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_warning "Reset channels to defaults ($scope)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -rp "This will remove all custom channels. Continue? [y/N] " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        print_info "Cancelled"
        exit 0
    fi

    # Get current channels
    local channels
    if [[ -n "$env_flag" ]]; then
        channels=$(conda config $env_flag --show channels 2>/dev/null | grep "^  -" | sed 's/^  - //' || echo "")
    else
        channels=$(conda config --show channels 2>/dev/null | grep "^  -" | sed 's/^  - //' || echo "")
    fi

    # Remove each channel
    if [[ -n "$channels" ]]; then
        while IFS= read -r channel; do
            [[ -z "$channel" ]] && continue
            conda config $env_flag --remove channels "$channel" 2>/dev/null || true
        done <<< "$channels"
    fi

    # Set to defaults
    conda config $env_flag --add channels defaults 2>/dev/null || true

    print_success "Channels reset to defaults"
    echo ""
    list_channels "$env_name"
}

# Detect channel conflicts
detect_conflicts() {
    local env_name=${1:-}

    if [[ -z "$env_name" ]]; then
        if [[ -z "${CONDA_DEFAULT_ENV:-}" || "${CONDA_DEFAULT_ENV}" == "base" ]]; then
            print_error "No environment specified and no active environment"
            echo "Usage: $0 detect-conflicts <env_name>"
            exit 1
        fi
        env_name="${CONDA_DEFAULT_ENV}"
    fi

    verify_environment "$env_name"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 Detecting Channel Conflicts"
    echo "Environment: $env_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_info "Analyzing installed packages..."

    # Get packages with their channels
    local packages_with_channels
    packages_with_channels=$(conda list -n "$env_name" 2>/dev/null | \
        awk 'NR>3 && $4 != "" {print $1 "|" $4}' | \
        grep -v "^#" || echo "")

    if [[ -z "$packages_with_channels" ]]; then
        print_info "No package channel information available"
        exit 0
    fi

    # Extract unique channels
    local channels_used
    channels_used=$(echo "$packages_with_channels" | cut -d'|' -f2 | sort -u)

    echo "Channels in use:"
    echo "$channels_used" | sed 's/^/  - /'
    echo ""

    # Check for common conflict patterns
    local has_conflicts=false

    # Check for conda-forge + defaults mix
    if echo "$channels_used" | grep -q "conda-forge" && echo "$channels_used" | grep -q "defaults"; then
        print_warning "Mixed conda-forge and defaults packages detected"
        echo ""
        echo "  This can cause dependency conflicts. Recommended actions:"
        echo "  1. Use conda-forge exclusively: ./channel_manager.sh reset $env_name && ./channel_manager.sh add conda-forge $env_name"
        echo "  2. Or use defaults only: ./channel_manager.sh reset $env_name"
        echo ""
        has_conflicts=true
    fi

    # Check for packages from multiple channels
    declare -A package_channels

    while IFS='|' read -r pkg channel; do
        [[ -z "$pkg" ]] && continue
        package_channels["$pkg"]="${package_channels[$pkg]:-}|$channel"
    done <<< "$packages_with_channels"

    # Find packages from multiple sources
    echo "Packages installed from multiple channels:"
    local multi_channel_found=false

    for pkg in "${!package_channels[@]}"; do
        local channels="${package_channels[$pkg]}"
        local channel_count=$(echo "$channels" | tr '|' '\n' | grep -v "^$" | sort -u | wc -l)

        if [[ $channel_count -gt 1 ]]; then
            echo "  - $pkg: ${channels//|/ , }"
            multi_channel_found=true
            has_conflicts=true
        fi
    done

    if [[ "$multi_channel_found" == false ]]; then
        echo "  (none)"
    fi
    echo ""

    # Recommendations
    if [[ "$has_conflicts" == true ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "💡 Recommendations"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "1. Set channel priority to 'strict':"
        echo "   conda config --set channel_priority strict"
        echo ""
        echo "2. Consider using a single primary channel (conda-forge recommended):"
        echo "   ./channel_manager.sh reset $env_name"
        echo "   ./channel_manager.sh add conda-forge $env_name"
        echo ""
        echo "3. Recreate environment with consistent channel:"
        echo "   ./export_env.sh --name $env_name"
        echo "   # Edit environment.yml to specify channel"
        echo "   # Then recreate environment"
        echo ""
    else
        print_success "No channel conflicts detected"
    fi
}

# Main command dispatcher
if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

COMMAND=$1
shift

case "$COMMAND" in
    list|ls)
        list_channels "$@"
        ;;
    add)
        if [[ $# -lt 1 ]]; then
            print_error "Usage: $0 add <channel> [env_name]"
            exit 1
        fi
        add_channel "$@"
        ;;
    remove|rm)
        if [[ $# -lt 1 ]]; then
            print_error "Usage: $0 remove <channel> [env_name]"
            exit 1
        fi
        remove_channel "$@"
        ;;
    priority|prioritize)
        if [[ $# -lt 1 ]]; then
            print_error "Usage: $0 priority <channel> [env_name]"
            exit 1
        fi
        set_priority "$@"
        ;;
    reset)
        reset_channels "$@"
        ;;
    detect-conflicts|conflicts)
        detect_conflicts "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
