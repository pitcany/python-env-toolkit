# Example Workflows

This directory contains complete workflow examples that demonstrate how to chain multiple scripts together for common scenarios.

## Available Examples

### 1. new-ml-project.sh

**Purpose:** Complete workflow for setting up a new ML project environment from scratch.

**What it does:**
1. Interactive prompts for project name, template, and Python version
2. Creates environment using `create_ml_env.sh`
3. Installs additional packages with `safe_install.sh` (optional)
4. Exports environment specs with `export_env.sh` for version control
5. Registers Jupyter kernel with `manage_jupyter_kernels.sh`
6. Runs health check with `health_check.sh` to verify setup
7. Displays next steps and useful commands

**Usage:**

```bash
cd /path/to/python-env-toolkit
./examples/new-ml-project.sh
```

**Interactive prompts:**
- Project/Environment name
- Template selection (pytorch-gpu, tensorflow-cpu, data-science, etc.)
- Python version (default: 3.10)
- Additional packages (optional, comma-separated)

**Output:**
- New conda environment
- `environment.yml` and `requirements.txt` in current directory
- Registered Jupyter kernel
- Health check report
- Summary with next steps

**Example session:**

```
Project/Environment name: my-research
Select template (1-7): 1  # pytorch-gpu
Python version (default: 3.10): 3.11
Additional packages (comma-separated, or leave empty): wandb,tensorboard

# Script creates environment, installs packages, exports specs, etc.

✅ Environment 'my-research' is ready!

Next steps:
  1. Activate: conda activate my-research
  2. Start Jupyter: jupyter lab
  3. Verify GPU: python -c 'import torch; print(torch.cuda.is_available())'
  4. Add to git: git add environment.yml requirements.txt
```

---

### 2. fix-broken-env.sh

**Purpose:** Diagnostic and repair workflow for troubleshooting environment issues.

**What it does:**
1. Runs comprehensive health check with `health_check.sh`
2. Detects and fixes conda/pip conflicts with `find_duplicates.sh`
3. Examines conda revision history
4. Offers rollback option using `conda_rollback.sh`
5. Provides advanced repair options (export & clean)
6. Re-runs health check to verify fixes
7. Provides detailed next steps if issues remain

**Usage:**

```bash
cd /path/to/python-env-toolkit

# Option 1: With active environment
conda activate broken-env
./examples/fix-broken-env.sh

# Option 2: Specify environment
./examples/fix-broken-env.sh broken-env
```

**What it checks:**
- Environment health score
- GPU/CUDA configuration
- Package conflicts (conda/pip duplicates)
- Conda revision history
- ML framework availability

**Interactive options:**
- Fix conda/pip conflicts automatically
- Rollback to previous revision
- Export and clean environment (nuclear option)
- Manual exit for custom fixes

**Example session:**

```
Diagnosing environment: pytorch-old

▶ Step 1: Health Check
  ⚠️  Found issues: Health Score 65%
  ❌ PyTorch CUDA not available
  ⚠️  Found 3 conda/pip duplicates

▶ Step 2: Checking for Package Conflicts
  Found 3 package(s) installed in both conda and pip
  Fix conflicts? (y/N) y
  ✅ Conflicts resolved!

▶ Step 3: Checking Environment History
  Found 15 revision points
  Rollback? (y/N) n

▶ Step 5: Health Check - Verification
  ✅ Health Score: 92% - EXCELLENT

✅ Environment Fixed!
```

---

## How to Use These Examples

### As Learning Resources

Read the scripts to understand:
- How to chain multiple tools together
- Error handling patterns
- User interaction best practices
- Output formatting and color usage

### As Templates

Copy and modify for your own workflows:

```bash
# Copy example as starting point
cp examples/new-ml-project.sh examples/my-custom-workflow.sh

# Edit to add your specific requirements
nano examples/my-custom-workflow.sh
```

### As Direct Tools

Run them as-is for common scenarios - they're fully functional!

---

## Creating Your Own Workflows

Here's a template structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Get script directory (parent of examples/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Your workflow logic here
"$SCRIPT_DIR/health_check.sh" myenv
"$SCRIPT_DIR/safe_install.sh" pandas --yes
# ... etc
```

**Tips:**
1. Always use `$SCRIPT_DIR` to reference scripts (makes workflows portable)
2. Add error handling: `|| { echo "Failed"; exit 1; }`
3. Use `set -euo pipefail` for automatic error exits
4. Provide clear user feedback with colors and status messages
5. Add `--help` flag for documentation

---

## Common Workflow Patterns

### Pattern 1: Safe Experimentation

```bash
# Export current state
./export_env.sh --name myenv --file-yml backup.yml

# Try changes
./safe_install.sh new-experimental-package

# If it breaks, rollback
./conda_rollback.sh
```

### Pattern 2: Environment Migration

```bash
# Clone with modifications
./clone_env.sh old-env new-env --python 3.11 --cpu-to-gpu

# Verify new environment
./health_check.sh new-env

# Register for Jupyter
./manage_jupyter_kernels.sh add new-env
```

### Pattern 3: Team Onboarding

```bash
# Team member receives environment.yml
./sync_env.sh --yml environment.yml

# Register kernel
./manage_jupyter_kernels.sh add

# Verify setup
./health_check.sh
```

---

## Workflow Ideas

Here are more workflow scenarios you could implement:

1. **migrate-to-gpu.sh** - Clone CPU environment to GPU with validation
2. **upgrade-python.sh** - Safely upgrade Python version workflow
3. **reproduce-paper.sh** - Set up environment from research paper specs
4. **team-sync.sh** - Sync team's environments to match specs
5. **pre-training-check.sh** - Verify everything before starting long training
6. **cluster-prep.sh** - Prepare environment for deployment to cluster
7. **quarterly-cleanup.sh** - Audit and clean unused environments
8. **framework-benchmark.sh** - Compare PyTorch vs TensorFlow in identical envs

---

## Contributing Workflows

Have a useful workflow? Consider contributing it!

1. Create your workflow script in `examples/`
2. Make it executable: `chmod +x examples/your-workflow.sh`
3. Document it in this README
4. Test thoroughly
5. Submit a pull request

---

## Troubleshooting Examples

**"Cannot find toolkit scripts" error:**
- Ensure you're running from the toolkit directory or its examples/ subdirectory
- Check that parent directory contains the main scripts

**"Environment not found" error:**
- Verify environment name: `conda env list`
- Check for typos in environment name

**Scripts not working as expected:**
- Ensure all scripts are executable: `chmod +x *.sh`
- Check you're using bash (not sh): `bash --version`
- Verify conda is available: `conda --version`

---

**Happy workflow automation! 🚀**
