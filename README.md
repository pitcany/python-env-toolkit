# Python Environment Management Toolkit

A comprehensive collection of Bash scripts for managing Python development environments with Conda, pip, and Poetry. Designed specifically for data scientists and machine learning engineers who need robust, reliable environment management.

## Table of Contents

- [Quick Start](#quick-start)
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
| **safe_install.sh** | Install with preview & rollback | Dry-run preview, automatic snapshots, instant rollback |
| **export_env.sh** | Export environment specs | YAML + requirements.txt, cross-platform compatible |
| **sync_env.sh** | Sync from YAML/requirements | Update packages, prune extras, maintain consistency |
| **find_duplicates.sh** | Detect conda/pip conflicts | Find & fix packages installed in both |

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
