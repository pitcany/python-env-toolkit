# Python Environment Management Toolkit

A comprehensive collection of Bash scripts for managing Python development environments with Conda, pip, and Poetry. Designed specifically for data scientists and machine learning engineers who need robust, reliable environment management.

## Table of Contents

- [Quick Start](#quick-start)
- [Example Workflows](#example-workflows)
- [Script Overview](#script-overview)
- [Environment Creation & Setup](#environment-creation--setup)
- [Package Management](#package-management)
- [Environment Maintenance](#environment-maintenance)
- [Jupyter Integration](#jupyter-integration)
- [Diagnostics & Health](#diagnostics--health)
- [Common Workflows](#common-workflows)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Quick Start

```bash
# Make all scripts executable
chmod +x *.sh

# Create a new ML environment from template
./create_ml_env.sh myproject --template pytorch-gpu --register-kernel

# Check environment health
./health_check.sh myproject

# Install packages safely with preview and rollback
conda activate myproject
./safe_install.sh transformers torch-geometric --dry-run  # Preview first
./safe_install.sh transformers torch-geometric            # Actually install
```

## Example Workflows

**New to the toolkit?** Start with our complete workflow examples that show you how to chain scripts together for real-world scenarios.

### 🎯 new-ml-project.sh

Complete interactive workflow for setting up a new ML project from scratch.

```bash
./examples/new-ml-project.sh
```

**What it does:**
1. ✅ Prompts for project name and template selection (PyTorch, TensorFlow, etc.)
2. ✅ Creates optimized environment with proper CUDA versions
3. ✅ Installs additional packages safely
4. ✅ Exports specs for version control (environment.yml, requirements.txt)
5. ✅ Registers Jupyter kernel automatically
6. ✅ Runs health check and provides next steps

**Perfect for:** Starting new research projects, setting up team environments, creating reproducible setups

---

### 🔧 fix-broken-env.sh

Comprehensive diagnostic and repair workflow for troubleshooting environment issues.

```bash
# With active environment
conda activate broken-env
./examples/fix-broken-env.sh

# Or specify environment
./examples/fix-broken-env.sh broken-env
```

**What it does:**
1. 🔍 Runs comprehensive health check to identify problems
2. 🔍 Detects and fixes conda/pip package conflicts
3. 🔍 Reviews environment history for rollback options
4. 🔍 Offers export-and-clean for severe cases
5. 🔍 Re-verifies health and provides detailed remediation steps

**Perfect for:** Debugging import errors, fixing broken installations, resolving CUDA issues, recovering from bad updates

---

### Learn More

See [examples/README.md](examples/README.md) for:
- Detailed usage instructions
- Example sessions with output
- How to create your own workflows
- Additional workflow ideas

---

## Script Overview

### 🚀 Environment Creation & Setup

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **create_ml_env.sh** | Create ML environments from templates | 11 pre-configured templates (PyTorch, TensorFlow, JAX, etc.) |
| **clone_env.sh** | Clone with modifications | Swap frameworks, change Python version, add/remove packages |
| **poetry_bind_conda.sh** | Integrate Poetry with Conda | Bind Poetry to use Conda's Python interpreter |

### 📦 Package Management

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **smart_update.sh** | Intelligent update assistant | Risk-based decisions, interactive approval, batch mode |
| **safe_install.sh** | Install with preview & rollback | Dry-run preview, automatic snapshots, instant rollback |
| **export_env.sh** | Export environment specs | YAML + requirements.txt, cross-platform compatible |
| **sync_env.sh** | Sync from YAML/requirements | Update packages, prune extras, maintain consistency |
| **find_duplicates.sh** | Detect conda/pip conflicts | Find & fix packages installed in both |
| **channel_manager.sh** | Manage conda channels | Add/remove/prioritize channels, detect conflicts |

### 🧹 Environment Maintenance

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **clean_env.sh** | Remove all packages | Keep core (python, pip, setuptools, wheel) |
| **clean_poetry_env.sh** | Reset Poetry environment | Remove and recreate Poetry virtual env |
| **remove_pip_packages.sh** | Bulk remove pip packages | Remove all pip packages except core |
| **conda_rollback.sh** | Interactive rollback | Select from revision history, preview changes |
| **nuke_conda_envs.sh** | Nuclear cleanup | Remove ALL environments and reset base |

### 📓 Jupyter Integration

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **manage_jupyter_kernels.sh** | Unified kernel management | List, add, remove, clean orphaned, sync all |

### 🔍 Diagnostics & Health

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **health_check.sh** | Comprehensive diagnostics | GPU/CUDA check, conflicts, Jupyter status, health score |
| **env_diff.sh** | Compare two environments | Show differences, version mismatches, sync commands |

### 🛠️ Development & Validation

| Script | Purpose | Key Features |
|--------|---------|--------------|
| **validate_scripts.sh** | Shellcheck validation | Validate all scripts, CI/CD integration, strict mode |

---

## Environment Creation & Setup

### Creating ML Environments

Use `create_ml_env.sh` to quickly create pre-configured environments:

```bash
# PyTorch with GPU
./create_ml_env.sh pytorch-proj --template pytorch-gpu

# TensorFlow CPU-only
./create_ml_env.sh tf-cpu --template tensorflow-cpu

# Data science environment
./create_ml_env.sh analysis --template data-science

# NLP environment with custom packages
./create_ml_env.sh nlp-research --template nlp --add spacy-transformers --add sentencepiece

# Create and register Jupyter kernel in one step
./create_ml_env.sh cv-proj --template cv --register-kernel --python 3.11
```

**Available Templates:**
- `pytorch-cpu` / `pytorch-gpu` - PyTorch + common ML libraries
- `tensorflow-cpu` / `tensorflow-gpu` - TensorFlow + common ML libraries
- `jax-cpu` / `jax-gpu` - JAX + common ML libraries
- `data-science` - Pandas, NumPy, Scikit-learn, Matplotlib, Seaborn
- `deep-learning` - PyTorch + TensorFlow + visualization
- `nlp` - Transformers, spaCy, NLTK + PyTorch
- `cv` - Computer Vision: PyTorch, OpenCV, PIL, torchvision
- `minimal` - Minimal Python environment

### Cloning with Modifications

Clone existing environments with intelligent modifications:

```bash
# Clone with newer Python version
./clone_env.sh myenv myenv-py311 --python 3.11

# Clone CPU environment as GPU
./clone_env.sh pytorch-cpu pytorch-gpu --cpu-to-gpu

# Swap frameworks
./clone_env.sh pytorch-env tensorflow-env --swap-framework pytorch->tensorflow

# Clone and add/remove packages
./clone_env.sh prod dev --add pytest --add black --remove boto3

# Complex modifications
./clone_env.sh old new --python 3.11 --gpu-to-cpu --add pandas --remove tensorflow
```

**Supported Framework Swaps:**
- `pytorch->tensorflow` (or `pytorch->tf`)
- `tensorflow->pytorch` (or `tf->pytorch`)
- `pytorch->jax`

---

## Package Management

### Intelligent Package Updates

Use `smart_update.sh` for risk-aware package updates with interactive approval:

```bash
conda activate myenv

# Interactive mode with default output
./smart_update.sh

# Verbose mode - detailed risk breakdown
./smart_update.sh --verbose

# Summary mode - minimal one-line output
./smart_update.sh --summary

# Batch mode - review all updates first, then approve
./smart_update.sh --batch

# Target specific environment
./smart_update.sh --name myenv

# Only check conda packages
./smart_update.sh --conda-only

# Only check pip packages
./smart_update.sh --pip-only

# Pre-check for conflicts and post-update health check
./smart_update.sh --check-duplicates --health-check-after

# Export environment after updates
./smart_update.sh --export-after

# Refresh cache (clear PyPI API cache)
./smart_update.sh --refresh
```

**How it works:**

1. **Detects available updates** - Queries conda and pip for outdated packages
2. **Calculates risk scores** - Analyzes version changes, dependency impacts, and security advisories
3. **Interactive approval** - Present each update with risk assessment and options:
   - `[a]pprove` - Apply this update
   - `[s]kip` - Skip this update
   - `[d]etails` - Toggle verbose view for this package
   - `[q]uit` - Exit without applying remaining updates
4. **Batch execution** - Uses `safe_install.sh` internally for automatic rollback points
5. **Post-update actions** - Optional health check and environment export

**Risk Scoring System:**

The script calculates risk based on multiple factors:

1. **Semantic Versioning:**
   - Major bump (2.x → 3.x) = HIGH risk (breaking changes expected)
   - Minor bump (2.1 → 2.2) = MEDIUM risk (new features, possible behavior changes)
   - Patch bump (2.1.1 → 2.1.2) = LOW risk (bug fixes only)

2. **Dependency Impact Modifier:**
   - 0 other packages affected: no change
   - 1-3 packages affected: +1 risk level
   - 4+ packages affected: +2 risk levels

3. **Security/Bug Fix Modifier:**
   - Security fix detected: -1 risk level (minimum LOW)
   - Checks PyPI API for security advisories and classifiers

**Output Modes:**

**Default (compact):**
```
📦 numpy: 1.24.3 → 1.26.4 [MEDIUM RISK]
   Reason: Minor version bump + 2 dependency changes

   [a]pprove  [s]kip  [d]etails  [q]uit:
```

**Summary (`--summary`):**
```
📦 numpy 1.24.3→1.26.4 [MED] Minor+deps | [a/s/d/q]:
```

**Verbose (`--verbose`):**
```
📦 numpy: 1.24.3 → 1.26.4
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Risk Score: MEDIUM
├─ Version change: Minor (1.24→1.26) [MEDIUM]
├─ Dependency impact: 2 packages affected [+1 risk]
│  └─ pandas 2.0.0 → 2.0.3
│  └─ scikit-learn will be upgraded
├─ Release type: Bug fixes + features
└─ Security advisories: None found

[a]pprove  [s]kip  [d]etails  [q]uit:
```

**Best Practices:**

- Run `--check-duplicates` flag before updates to ensure clean state
- Use `--verbose` mode when updating critical dependencies
- Use `--batch` mode to review all updates before applying
- Enable `--health-check-after` to verify environment health
- Use `--export-after` to automatically backup environment post-update
- Clear cache with `--refresh` if you see stale update information

### Safe Installation with Preview

Always preview changes before installing:

```bash
conda activate myenv

# Preview what would change (dry-run only)
./safe_install.sh pandas scikit-learn --dry-run

# Install with automatic snapshot
./safe_install.sh pandas scikit-learn

# If something breaks, rollback is one command away
conda install --revision 42  # Or use ./conda_rollback.sh

# Install pip packages safely
./safe_install.sh --pip transformers datasets --dry-run
./safe_install.sh --pip transformers datasets

# Non-interactive mode
./safe_install.sh torch torchvision --yes
```

### Export & Sync Environments

**Export for backup or sharing:**

```bash
conda activate myenv

# Export to default files (environment.yml, requirements.txt)
./export_env.sh

# Export with custom names
./export_env.sh --file-yml backup-2024.yml --file-req backup-2024-req.txt

# Export specific environment (without activating)
./export_env.sh --name myenv --file-yml myenv-backup.yml
```

**Sync from specification files:**

```bash
conda activate myenv

# Sync from YAML (update packages)
./sync_env.sh --yml environment.yml

# Sync from both YAML and requirements
./sync_env.sh --yml environment.yml --req requirements.txt

# Prune packages not in specs
./sync_env.sh --yml environment.yml --prune

# Non-interactive sync
./sync_env.sh --yml environment.yml --prune --yes
```

### Finding and Fixing Conflicts

Detect packages installed via both conda and pip:

```bash
conda activate myenv

# List duplicates
./find_duplicates.sh

# List duplicates for specific environment
./find_duplicates.sh myenv

# Automatically fix (removes pip versions, keeps conda)
./find_duplicates.sh --fix

# Non-interactive fix
./find_duplicates.sh myenv --fix --yes
```

---

## Environment Maintenance

### Cleaning Environments

**Clean current environment:**

```bash
conda activate myenv

# Remove all packages except core
./clean_env.sh

# Keeps: python, pip, setuptools, wheel
# Removes: everything else
```

**Remove pip packages:**

```bash
conda activate myenv

# Remove all pip packages (except core)
./remove_pip_packages.sh

# Remove from specific environment
./remove_pip_packages.sh myenv

# Non-interactive mode
./remove_pip_packages.sh myenv --yes
```

**Clean Poetry environment:**

```bash
cd my-poetry-project

# Interactive cleanup (prompts for options)
./clean_poetry_env.sh

# Clean and reinstall automatically
./clean_poetry_env.sh --yes

# Clean but don't reinstall yet
./clean_poetry_env.sh --no-install

# Keep poetry.lock file
./clean_poetry_env.sh --keep-lock
```

### Rolling Back Changes

Undo environment changes using conda's revision system:

```bash
conda activate myenv

# Interactive rollback (shows revision list)
./conda_rollback.sh

# Shows all available revisions with dates
# Prompts you to select one
# Shows what will change
# Performs rollback
```

### Nuclear Option

**⚠️ WARNING: DESTRUCTIVE** - Use with caution!

```bash
# Remove ALL environments and reset base
./nuke_conda_envs.sh

# With backup first
./nuke_conda_envs.sh --backup

# Non-interactive (skip confirmation)
./nuke_conda_envs.sh --yes --backup
```

This script:
1. Deletes all non-base environments
2. Removes all packages from base (except core)
3. Updates conda to latest version
4. Cleans all caches

---

## Jupyter Integration

### Managing Jupyter Kernels

**List all kernels:**

```bash
# List all Jupyter kernels and their status
./manage_jupyter_kernels.sh list

# Shows: kernel name, status (valid/orphaned), Python path
```

**Register environments:**

```bash
conda activate myenv

# Register active environment
./manage_jupyter_kernels.sh add

# Register specific environment
./manage_jupyter_kernels.sh add myenv

# Register with custom display name
./manage_jupyter_kernels.sh add myenv --display-name "My ML Project"
```

**Remove kernels:**

```bash
# Remove specific kernel
./manage_jupyter_kernels.sh remove myenv

# Non-interactive removal
./manage_jupyter_kernels.sh remove myenv --yes
```

**Clean orphaned kernels:**

```bash
# Remove all kernels pointing to deleted environments
./manage_jupyter_kernels.sh clean

# Non-interactive cleanup
./manage_jupyter_kernels.sh clean --yes
```

**Sync all environments:**

```bash
# Register ALL conda environments as Jupyter kernels
./manage_jupyter_kernels.sh sync

# Automatically installs ipykernel where needed
# Non-interactive sync
./manage_jupyter_kernels.sh sync --yes
```

---

## Diagnostics & Health

### Comprehensive Health Check

Check environment health with detailed diagnostics:

```bash
conda activate myenv

# Full health check
./health_check.sh

# Quick check (skip detailed analysis)
./health_check.sh --quick

# Check specific environment
./health_check.sh myenv

# GPU/CUDA check only
./health_check.sh --gpu-only

# Verbose output
./health_check.sh --verbose
```

**What it checks:**
- ✅ GPU/CUDA/cuDNN configuration
- ✅ CUDA driver vs toolkit versions
- ✅ PyTorch/TensorFlow GPU availability
- ✅ Python version and core packages
- ✅ ML framework versions
- ✅ Package conflicts (conda/pip duplicates)
- ✅ Known problematic combinations
- ✅ Jupyter kernel registration
- ✅ Disk space usage
- ✅ Package count statistics
- ✅ Overall health score (0-100%)

**Example output:**

```
═══════════════════════════════════════════════════════════
  Health Score: 95% - EXCELLENT
═══════════════════════════════════════════════════════════

Checks performed: 18
Passed: 17
Warnings: 1
Failed: 0
```

### Comparing Environments

Use `env_diff.sh` to compare two environments and identify differences:

```bash
# Compare two environments
./env_diff.sh env1 env2

# Show detailed version differences
./env_diff.sh env1 env2 --detailed

# Export diff report to file
./env_diff.sh env1 env2 --export diff_report.txt

# Show sync commands to make env2 match env1
./env_diff.sh env1 env2 --sync

# Combine options
./env_diff.sh prod dev --detailed --sync --export
```

**What it shows:**
- ✅ Packages only in environment 1
- ✅ Packages only in environment 2
- ✅ Version mismatches between common packages
- ✅ Differences in both conda and pip packages
- ✅ Summary statistics
- ✅ Optional: Sync commands to reconcile differences

**Perfect for:** Team synchronization, validating clones, debugging environment discrepancies, creating migration plans

### Managing Conda Channels

Use `channel_manager.sh` to manage conda channel priorities and configurations:

```bash
# List channels for current/global configuration
./channel_manager.sh list

# List channels for specific environment
./channel_manager.sh list myenv

# Add a channel globally
./channel_manager.sh add conda-forge

# Add channel to specific environment
./channel_manager.sh add conda-forge myenv

# Remove a channel
./channel_manager.sh remove conda-forge

# Set channel as highest priority
./channel_manager.sh priority conda-forge myenv

# Reset to default channels
./channel_manager.sh reset
./channel_manager.sh reset myenv

# Detect channel conflicts in environment
./channel_manager.sh detect-conflicts myenv
```

**What it does:**
- ✅ List configured channels with priorities
- ✅ Add/remove channels globally or per-environment
- ✅ Change channel priorities (prepend to highest)
- ✅ Reset to default channel configuration
- ✅ Detect common channel conflicts (conda-forge + defaults mix)
- ✅ Suggest optimal channel configurations

**Perfect for:** Resolving package conflicts, managing channel priorities, team channel standards, debugging installation issues

---

## Common Workflows

### Starting a New Project

```bash
# 1. Create environment from template
./create_ml_env.sh myproject --template pytorch-gpu --register-kernel

# 2. Activate and check health
conda activate myproject
./health_check.sh

# 3. Install additional packages safely
./safe_install.sh wandb tensorboard --dry-run
./safe_install.sh wandb tensorboard

# 4. Export for team members
./export_env.sh --file-yml myproject-env.yml
```

### Regular Maintenance and Updates

```bash
conda activate myenv

# 1. Check for and apply updates intelligently
./smart_update.sh --verbose --check-duplicates

# 2. Review what was updated
conda list --revisions

# 3. Verify environment health
./health_check.sh

# 4. Export updated environment
./export_env.sh

# If issues arise, rollback easily
./conda_rollback.sh
```

### Setting Up on New Machine

```bash
# 1. Sync from exported specs
conda create -n myproject python=3.10
conda activate myproject
./sync_env.sh --yml myproject-env.yml --req requirements.txt

# 2. Register Jupyter kernel
./manage_jupyter_kernels.sh add

# 3. Verify everything works
./health_check.sh
```

### Fixing Broken Environment

```bash
conda activate broken-env

# Option 1: Rollback recent changes
./conda_rollback.sh

# Option 2: Check for conflicts and fix
./find_duplicates.sh --fix
./health_check.sh

# Option 3: Nuclear option - start fresh
./export_env.sh --file-yml backup.yml  # Backup first!
./clean_env.sh
./sync_env.sh --yml backup.yml
```

### Switching ML Frameworks

```bash
# Option 1: Clone and modify
./clone_env.sh pytorch-env tensorflow-env --swap-framework pytorch->tensorflow

# Option 2: Clean and rebuild
conda activate pytorch-env
./export_env.sh --file-yml backup.yml
./clean_env.sh
# Manually edit backup.yml to change framework
./sync_env.sh --yml backup.yml
```

### Upgrading Python Version

```bash
# Clone with new Python version
./clone_env.sh myenv myenv-py311 --python 3.11

# Test new environment
conda activate myenv-py311
./health_check.sh

# If good, delete old environment
conda env remove -n myenv
```

### Preparing for GPU Training

```bash
# 1. Clone CPU env as GPU
./clone_env.sh myenv-cpu myenv-gpu --cpu-to-gpu

# 2. Check GPU setup
conda activate myenv-gpu
./health_check.sh --gpu-only

# 3. Test GPU access
python -c "import torch; print(torch.cuda.is_available())"
```

---

## Best Practices

### 🎯 Environment Management

1. **One environment per project** - Avoid sharing environments between projects
2. **Use templates** - Start with `create_ml_env.sh` templates for consistency
3. **Export regularly** - Run `export_env.sh` after major changes
4. **Version control specs** - Commit `environment.yml` and `requirements.txt` to git
5. **Name descriptively** - Use project names, not generic names like "ml" or "pytorch"

### 💾 Backup & Recovery

1. **Before major changes** - Always run `export_env.sh` first
2. **Test with dry-run** - Use `--dry-run` flag when installing packages
3. **Use safe_install.sh** - Automatic snapshots enable easy rollback
4. **Check revisions** - Run `conda list --revisions` to see history

### 🔧 Package Installation

1. **Prefer conda over pip** - Use conda for core packages, pip for others
2. **Avoid mixing** - Run `find_duplicates.sh` regularly
3. **Preview changes** - Always use `--dry-run` first
4. **Install related packages together** - Better dependency resolution
5. **Pin critical versions** - Use `package=version` for reproducibility

### 🏥 Health & Maintenance

1. **Regular health checks** - Run `health_check.sh` after major changes
2. **Clean orphaned kernels** - Run `manage_jupyter_kernels.sh clean` periodically
3. **Monitor disk space** - Large environments add up quickly
4. **Clean conda cache** - Run `conda clean --all` occasionally
5. **Remove unused environments** - Don't hoard old environments

### 🎓 Jupyter Workflows

1. **Register kernels** - Always use `manage_jupyter_kernels.sh` for consistency
2. **Clean orphaned kernels** - After deleting environments
3. **Descriptive names** - Use `--display-name` for clarity
4. **Verify registration** - Check with `manage_jupyter_kernels.sh list`

---

## Troubleshooting

### "Should I update this package?"

```bash
# Use smart_update.sh for risk analysis
./smart_update.sh --verbose

# Reviews each update with:
# - Version change type (major/minor/patch)
# - Dependency impact
# - Security advisories
# - Interactive approval
```

### "Package X conflicts with Y"

```bash
# Check for conda/pip duplicates
./find_duplicates.sh --fix

# Try installing separately
./safe_install.sh packageX --dry-run
./safe_install.sh packageX
```

### "CUDA version mismatch"

```bash
# Check your setup
./health_check.sh --gpu-only

# Shows CUDA driver vs toolkit versions
# Reinstall with correct CUDA version
```

### "Jupyter kernel not found"

```bash
# List all kernels
./manage_jupyter_kernels.sh list

# Clean orphaned kernels
./manage_jupyter_kernels.sh clean

# Re-register environment
./manage_jupyter_kernels.sh add myenv
```

### "Environment is broken"

```bash
# Try rollback first
./conda_rollback.sh

# If that fails, check conflicts
./health_check.sh
./find_duplicates.sh --fix

# Nuclear option: rebuild from export
./export_env.sh --file-yml backup.yml
conda env remove -n myenv
conda env create -n myenv -f backup.yml
```

### "Disk space issues"

```bash
# Check environment size
du -sh ~/miniconda3/envs/*

# Clean conda cache
conda clean --all

# Remove unused environments
conda env list
conda env remove -n unused-env
```

### "ImportError even though package is installed"

```bash
# Check for conflicts
./find_duplicates.sh

# Verify installation
conda activate myenv
python -c "import problematic_package"

# Reinstall if needed
pip uninstall problematic_package
./safe_install.sh problematic_package
```

---

## Requirements

### Core Dependencies
- **Conda/Miniconda** - Required for all scripts
- **Bash 4.0+** - Standard on most Linux/macOS systems
- **Python 3.8+** - Managed by conda

### Optional Dependencies
- **Poetry** - Required only for `poetry_bind_conda.sh` and `clean_poetry_env.sh`
- **Jupyter** - Required only for `manage_jupyter_kernels.sh`
- **NVIDIA drivers** - Required for GPU-enabled templates
- **Standard Unix tools** - grep, sed, awk (usually pre-installed)

---

## Contributing

Found a bug or have a suggestion? This is a personal toolkit, but feedback is welcome!

---

## License

These scripts are provided as-is for personal and professional use. Modify and distribute freely.

---

## Quick Reference

### Most Used Commands

```bash
# Create new environment
./create_ml_env.sh <name> --template <template>

# Update packages intelligently
./smart_update.sh
./smart_update.sh --verbose --check-duplicates

# Install packages safely
./safe_install.sh <packages> --dry-run
./safe_install.sh <packages>

# Check environment health
./health_check.sh

# Export environment
./export_env.sh

# Manage Jupyter kernels
./manage_jupyter_kernels.sh list
./manage_jupyter_kernels.sh add

# Clone environment
./clone_env.sh <source> <target> [options]

# Find conflicts
./find_duplicates.sh --fix
```

### Emergency Commands

```bash
# Rollback last change
./conda_rollback.sh

# Clean and rebuild
./export_env.sh --file-yml backup.yml
./clean_env.sh
./sync_env.sh --yml backup.yml

# Complete reset (nuclear option)
./nuke_conda_envs.sh --backup
```

---

**Happy environment managing! 🐍🚀**
