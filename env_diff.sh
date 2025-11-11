#!/usr/bin/env bash
# ---------------------------------------------------------------------
# env_diff.sh - Compare two conda environments and show differences
#
# Usage:
#   ./env_diff.sh env1 env2              # Compare two environments
#   ./env_diff.sh env1 env2 --detailed   # Show detailed version info
#   ./env_diff.sh env1 env2 --export     # Export diff to file
#   ./env_diff.sh env1 env2 --sync       # Show sync commands
#
# Features:
#   - Compare package versions between environments
#   - Show packages unique to each environment
#   - Highlight version mismatches
#   - Generate actionable sync commands
#   - Support for both conda and pip packages
# ---------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
DETAILED=false
EXPORT_DIFF=false
SHOW_SYNC=false
EXPORT_FILE=""

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
    sed -n '2,13p' "$0" | sed 's/^# //' | sed 's/^#//'
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <env1> <env2> [--detailed] [--export <file>] [--sync]"
    echo ""
    show_help
    exit 1
fi

ENV1="$1"
ENV2="$2"
shift 2

# Parse optional flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --detailed|-d)
            DETAILED=true
            shift
            ;;
        --export|-e)
            EXPORT_DIFF=true
            if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                EXPORT_FILE="$2"
                shift
            else
                EXPORT_FILE="env_diff_${ENV1}_${ENV2}.txt"
            fi
            shift
            ;;
        --sync|-s)
            SHOW_SYNC=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Verify environments exist
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Environment Comparison Tool"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Validating environments..."

if ! conda env list | grep -q "^${ENV1} "; then
    print_error "Environment '$ENV1' not found"
    echo ""
    echo "Available environments:"
    conda env list | grep -v "^#" | awk '{print "  - " $1}'
    exit 1
fi

if ! conda env list | grep -q "^${ENV2} "; then
    print_error "Environment '$ENV2' not found"
    echo ""
    echo "Available environments:"
    conda env list | grep -v "^#" | awk '{print "  - " $1}'
    exit 1
fi

print_success "Both environments found"
echo ""

# Function to get conda packages for an environment
get_conda_packages() {
    local env_name=$1
    conda list -n "$env_name" --no-pip 2>/dev/null | \
        awk 'NR>3 && $1 !~ /^#/ {print $1 "|" $2}' | \
        sort
}

# Function to get pip packages for an environment
get_pip_packages() {
    local env_name=$1
    conda run -n "$env_name" pip list --format=freeze 2>/dev/null | \
        grep -v "^-e " | \
        sed 's/==/ /' | \
        awk '{print $1 "|" $2}' | \
        sort || echo ""
}

# Get package lists
print_info "Scanning conda packages..."
env1_conda=$(get_conda_packages "$ENV1")
env2_conda=$(get_conda_packages "$ENV2")

print_info "Scanning pip packages..."
env1_pip=$(get_pip_packages "$ENV1")
env2_pip=$(get_pip_packages "$ENV2")

echo ""

# Temporary files for comparison
TMP1=$(mktemp)
TMP2=$(mktemp)
trap 'rm -f "$TMP1" "$TMP2"' EXIT

# Analyze conda packages
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Conda Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract package names
echo "$env1_conda" | cut -d'|' -f1 | sort -u > "$TMP1"
echo "$env2_conda" | cut -d'|' -f1 | sort -u > "$TMP2"

# Packages only in ENV1
only_in_env1=$(comm -23 "$TMP1" "$TMP2")
only_in_env1_count=$(echo "$only_in_env1" | grep -c . || echo "0")

# Packages only in ENV2
only_in_env2=$(comm -13 "$TMP1" "$TMP2")
only_in_env2_count=$(echo "$only_in_env2" | grep -c . || echo "0")

# Common packages (for version comparison)
common_packages=$(comm -12 "$TMP1" "$TMP2")

# Version mismatches
version_mismatches=()
mismatch_count=0

while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue

    version1=$(echo "$env1_conda" | grep "^${pkg}|" | cut -d'|' -f2)
    version2=$(echo "$env2_conda" | grep "^${pkg}|" | cut -d'|' -f2)

    if [[ "$version1" != "$version2" ]]; then
        version_mismatches+=("${pkg}|${version1}|${version2}")
        ((mismatch_count++))
    fi
done <<< "$common_packages"

# Display results
if [[ $only_in_env1_count -gt 0 ]]; then
    echo -e "${BLUE}📋 Packages only in ${ENV1}:${NC} (${only_in_env1_count})"
    echo "$only_in_env1" | head -10 | sed 's/^/  - /'
    if [[ $only_in_env1_count -gt 10 ]]; then
        echo "  ... and $((only_in_env1_count - 10)) more"
    fi
    echo ""
fi

if [[ $only_in_env2_count -gt 0 ]]; then
    echo -e "${BLUE}📋 Packages only in ${ENV2}:${NC} (${only_in_env2_count})"
    echo "$only_in_env2" | head -10 | sed 's/^/  - /'
    if [[ $only_in_env2_count -gt 10 ]]; then
        echo "  ... and $((only_in_env2_count - 10)) more"
    fi
    echo ""
