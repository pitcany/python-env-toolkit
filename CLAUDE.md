# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Type:** Utility Script Collection
**Purpose:** Python Environment Management Toolkit
**Language:** Bash Shell Scripts

This repository contains standalone utility scripts for managing Python development environments, specifically focusing on Conda and Poetry package management workflows. Each script is self-contained and executable, designed to solve specific environment management tasks.

## Architecture & Code Organization

The codebase follows a **flat, single-directory structure** with no subdirectories. Each script is independent and can be run standalone. All scripts use strict error handling (`set -euo pipefail`) and follow a common pattern: argument parsing → environment validation → operation with user feedback → verification.

### Key Scripts

#### 🚀 Environment Creation & Setup

**create_ml_env.sh** - Quick ML environment creation from templates
- 11 pre-configured templates (pytorch-cpu/gpu, tensorflow-cpu/gpu, jax, data-science, nlp, cv, etc.)
- Handles CUDA/cuDNN version matching automatically
- Can auto-register as Jupyter kernel
- Supports custom Python version and additional packages

**clone_env.sh** - Smart environment cloning with modifications
- Clone with Python version changes
- Swap ML frameworks (PyTorch ↔ TensorFlow ↔ JAX)
- Switch CPU ↔ GPU packages
- Add or remove specific packages during clone
- Preview changes before applying

**poetry_bind_conda.sh** - Poetry-Conda integration
- Binds Poetry to use active Conda environment's Python interpreter
- Auto-creates Poetry environment if missing
- Supports `--force` flag to recreate environment

#### 📦 Package Management

**smart_update.sh** - Intelligent package update assistant with risk-based decision making
- Analyzes available updates for conda and pip packages
- Calculates risk scores using semantic versioning, dependency impact, and security advisories
- Interactive approval workflow with configurable verbosity (default/summary/verbose)
- Batch mode to review all updates before applying
- Integrates with `safe_install.sh` for automatic rollback points
- Optional pre-check for duplicates and post-update health check
- Caching of PyPI API responses (1-hour TTL) with `--refresh` to clear

**safe_install.sh** - Safe package installation with dry-run and rollback
- Dry-run preview of changes before installation
- Automatic conda revision snapshots (rollback points)
- Supports both conda and pip packages
- Offers instant rollback on failure
- Interactive confirmation with non-interactive mode available

**export_env.sh** - Environment export and backup
- Exports Conda dependencies to YAML (without build numbers for cross-platform compatibility)
- Exports pip packages to requirements.txt
- Supports custom output filenames via `--name`, `--file-yml`, `--file-req` flags

**sync_env.sh** - Sync environment from YAML/requirements files
- Updates packages from environment.yml and/or requirements.txt
- Optional `--prune` mode to remove unlisted packages
- Handles both conda and pip dependencies
- Non-interactive mode with `--yes` flag

**find_duplicates.sh** - Find and fix conda/pip package conflicts
- Detects packages installed via both conda and pip
- Shows version comparison for duplicates
- `--fix` mode removes pip duplicates (keeps conda versions)
- Works with active or named environments

**channel_manager.sh** - Conda channel management utility
- List configured channels with priority order
- Add/remove channels globally or per-environment
- Set channel priority (prepend to highest)
- Reset to default channel configuration
- Detect channel conflicts (conda-forge + defaults mix)
- Suggest optimal channel configurations

#### 🧹 Environment Maintenance

**clean_env.sh** - Complete environment cleanup
- Removes all Conda and pip packages except core ones (python, pip, setuptools, wheel)
- Requires active Conda environment
- Interactive confirmation before removal

**clean_poetry_env.sh** - Reset Poetry virtual environment
- Removes and recreates Poetry virtual environment
- Optional removal of poetry.lock file
- Can skip reinstallation with `--no-install`
- Keeps or removes lock file with `--keep-lock`

**remove_pip_packages.sh** - Pip package bulk removal
- Lists and removes all pip packages (excluding pip, setuptools, wheel)
- Can target specific environment: `./remove_pip_packages.sh <env_name>`
- Supports `--yes` flag for non-interactive mode

**conda_rollback.sh** - Interactive environment rollback
- Lists available revision snapshots for active Conda environment
- Prompts user to select revision number
- Shows environment state after rollback

**nuke_conda_envs.sh** - Nuclear option: remove ALL environments
- ⚠️ DESTRUCTIVE: Removes all conda/mamba environments except base
- Cleans base environment to minimal state
- Optional `--backup` to export environments first
- Updates conda/mamba to latest version
- Requires explicit "DELETE EVERYTHING" confirmation

#### 📓 Jupyter Integration

**manage_jupyter_kernels.sh** - Unified Jupyter kernel management
- `list` - List all kernels with status (valid/orphaned)
- `add` - Register conda environment as kernel
- `remove` - Remove specific kernel
- `clean` - Remove orphaned kernels (pointing to deleted environments)
- `sync` - Register all conda environments as kernels
- Auto-installs ipykernel where needed

#### 🔍 Diagnostics & Health

**health_check.sh** - Comprehensive environment health diagnostics
- GPU/CUDA/cuDNN configuration validation
- PyTorch/TensorFlow/JAX GPU availability checks
- CUDA version compatibility checking
- Package conflict detection (conda/pip duplicates)
- Jupyter kernel registration status
- Disk space analysis
- ML framework version validation
- Health score (0-100%) with pass/warning/fail counts
- Quick mode (`--quick`) and GPU-only mode (`--gpu-only`)

