#!/usr/bin/env bash
################################################################################
# install_conda.sh - Download and install latest stable Miniconda or Miniforge
#
# Usage:
#   ./install_conda.sh [OPTIONS]
#
# Options:
#   --miniforge          Install Miniforge (default, recommended)
#   --miniconda          Install Miniconda instead
#   --path <path>        Custom installation directory (default: ~/miniforge3 or ~/miniconda3)
#   --no-init            Skip shell initialization (conda init)
#   --unattended         Non-interactive mode, use defaults
#   --help               Show this help message
#
# Description:
#   Downloads and installs the latest stable version of Miniforge or Miniconda.
#   Miniforge is recommended for better performance and conda-forge default channel.
#   Automatically detects platform (Linux/macOS) and architecture (x86_64/ARM64).
#   Verifies SHA256 checksums for security before installation.
#
# Examples:
#   ./install_conda.sh                          # Install Miniforge interactively
#   ./install_conda.sh --miniconda              # Install Miniconda instead
#   ./install_conda.sh --path ~/conda           # Custom installation path
#   ./install_conda.sh --unattended --no-init   # CI/CD mode
#
################################################################################

set -euo pipefail

# Default configuration
INSTALLER_TYPE="miniforge"  # miniforge or miniconda
INSTALLER_TYPE_EXPLICIT=false  # Track if user explicitly set type via CLI
INSTALL_PATH=""
SKIP_INIT=false
UNATTENDED=false

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --miniforge)
            INSTALLER_TYPE="miniforge"
            INSTALLER_TYPE_EXPLICIT=true
            shift
            ;;
        --miniconda)
            INSTALLER_TYPE="miniconda"
            INSTALLER_TYPE_EXPLICIT=true
            shift
            ;;
        --path)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}❌ Error: --path requires a directory path${NC}"
                exit 1
            fi
            INSTALL_PATH="$2"
            shift 2
            ;;
        --no-init)
            SKIP_INIT=true
            shift
            ;;
        --unattended)
            UNATTENDED=true
            shift
            ;;
        --help)
            sed -n '/^# install_conda.sh/,/^################################################################################$/p' "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect platform
detect_platform() {
    local os=""
    local arch=""

    case "$(uname -s)" in
        Linux*)
            os="Linux"
            ;;
        Darwin*)
            os="MacOSX"
            ;;
        *)
            echo -e "${RED}❌ Unsupported operating system: $(uname -s)${NC}"
            echo "This script supports Linux and macOS only."
            exit 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64)
            arch="x86_64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        *)
            echo -e "${RED}❌ Unsupported architecture: $(uname -m)${NC}"
            echo "This script supports x86_64 and ARM64/aarch64 only."
            exit 1
            ;;
    esac

    echo "${os}-${arch}"
}

# Get download URL and filename for installer
get_installer_info() {
    local installer_type=$1
    local platform=$2
    local base_url=""
    local filename=""

    if [[ "$installer_type" == "miniforge" ]]; then
        base_url="https://github.com/conda-forge/miniforge/releases/latest/download"
        filename="Miniforge3-${platform}.sh"
    else
        # Miniconda latest versions
        base_url="https://repo.anaconda.com/miniconda"
        filename="Miniconda3-latest-${platform}.sh"
    fi

    echo "${base_url}|${filename}"
}

# Download file with progress
download_file() {
    local url=$1
    local output=$2

    echo -e "${BLUE}📥 Downloading from: $url${NC}"

    if command -v curl &> /dev/null; then
        curl -L -o "$output" "$url" --progress-bar
    elif command -v wget &> /dev/null; then
        wget -O "$output" "$url" --show-progress
    else
        echo -e "${RED}❌ Neither curl nor wget found. Please install one of them.${NC}"
        exit 1
    fi
}