fi

if [[ $mismatch_count -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Version Mismatches:${NC} (${mismatch_count})"

    for mismatch in "${version_mismatches[@]}"; do
        pkg=$(echo "$mismatch" | cut -d'|' -f1)
        v1=$(echo "$mismatch" | cut -d'|' -f2)
        v2=$(echo "$mismatch" | cut -d'|' -f3)

        if [[ "$DETAILED" == true ]]; then
            echo -e "  ${pkg}: ${ENV1}=${GREEN}${v1}${NC} → ${ENV2}=${YELLOW}${v2}${NC}"
        else
            echo "  - ${pkg}: ${v1} → ${v2}"
        fi
    done | head -20

    if [[ $mismatch_count -gt 20 ]]; then
        echo "  ... and $((mismatch_count - 20)) more"
    fi
    echo ""
else
    print_success "All common conda packages have matching versions"
    echo ""
fi

# Analyze pip packages
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐍 Pip Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -z "$env1_pip" && -z "$env2_pip" ]]; then
    print_info "No pip packages in either environment"
    echo ""
else
    # Extract package names for pip
    echo "$env1_pip" | cut -d'|' -f1 | sort -u > "$TMP1"
    echo "$env2_pip" | cut -d'|' -f1 | sort -u > "$TMP2"

    # Packages only in ENV1
    pip_only_in_env1=$(comm -23 "$TMP1" "$TMP2")
    pip_only_in_env1_count=$(echo "$pip_only_in_env1" | grep -c . || echo "0")

    # Packages only in ENV2
    pip_only_in_env2=$(comm -13 "$TMP1" "$TMP2")
    pip_only_in_env2_count=$(echo "$pip_only_in_env2" | grep -c . || echo "0")

    # Common pip packages
    pip_common=$(comm -12 "$TMP1" "$TMP2")

    # Pip version mismatches
    pip_mismatches=()
    pip_mismatch_count=0

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue

        version1=$(echo "$env1_pip" | grep "^${pkg}|" | cut -d'|' -f2)
        version2=$(echo "$env2_pip" | grep "^${pkg}|" | cut -d'|' -f2)

        if [[ "$version1" != "$version2" ]]; then
            pip_mismatches+=("${pkg}|${version1}|${version2}")
            ((pip_mismatch_count++))
        fi
    done <<< "$pip_common"

    # Display pip results
    if [[ $pip_only_in_env1_count -gt 0 ]]; then
        echo -e "${BLUE}📋 Pip packages only in ${ENV1}:${NC} (${pip_only_in_env1_count})"
        echo "$pip_only_in_env1" | head -10 | sed 's/^/  - /'
        if [[ $pip_only_in_env1_count -gt 10 ]]; then
            echo "  ... and $((pip_only_in_env1_count - 10)) more"
        fi
        echo ""
    fi

    if [[ $pip_only_in_env2_count -gt 0 ]]; then
        echo -e "${BLUE}📋 Pip packages only in ${ENV2}:${NC} (${pip_only_in_env2_count})"
        echo "$pip_only_in_env2" | head -10 | sed 's/^/  - /'
        if [[ $pip_only_in_env2_count -gt 10 ]]; then
            echo "  ... and $((pip_only_in_env2_count - 10)) more"
        fi
        echo ""
    fi

    if [[ $pip_mismatch_count -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Pip Version Mismatches:${NC} (${pip_mismatch_count})"

        for mismatch in "${pip_mismatches[@]}"; do
            pkg=$(echo "$mismatch" | cut -d'|' -f1)
            v1=$(echo "$mismatch" | cut -d'|' -f2)
            v2=$(echo "$mismatch" | cut -d'|' -f3)

            if [[ "$DETAILED" == true ]]; then
                echo -e "  ${pkg}: ${ENV1}=${GREEN}${v1}${NC} → ${ENV2}=${YELLOW}${v2}${NC}"
            else
                echo "  - ${pkg}: ${v1} → ${v2}"
            fi
        done | head -20

        if [[ $pip_mismatch_count -gt 20 ]]; then
            echo "  ... and $((pip_mismatch_count - 20)) more"
        fi
        echo ""
    else
        if [[ $pip_only_in_env1_count -eq 0 && $pip_only_in_env2_count -eq 0 ]]; then
            print_success "All pip packages match"
            echo ""
        fi
    fi
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Conda Packages:"
echo "  - Common: $(echo "$common_packages" | grep -c . || echo "0")"
echo "  - Only in $ENV1: $only_in_env1_count"
echo "  - Only in $ENV2: $only_in_env2_count"
echo "  - Version mismatches: $mismatch_count"
echo ""
echo "Pip Packages:"
echo "  - Common: $(echo "$pip_common" | grep -c . || echo "0")"
echo "  - Only in $ENV1: $pip_only_in_env1_count"
echo "  - Only in $ENV2: $pip_only_in_env2_count"
echo "  - Version mismatches: $pip_mismatch_count"
echo ""

total_differences=$((only_in_env1_count + only_in_env2_count + mismatch_count + pip_only_in_env1_count + pip_only_in_env2_count + pip_mismatch_count))

if [[ $total_differences -eq 0 ]]; then
    print_success "Environments are identical!"
else
    print_warning "Found $total_differences differences between environments"
fi

echo ""

# Generate sync commands if requested
if [[ "$SHOW_SYNC" == true && $total_differences -gt 0 ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Sync Commands (${ENV1} → ${ENV2})"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ $only_in_env1_count -gt 0 ]]; then
        echo "# Install packages from ${ENV1} into ${ENV2}:"
        echo "conda activate ${ENV2}"
        echo "$only_in_env1" | while read -r pkg; do
            [[ -z "$pkg" ]] && continue
            version=$(echo "$env1_conda" | grep "^${pkg}|" | cut -d'|' -f2)
            echo "conda install -y ${pkg}=${version}"
        done | head -10
        if [[ $only_in_env1_count -gt 10 ]]; then
            echo "# ... and $((only_in_env1_count - 10)) more packages"
        fi
        echo ""
    fi

    if [[ $mismatch_count -gt 0 ]]; then
        echo "# Update mismatched versions in ${ENV2}:"
        echo "conda activate ${ENV2}"
        for mismatch in "${version_mismatches[@]}"; do
            pkg=$(echo "$mismatch" | cut -d'|' -f1)
            v1=$(echo "$mismatch" | cut -d'|' -f2)
            echo "conda install -y ${pkg}=${v1}"
        done | head -10
        if [[ $mismatch_count -gt 10 ]]; then
            echo "# ... and $((mismatch_count - 10)) more packages"
        fi
        echo ""
    fi

    if [[ $pip_only_in_env1_count -gt 0 || $pip_mismatch_count -gt 0 ]]; then
        echo "# Sync pip packages:"
        echo "conda activate ${ENV2}"
        if [[ $pip_only_in_env1_count -gt 0 ]]; then
            echo "$pip_only_in_env1" | while read -r pkg; do
                [[ -z "$pkg" ]] && continue
                version=$(echo "$env1_pip" | grep "^${pkg}|" | cut -d'|' -f2)
                echo "pip install ${pkg}==${version}"
            done | head -5
        fi
        if [[ $pip_mismatch_count -gt 0 ]]; then
            for mismatch in "${pip_mismatches[@]}"; do
                pkg=$(echo "$mismatch" | cut -d'|' -f1)
                v1=$(echo "$mismatch" | cut -d'|' -f2)
                echo "pip install ${pkg}==${v1}"
            done | head -5
        fi
        echo ""
    fi
fi

# Export diff if requested
if [[ "$EXPORT_DIFF" == true ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Exporting diff to ${EXPORT_FILE}..."

    {
        echo "Environment Comparison: ${ENV1} vs ${ENV2}"
        echo "Generated: $(date)"
        echo ""
        echo "=== CONDA PACKAGES ==="
        echo ""
        if [[ $only_in_env1_count -gt 0 ]]; then
            echo "Only in ${ENV1}:"
            echo "$only_in_env1"
            echo ""
        fi
        if [[ $only_in_env2_count -gt 0 ]]; then
            echo "Only in ${ENV2}:"
            echo "$only_in_env2"
            echo ""
        fi
        if [[ $mismatch_count -gt 0 ]]; then
            echo "Version Mismatches:"
            for mismatch in "${version_mismatches[@]}"; do
                pkg=$(echo "$mismatch" | cut -d'|' -f1)
                v1=$(echo "$mismatch" | cut -d'|' -f2)
                v2=$(echo "$mismatch" | cut -d'|' -f3)
                echo "${pkg}: ${v1} → ${v2}"
            done
            echo ""
        fi

        echo "=== PIP PACKAGES ==="
        echo ""
        if [[ $pip_only_in_env1_count -gt 0 ]]; then
            echo "Only in ${ENV1}:"
            echo "$pip_only_in_env1"
            echo ""
        fi
        if [[ $pip_only_in_env2_count -gt 0 ]]; then
            echo "Only in ${ENV2}:"
            echo "$pip_only_in_env2"
            echo ""
        fi
        if [[ $pip_mismatch_count -gt 0 ]]; then
            echo "Version Mismatches:"
            for mismatch in "${pip_mismatches[@]}"; do
                pkg=$(echo "$mismatch" | cut -d'|' -f1)
                v1=$(echo "$mismatch" | cut -d'|' -f2)
                v2=$(echo "$mismatch" | cut -d'|' -f3)
                echo "${pkg}: ${v1} → ${v2}"
            done
            echo ""
        fi
    } > "$EXPORT_FILE"

    print_success "Diff exported to ${EXPORT_FILE}"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