**env_diff.sh** - Compare two environments
- Show packages unique to each environment
- Highlight version mismatches for common packages
- Compare both conda and pip packages
- Export diff report to file
- Generate sync commands to reconcile differences
- Detailed and summary display modes
- Useful for team synchronization and debugging discrepancies

#### 🛠️ Development & Validation

**validate_scripts.sh** - Shell script validation with shellcheck
- Validates all shell scripts using shellcheck
- Supports strict mode (treats warnings as errors)
- Shows suggested fixes for issues
- Integrates with CI/CD (GitHub Actions workflow included)
- Helps maintain code quality and catch bugs early

## Common Commands

### Running Scripts

All scripts require Bash and an active Conda environment (except when specifying environment by name):

```bash
# Make scripts executable (if needed)
chmod +x *.sh

# Run scripts (most require active conda environment)
conda activate myenv
./clean_env.sh
./export_env.sh
./conda_rollback.sh
./poetry_bind_conda.sh

# Or specify environment name
./remove_pip_packages.sh myenv
./export_env.sh --name myenv
```

### Common Workflows

**Create new ML environment:**
```bash
# From template
./create_ml_env.sh myproject --template pytorch-gpu --register-kernel

# Check health
conda activate myproject
./health_check.sh
```

**Intelligent package updates:**
```bash
conda activate myenv
./smart_update.sh                         # Interactive update workflow
./smart_update.sh --verbose               # Detailed risk breakdown
./smart_update.sh --batch                 # Review all updates first
./smart_update.sh --check-duplicates --health-check-after  # With pre/post checks
```

**Safe package installation:**
```bash
conda activate myenv
./safe_install.sh transformers --dry-run  # Preview first
./safe_install.sh transformers            # Install with auto-snapshot
```

**Backup before changes:**
```bash
conda activate myenv
./export_env.sh --file-yml backup.yml --file-req backup-requirements.txt
```

**Clone environment with modifications:**
```bash
# Clone CPU env as GPU
./clone_env.sh myenv-cpu myenv-gpu --cpu-to-gpu

# Clone with newer Python
./clone_env.sh old new --python 3.11
```

**Fix environment conflicts:**
```bash
conda activate myenv
./find_duplicates.sh --fix        # Remove conda/pip duplicates
./health_check.sh                 # Verify health
```

**Rollback after problematic update:**
```bash
conda activate myenv
./conda_rollback.sh
# Select previous revision from list
```

**Manage Jupyter kernels:**
```bash
./manage_jupyter_kernels.sh list         # List all kernels
./manage_jupyter_kernels.sh add myenv    # Register environment
./manage_jupyter_kernels.sh clean        # Remove orphaned
```

**Set up Poetry with Conda:**
```bash
conda activate myenv
./poetry_bind_conda.sh
```

### Linting

No linter is configured, but you can use shellcheck:

```bash
shellcheck *.sh
```

## Design Patterns & Conventions

### Error Handling
All scripts use `set -euo pipefail` for strict error handling (exit on error, treat unset variables as errors, fail on pipe errors).

### User Safety
- **Interactive confirmations** for destructive operations (can be bypassed with `--yes` where supported)
- **Core package protection**: python, pip, setuptools, wheel are never removed
- **Pre-flight checks** validate environment state before proceeding

### Script Structure Pattern
1. Shebang and documentation header
2. Error handling setup (`set -euo pipefail`)
3. Argument parsing and validation
4. Environment detection/validation
5. Main operation with user feedback
6. Verification and summary output

### Variable Naming
- Environment variables: ALL_CAPS (e.g., `CONDA_DEFAULT_ENV`)
- Local variables: lowercase_with_underscores
- Flags/booleans: SCREAMING_SNAKE_CASE (e.g., `FORCE_RECREATE`)

### Output Formatting
- Emojis for visual categorization (🧭 navigation, 🧹 cleaning, ✅ success, 🚫 error)
- Color codes in some scripts (RED, GREEN, YELLOW)
- Clear separators and whitespace for readability

## Important Notes

### Dependencies
- **Conda/Miniconda** - Required for all scripts except Poetry-specific ones
- **Poetry** - Required only for poetry_bind_conda.sh and clean_poetry_env.sh
- **Jupyter** - Required only for manage_jupyter_kernels.sh
- **NVIDIA drivers/CUDA** - Optional, for GPU-enabled features and templates
- Standard Unix utilities (grep, sed, awk, cut, xargs) must be available

### Script Independence
Scripts are **independent** and don't call each other (except health_check.sh may optionally call find_duplicates.sh if available, and smart_update.sh calls safe_install.sh internally), but complement each other in workflows:
- Use `smart_update.sh` for risk-aware package updates with interactive approval
- Use `export_env.sh` before `clean_env.sh` or `nuke_conda_envs.sh` for backup
- Use `safe_install.sh` for installations with automatic rollback points
- Use `conda_rollback.sh` as undo mechanism for environment changes
- Use `health_check.sh` to diagnose issues, then `find_duplicates.sh --fix` to resolve conflicts
- Use `create_ml_env.sh` with `--register-kernel` or follow up with `manage_jupyter_kernels.sh add`
- Use `clone_env.sh` to create modified copies without affecting originals
- Use `poetry_bind_conda.sh` for hybrid Conda+Poetry workflows
- Use `smart_update.sh --check-duplicates --health-check-after` to ensure clean state before and after updates

### Testing
No automated test suite exists. Test manually in isolated Conda test environments, not production ones. Test cases should include: empty environments, environments with multiple packages, no active environment, invalid inputs, and cancellation prompts.