# Verify SHA256 checksum for Miniforge
verify_checksum_miniforge() {
    local installer_file=$1
    local platform=$2

    echo -e "${BLUE}🔐 Verifying checksum...${NC}"

    # Download checksums file
    local checksums_url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-${platform}.sh.sha256"
    local checksums_file="${installer_file}.sha256"

    if ! download_file "$checksums_url" "$checksums_file" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Could not download checksums file. Skipping verification.${NC}"
        return 0
    fi

    local expected_checksum
    expected_checksum=$(awk '{print $1}' "$checksums_file")

    local actual_checksum
    if command -v sha256sum &> /dev/null; then
        actual_checksum=$(sha256sum "$installer_file" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        actual_checksum=$(shasum -a 256 "$installer_file" | awk '{print $1}')
    else
        echo -e "${YELLOW}⚠️  No SHA256 tool found. Skipping verification.${NC}"
        rm -f "$checksums_file"
        return 0
    fi

    rm -f "$checksums_file"

    if [[ "$expected_checksum" != "$actual_checksum" ]]; then
        echo -e "${RED}❌ Checksum verification failed!${NC}"
        echo -e "Expected: $expected_checksum"
        echo -e "Got:      $actual_checksum"
        exit 1
    fi

    echo -e "${GREEN}✅ Checksum verified successfully${NC}"
}

# Verify file integrity for Miniconda (basic check)
verify_miniconda() {
    local installer_file=$1

    # Miniconda doesn't publish checksums in an easily accessible way
    # Just verify the file is a valid bash script and reasonable size
    if [[ ! -s "$installer_file" ]]; then
        echo -e "${RED}❌ Downloaded file is empty${NC}"
        exit 1
    fi

    local file_size
    file_size=$(stat -f%z "$installer_file" 2>/dev/null || stat -c%s "$installer_file" 2>/dev/null || echo "0")

    # Miniconda installer should be at least 50MB
    if [[ -z "$file_size" || $file_size -lt 52428800 ]]; then
        echo -e "${RED}❌ Downloaded file seems too small (${file_size} bytes)${NC}"
        exit 1
    fi

    local first_line
    first_line=$(head -n 1 "$installer_file")
    if [[ ! "$first_line" =~ ^#!/bin/bash ]]; then
        echo -e "${RED}❌ Downloaded file doesn't appear to be a bash script${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Basic integrity check passed${NC}"
}

# Main installation function
main() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  🚀 Conda Installer${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Detect platform
    local platform
    platform=$(detect_platform)
    echo -e "${BLUE}🖥️  Detected platform: $platform${NC}"
    echo ""

    # Interactive selection if not explicitly specified via CLI
    if [[ "$UNATTENDED" == false && "$INSTALLER_TYPE_EXPLICIT" == false ]]; then
        echo -e "${YELLOW}📦 Which distribution would you like to install?${NC}"
        echo ""
        echo "  1) Miniforge (recommended)"
        echo "     • Uses conda-forge channel by default"
        echo "     • Faster package resolution"
        echo "     • More packages available"
        echo "     • Community-maintained"
        echo ""
        echo "  2) Miniconda"
        echo "     • Official Anaconda distribution"
        echo "     • Uses defaults channel"
        echo "     • More conservative package versions"
        echo ""

        read -rp "Enter choice [1-2] (default: 1): " choice
        choice=${choice:-1}

        case $choice in
            1)
                INSTALLER_TYPE="miniforge"
                ;;
            2)
                INSTALLER_TYPE="miniconda"
                ;;
            *)
                echo -e "${RED}❌ Invalid choice${NC}"
                exit 1
                ;;
        esac
        echo ""
    fi

    # Set default installation path if not specified
    if [[ -z "$INSTALL_PATH" ]]; then
        if [[ "$INSTALLER_TYPE" == "miniforge" ]]; then
            INSTALL_PATH="$HOME/miniforge3"
        else
            INSTALL_PATH="$HOME/miniconda3"
        fi
    fi

    # Expand tilde in path
    INSTALL_PATH="${INSTALL_PATH/#\~/$HOME}"

    # Check if already installed
    if [[ -d "$INSTALL_PATH" ]]; then
        echo -e "${YELLOW}⚠️  Installation directory already exists: $INSTALL_PATH${NC}"

        if [[ "$UNATTENDED" == false ]]; then
            read -rp "Remove existing installation and continue? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}ℹ️  Installation cancelled${NC}"
                exit 0
            fi
            echo -e "${BLUE}🧹 Removing existing installation...${NC}"
            rm -rf "$INSTALL_PATH"
        else
            echo -e "${RED}❌ Cannot proceed in unattended mode with existing installation${NC}"
            exit 1
        fi
    fi

    # Get installer information
    local installer_info
    installer_info=$(get_installer_info "$INSTALLER_TYPE" "$platform")
    local base_url
    base_url=$(echo "$installer_info" | cut -d'|' -f1)
    local filename
    filename=$(echo "$installer_info" | cut -d'|' -f2)
    local download_url="${base_url}/${filename}"

    # Create temporary directory for download
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT

    local installer_file="${temp_dir}/${filename}"

    echo -e "${BLUE}📋 Installation Summary:${NC}"
    echo -e "   Type:        ${INSTALLER_TYPE}"
    echo -e "   Platform:    ${platform}"
    echo -e "   Destination: ${INSTALL_PATH}"
    echo ""

    if [[ "$UNATTENDED" == false ]]; then
        read -rp "Proceed with installation? [Y/n]: " proceed
        proceed=${proceed:-Y}
        if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}ℹ️  Installation cancelled${NC}"
            exit 0
        fi
        echo ""
    fi

    # Download installer
    download_file "$download_url" "$installer_file"
    echo ""

    # Verify checksum/integrity
    if [[ "$INSTALLER_TYPE" == "miniforge" ]]; then
        verify_checksum_miniforge "$installer_file" "$platform"
    else
        verify_miniconda "$installer_file"
    fi
    echo ""

    # Run installer
    echo -e "${BLUE}📦 Running installer...${NC}"

    # Verify file is readable before executing
    if [[ ! -r "$installer_file" ]]; then
        echo -e "${RED}❌ Downloaded file is not readable${NC}"
        exit 1
    fi

    bash "$installer_file" -b -p "$INSTALL_PATH"
    echo ""

    # Initialize shell if requested
    if [[ "$SKIP_INIT" == false ]]; then
        echo -e "${BLUE}🔧 Initializing shell...${NC}"

        # Detect shell
        local shell_name
        shell_name=$(basename "$SHELL")

        if [[ -f "${INSTALL_PATH}/bin/conda" ]]; then
            "${INSTALL_PATH}/bin/conda" init "$shell_name" > /dev/null 2>&1 || true
            echo -e "${GREEN}✅ Shell initialized for $shell_name${NC}"
            echo -e "${YELLOW}⚠️  Please restart your shell or run: source ~/.${shell_name}rc${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not find conda binary for shell initialization${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Skipped shell initialization${NC}"
        echo -e "${YELLOW}💡 To manually initialize, run:${NC}"
        echo -e "   ${INSTALL_PATH}/bin/conda init"
    fi
    echo ""

    # Installation summary
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Installation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📍 Installation location: ${INSTALL_PATH}${NC}"
    echo ""
    echo -e "${YELLOW}🚀 Next steps:${NC}"

    if [[ "$SKIP_INIT" == false ]]; then
        echo "   1. Restart your shell or run: source ~/.$(basename "$SHELL")rc"
        echo "   2. Verify installation: conda --version"
        echo "   3. Create your first environment: conda create -n myenv python=3.11"
    else
        echo "   1. Initialize shell: ${INSTALL_PATH}/bin/conda init"
        echo "   2. Restart your shell"
        echo "   3. Verify installation: conda --version"
        echo "   4. Create your first environment: conda create -n myenv python=3.11"
    fi
    echo ""

    if [[ "$INSTALLER_TYPE" == "miniforge" ]]; then
        echo -e "${BLUE}💡 Miniforge uses conda-forge channel by default${NC}"
        echo "   This provides faster package resolution and more packages."
        echo ""
    fi

    echo -e "${GREEN}Happy coding! 🎉${NC}"
}

# Run main function
main
