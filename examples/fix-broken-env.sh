#!/usr/bin/env bash

# fix-broken-env.sh - Diagnostic and repair workflow for broken environments
#
# This example demonstrates how to diagnose and fix common environment issues:
# 1. Run comprehensive health check to identify problems
# 2. Detect and fix conda/pip conflicts
# 3. Offer rollback options if issues persist
# 4. Provide cleanup and rebuild options for severe cases
# 5. Re-verify health after fixes
#
# Usage:
#   cd /path/to/python-env-toolkit
#   conda activate <broken-env>
#   ./examples/fix-broken-env.sh
#
#   Or specify environment:
#   ./examples/fix-broken-env.sh <env-name>

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory (parent of examples/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${MAGENTA}▶ Step $1: $2${NC}"
    echo ""
}

print_info() {
    echo -e "${CYAN}  ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}  ✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}  ❌ $1${NC}"
}

# Check if we're in the right directory
if [[ ! -f "$SCRIPT_DIR/health_check.sh" ]]; then
    echo -e "${RED}Error: Cannot find toolkit scripts${NC}"
    echo "Please run this from the python-env-toolkit directory or its examples/ subdirectory"
    exit 1
fi

# Determine environment
TARGET_ENV="$1"
if [[ -z "$TARGET_ENV" ]]; then
    if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "${CONDA_DEFAULT_ENV}" == "base" ]]; then
        echo -e "${RED}Error: No environment specified and no environment is active${NC}"
        echo "Usage: $0 <env-name>"
        echo "   Or: conda activate <env-name> && $0"
        exit 1
    fi
    TARGET_ENV="${CONDA_DEFAULT_ENV}"
fi

# Verify environment exists
if ! conda env list | grep -q "^${TARGET_ENV} "; then
    echo -e "${RED}Error: Environment '${TARGET_ENV}' not found${NC}"
    exit 1
fi

print_header "Environment Repair Workflow"

echo -e "${CYAN}Diagnosing environment: ${YELLOW}${TARGET_ENV}${NC}"
echo ""

# Step 1: Initial health check
print_step "1" "Health Check - Initial Diagnosis"

echo -e "${CYAN}Running comprehensive health check...${NC}"
echo ""

# Run health check and capture exit code
HEALTH_EXIT=0
"$SCRIPT_DIR/health_check.sh" "$TARGET_ENV" || HEALTH_EXIT=$?

echo ""

if [[ $HEALTH_EXIT -eq 0 ]]; then
    print_success "Environment appears healthy!"
    echo ""
    echo -e "${CYAN}If you're still experiencing issues, they may be:${NC}"
    echo "  - Application-specific bugs"
    echo "  - Data/file-related issues"
    echo "  - Network/connectivity problems"
    echo ""
    read -p "Continue with diagnostic checks anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting."
        exit 0
    fi
else
    print_warning "Health check found issues. Let's investigate and fix them."
fi

# Step 2: Check for conda/pip conflicts
print_step "2" "Checking for Package Conflicts"

echo -e "${CYAN}Scanning for packages installed via both conda and pip...${NC}"
echo ""

DUPLICATES_FOUND=0
"$SCRIPT_DIR/find_duplicates.sh" "$TARGET_ENV" 2>&1 | tee /tmp/duplicates_output.txt || DUPLICATES_FOUND=$?

if grep -q "Found.*package" /tmp/duplicates_output.txt 2>/dev/null; then
    echo ""
    print_warning "Conflicts detected!"
    echo ""
    read -p "Fix conflicts by removing pip duplicates? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        "$SCRIPT_DIR/find_duplicates.sh" "$TARGET_ENV" --fix --yes
        print_success "Conflicts resolved!"
    else
        print_info "Skipping conflict resolution"
    fi
else
    print_success "No conda/pip conflicts found"
fi

rm -f /tmp/duplicates_output.txt

# Step 3: Check conda revision history
print_step "3" "Checking Environment History"

echo -e "${CYAN}Examining conda revision history...${NC}"
echo ""

# Get revision count
REVISION_COUNT=$(conda list --revisions -n "$TARGET_ENV" 2>/dev/null | grep -c "^rev" || echo "0")

