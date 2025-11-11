#!/usr/bin/env bash

# nuke_conda_envs.sh
# Removes ALL conda/mamba environments (except base) and completely resets base environment
# WARNING: This is a DESTRUCTIVE operation that cannot be easily undone!

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
SKIP_CONFIRMATION=false
BACKUP_FIRST=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --backup|-b)
            BACKUP_FIRST=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Removes ALL conda/mamba environments and resets base environment to clean state."
            echo ""
            echo "Options:"
            echo "  --yes, -y       Skip confirmation prompts"
            echo "  --backup, -b    Backup all environments before deletion"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "⚠️  WARNING: This operation is DESTRUCTIVE and cannot be easily undone!"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}💣 CONDA/MAMBA ENVIRONMENT NUCLEAR OPTION${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo -e "${RED}❌ conda command not found. Please ensure Conda is installed and initialized.${NC}"
    exit 1
fi

# Get conda root directory
CONDA_ROOT=$(conda info --base)
echo -e "${BLUE}🔍 Conda root directory:${NC} $CONDA_ROOT"
echo ""

# List all environments
echo -e "${YELLOW}📋 Current environments:${NC}"
conda env list
echo ""

# Count environments (excluding base)
ENV_COUNT=$(conda env list | grep -v '^#' | grep -v '^\s*$' | grep -v 'base' | wc -l)

if [[ $ENV_COUNT -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No non-base environments found.${NC}"
else
    echo -e "${YELLOW}⚠️  Found $ENV_COUNT non-base environment(s) to remove.${NC}"
fi
echo ""

# Backup option
if [[ "$BACKUP_FIRST" == true ]]; then
    BACKUP_DIR="conda_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    echo -e "${BLUE}💾 Backing up environments to: $BACKUP_DIR${NC}"

    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ $line =~ ^#.* ]] || [[ -z $line ]]; then
            continue
        fi

        # Extract environment name (first column)
        env_name=$(echo "$line" | awk '{print $1}')

        if [[ -n $env_name ]]; then
            echo "  📦 Exporting $env_name..."
            conda env export -n "$env_name" > "$BACKUP_DIR/${env_name}.yml" 2>/dev/null || true
        fi
    done < <(conda env list | grep -v '^#')

    echo -e "${GREEN}✅ Backups saved to: $BACKUP_DIR${NC}"
    echo ""
fi

# Show warning and require confirmation
echo -e "${RED}⚠️  ⚠️  ⚠️  DANGER ZONE ⚠️  ⚠️  ⚠️${NC}"
echo ""
echo "This script will:"
echo -e "  ${RED}1. Delete ALL non-base conda/mamba environments${NC}"
echo -e "  ${RED}2. Remove ALL packages from base environment (except core)${NC}"
echo -e "  ${RED}3. Update conda/mamba to the latest version${NC}"
echo ""
echo -e "${YELLOW}This operation CANNOT be easily undone!${NC}"
echo ""

if [[ "$SKIP_CONFIRMATION" == false ]]; then
    echo -e "${YELLOW}To proceed, type exactly:${NC} ${RED}DELETE EVERYTHING${NC}"
    read -r -p "➤ " confirmation

    if [[ "$confirmation" != "DELETE EVERYTHING" ]]; then
        echo -e "${GREEN}✅ Operation cancelled. Your environments are safe.${NC}"
        exit 0
    fi
    echo ""
fi

# Step 1: Remove all non-base environments
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}🗑️  Step 1: Removing non-base environments${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [[ $ENV_COUNT -gt 0 ]]; then
    while IFS= read -r line; do
        # Skip comments, empty lines, and base environment
        if [[ $line =~ ^#.* ]] || [[ -z $line ]] || [[ $line =~ base ]]; then
            continue
        fi

        # Extract environment name and path
        env_name=$(echo "$line" | awk '{print $1}')

        if [[ -n $env_name ]]; then
            echo -e "  ${YELLOW}🧹 Removing environment: $env_name${NC}"
            conda env remove -n "$env_name" -y
            echo -e "  ${GREEN}✅ Removed: $env_name${NC}"
            echo ""
        fi
    done < <(conda env list | grep -v '^#' | grep -v 'base')

    echo -e "${GREEN}✅ All non-base environments removed.${NC}"
else
    echo -e "${GREEN}✅ No non-base environments to remove.${NC}"
fi
echo ""

# Step 2: Clean base environment
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}🧹 Step 2: Cleaning base environment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get list of packages in base (excluding protected ones)
echo "🔍 Analyzing base environment packages..."
PROTECTED_PACKAGES="^(python|conda|pip|setuptools|wheel|_libgcc_mutex|_openmp_mutex|ca-certificates|certifi|libgcc-ng|libgomp|libstdcxx-ng|ld_impl_linux-gnu)$"

# Get conda packages (excluding protected ones)
CONDA_PACKAGES=$(conda list -n base --no-pip | awk 'NR>3 {print $1}' | grep -Ev "$PROTECTED_PACKAGES" || true)

# Get pip packages (excluding protected ones)
PIP_PACKAGES=$(conda list -n base --export | grep '# pip' | sed 's/# pip.*//' | awk '{print $1}' | grep -Ev "^(pip|setuptools|wheel)$" || true)

if [[ -n "$CONDA_PACKAGES" ]]; then
    echo ""
    echo -e "${YELLOW}📦 Conda packages to remove:${NC}"
    echo "$CONDA_PACKAGES" | head -20
    if [[ $(echo "$CONDA_PACKAGES" | wc -l) -gt 20 ]]; then
        echo "... and $(( $(echo "$CONDA_PACKAGES" | wc -l) - 20 )) more"
    fi
    echo ""
    echo "🗑️  Removing conda packages from base..."
    echo "$CONDA_PACKAGES" | xargs -r conda remove -n base -y --force || true
    echo -e "${GREEN}✅ Conda packages removed from base.${NC}"
else
    echo -e "${GREEN}✅ No conda packages to remove from base.${NC}"
fi

if [[ -n "$PIP_PACKAGES" ]]; then
    echo ""
    echo -e "${YELLOW}📦 Pip packages to remove:${NC}"
    echo "$PIP_PACKAGES" | head -20
    if [[ $(echo "$PIP_PACKAGES" | wc -l) -gt 20 ]]; then
        echo "... and $(( $(echo "$PIP_PACKAGES" | wc -l) - 20 )) more"
    fi
    echo ""
    echo "🗑️  Removing pip packages from base..."
    echo "$PIP_PACKAGES" | xargs -r conda run -n base pip uninstall -y || true
    echo -e "${GREEN}✅ Pip packages removed from base.${NC}"
else
    echo -e "${GREEN}✅ No pip packages to remove from base.${NC}"
fi

echo ""

# Step 3: Update conda/mamba
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🔄 Step 3: Updating conda to latest version${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

conda update -n base conda -y

# Check if mamba is available and update it
if command -v mamba &> /dev/null; then
    echo ""
    echo "🔄 Updating mamba..."
    conda update -n base mamba -y || true
fi

echo ""
echo -e "${GREEN}✅ Conda updated successfully.${NC}"
echo ""

# Step 4: Clean conda cache
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🧼 Step 4: Cleaning conda cache${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

conda clean --all -y

echo -e "${GREEN}✅ Conda cache cleaned.${NC}"
echo ""

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ OPERATION COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Final environment status:"
conda env list
echo ""
echo "📦 Base environment packages:"
conda list -n base
echo ""
echo -e "${GREEN}🎉 Your conda installation has been reset to a clean state!${NC}"
echo ""

if [[ "$BACKUP_FIRST" == true ]]; then
    echo -e "${BLUE}💾 Environment backups are available in: $BACKUP_DIR${NC}"
    echo "   To restore an environment: conda env create -f $BACKUP_DIR/<env_name>.yml"
    echo ""
fi