if [[ $REVISION_COUNT -gt 1 ]]; then
    print_info "Found $REVISION_COUNT revision points in history"
    echo ""
    echo -e "${CYAN}Recent revisions:${NC}"
    conda list --revisions -n "$TARGET_ENV" | grep -A2 "^rev" | tail -20
    echo ""
    read -p "Rollback to a previous revision? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        # Activate environment for rollback script
        if [[ "$TARGET_ENV" != "${CONDA_DEFAULT_ENV:-}" ]]; then
            echo -e "${YELLOW}Note: Rollback script requires active environment${NC}"
            echo -e "${YELLOW}Run: conda activate $TARGET_ENV && $SCRIPT_DIR/conda_rollback.sh${NC}"
            echo ""
        else
            "$SCRIPT_DIR/conda_rollback.sh"
        fi
    else
        print_info "Skipping rollback"
    fi
else
    print_info "Only $REVISION_COUNT revision in history (no rollback available)"
fi

# Step 4: Offer advanced repair options
print_step "4" "Advanced Repair Options"

echo ""
echo -e "${CYAN}What would you like to do?${NC}"
echo ""
echo "  1) Export and clean environment (nuclear option - removes all packages)"
echo "  2) Re-run health check only"
echo "  3) Exit (I'll fix it manually)"
echo ""
read -p "Select option (1-3): " REPAIR_OPTION

case $REPAIR_OPTION in
    1)
        echo ""
        print_warning "This will export environment specs, then remove all packages"
        echo ""
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Export first
            echo ""
            print_info "Exporting environment to backup.yml..."
            "$SCRIPT_DIR/export_env.sh" --name "$TARGET_ENV" --file-yml "${TARGET_ENV}-backup-$(date +%Y%m%d-%H%M%S).yml" --file-req "${TARGET_ENV}-backup-$(date +%Y%m%d-%H%M%S).txt"

            echo ""
            print_success "Backup created!"
            echo ""
            print_info "To clean and rebuild:"
            echo "  1. conda activate $TARGET_ENV"
            echo "  2. $SCRIPT_DIR/clean_env.sh"
            echo "  3. $SCRIPT_DIR/sync_env.sh --yml ${TARGET_ENV}-backup-*.yml"
            echo ""
            print_warning "Clean operation not performed automatically for safety"
        fi
        ;;
    2)
        echo ""
        print_info "Re-running health check..."
        ;;
    3)
        echo ""
        print_info "Exiting. Good luck with manual fixes!"
        exit 0
        ;;
    *)
        echo ""
        print_warning "Invalid option"
        ;;
esac

# Step 5: Final health check
print_step "5" "Health Check - Verification"

echo -e "${CYAN}Verifying environment health after fixes...${NC}"
echo ""

FINAL_EXIT=0
"$SCRIPT_DIR/health_check.sh" "$TARGET_ENV" || FINAL_EXIT=$?

echo ""

if [[ $FINAL_EXIT -eq 0 ]]; then
    print_header "✅ Environment Fixed!"

    echo -e "${GREEN}The environment '${TARGET_ENV}' is now healthy!${NC}"
    echo ""
    echo -e "${CYAN}Actions taken:${NC}"
    echo "  ✓ Health check completed"
    echo "  ✓ Package conflicts resolved (if any)"
    echo "  ✓ Environment verified"
    echo ""
else
    print_header "⚠️  Issues Remain"

    echo -e "${YELLOW}The environment still has some issues.${NC}"
    echo ""
    echo -e "${CYAN}Recommended next steps:${NC}"
    echo ""
    echo "  1. Review health check output above for specific problems"
    echo ""
    echo "  2. Try rollback if recent changes caused issues:"
    echo -e "     ${YELLOW}conda activate $TARGET_ENV && $SCRIPT_DIR/conda_rollback.sh${NC}"
    echo ""
    echo "  3. For GPU issues, verify CUDA installation:"
    echo -e "     ${YELLOW}nvidia-smi${NC}"
    echo ""
    echo "  4. For severe issues, export and rebuild:"
    echo -e "     ${YELLOW}$SCRIPT_DIR/export_env.sh --name $TARGET_ENV${NC}"
    echo -e "     ${YELLOW}conda activate $TARGET_ENV && $SCRIPT_DIR/clean_env.sh${NC}"
    echo -e "     ${YELLOW}$SCRIPT_DIR/sync_env.sh --yml environment.yml${NC}"
    echo ""
    echo "  5. Last resort - clone to new environment:"
    echo -e "     ${YELLOW}$SCRIPT_DIR/clone_env.sh $TARGET_ENV ${TARGET_ENV}-fixed${NC}"
    echo ""
fi

echo -e "${CYAN}📚 Additional Resources:${NC}"
echo "  - Check conflicts: $SCRIPT_DIR/find_duplicates.sh $TARGET_ENV"
echo "  - View history: conda list --revisions -n $TARGET_ENV"
echo "  - Package info: conda list -n $TARGET_ENV"
echo ""
