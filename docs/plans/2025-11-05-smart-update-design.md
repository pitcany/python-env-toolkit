# Smart Update Script Design

**Date:** 2025-11-05
**Script Name:** `smart_update.sh`
**Purpose:** Intelligent package update assistant with risk-based decision making

## Overview

An interactive package update tool that analyzes available updates, calculates risk scores based on semantic versioning, dependency impacts, and security advisories, then guides users through approval decisions with configurable verbosity.

## Architecture & Workflow

### High-Level Flow

1. Detect active conda environment (or accept `--name` flag)
2. Query available updates from both conda and pip
3. For each package with an update available:
   - Calculate risk score (low/medium/high)
   - Present to user with configurable detail level
   - Wait for approve/skip/quit decision
4. Batch execute approved updates using existing `safe_install.sh` for automatic rollback points

### Risk Scoring Logic

**Components:**

1. **Semantic versioning analysis:**
   - Major bump (2.x → 3.x) = HIGH risk
   - Minor bump (2.1 → 2.2) = MEDIUM risk
   - Patch bump (2.1.1 → 2.1.2) = LOW risk

2. **Dependency impact modifier:**
   - 0 other packages affected: +0
   - 1-3 packages affected: +1 risk level
   - 4+ packages affected: +2 risk levels

3. **Security/bug fix modifier:**
   - Security fix detected: -1 risk level (min: LOW)
   - Check PyPI API for classifiers and vulnerability data

4. **Final score:** Combine all factors, clamp to LOW/MEDIUM/HIGH

### Integration with Existing Toolkit

- **Calls `safe_install.sh`** internally for each approved update (inherits dry-run preview and rollback)
- **Optional `find_duplicates.sh`** call before starting to ensure clean state
- **Optional `health_check.sh`** call after all updates complete

## Command-Line Interface

### Usage

```bash
# Interactive mode with default (compact) output
./smart_update.sh

# Verbose mode - detailed risk breakdown
./smart_update.sh --verbose

# Summary mode - minimal one-line output
./smart_update.sh --summary

# Target specific environment
./smart_update.sh --name myenv

# Additional options
./smart_update.sh --conda-only           # Only check conda packages
./smart_update.sh --pip-only             # Only check pip packages
./smart_update.sh --batch                # Show all updates first, then batch approval
./smart_update.sh --check-duplicates     # Run find_duplicates.sh first
./smart_update.sh --health-check-after   # Run health_check.sh after updates
./smart_update.sh --export-after         # Export environment after updates
./smart_update.sh --refresh              # Clear cache and refresh data
```

### Interactive Prompts

**Compact mode (default):**
```
📦 numpy: 1.24.3 → 1.26.4 [MEDIUM RISK]
   Reason: Minor version bump + 2 dependency changes

   [a]pprove  [s]kip  [d]etails  [q]uit:
```

**Summary mode (`--summary`):**
```
📦 numpy 1.24.3→1.26.4 [MED] Minor+deps | [a/s/d/q]:
```

**Verbose mode (`--verbose`):**
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

**The `[d]etails` option** toggles to verbose view temporarily for that package, then returns to default mode.

## Technical Implementation

### Update Detection

**Conda packages:**
```bash
# Get outdated packages
conda search --outdated --json
# Parse JSON to extract: package, current_version, available_version

# For each package, run dependency impact check
conda install --dry-run package=new_version --json
# Parse to see what else changes (upgrades, downgrades, new packages)
```

**Pip packages:**
```bash
# Get outdated packages
pip list --outdated --format=json
# Parse JSON for package, current, latest

# Dependency check using pip's dry-run
pip install --dry-run --report - package==new_version 2>/dev/null
# Parse install plan to see dependency changes
```

### Caching Strategy

- Cache PyPI API responses for 1 hour to avoid rate limiting
- Store in `/tmp/smart_update_cache_{env_name}/`
- Clear cache with `--refresh` flag

## Error Handling & Edge Cases

### Pre-flight Checks

- Verify conda environment is active (or `--name` points to valid env)
- Check for internet connectivity (needed for PyPI API calls)
- Ensure `safe_install.sh` is in same directory (for rollback capability)
- Warn if no updates available (don't fail, just inform and exit cleanly)

### Graceful Degradation

- **PyPI API unavailable:** Skip security checks, rely only on semver + dependency analysis
- **JSON parsing fails:** Fall back to text parsing where possible
- **Dry-run fails:** Show warning, mark as HIGH risk by default, let user decide
- **Cache corruption:** Delete cache and retry (don't fail entire operation)

### Edge Cases

**1. Package available from multiple channels:**
```
⚠️  pytorch available from: conda-forge (2.0.1), pytorch (2.1.0)
   Currently installed from: pytorch
   Which channel for update? [conda-forge/pytorch/skip]:
```

**2. Conflicting updates:**
```
🚫 Cannot update package_B to 2.1.0 (blocked by package_A dependency)
   Options: [s]kip B  [u]pdate A first  [q]uit
```

**3. Mixed conda/pip duplicates detected:**
```
⚠️  Found duplicates before updating. Recommend running:
   ./find_duplicates.sh --fix
   Continue anyway? [y/N]:
```

### Post-Update Actions

- Summary report: X approved, Y skipped, Z failed
- Optional: Run `health_check.sh --quick` after all updates
- Option to export updated environment: `--export-after`

## Testing Strategy

### Manual Test Scenarios

1. **Empty environment** - No updates available
2. **Single package update** - One patch-level update
3. **Multiple updates** - Mix of low/medium/high risk
4. **Security update** - Package with known CVE
5. **Breaking change** - Major version bump with dependency conflicts
6. **Network failure** - Simulate PyPI API unavailable
7. **User cancellation** - Press 'q' mid-workflow
8. **All approved** - Approve every update, verify batch execution
9. **Mixed conda/pip** - Environment with both package managers
10. **Invalid environment name** - `--name nonexistent`

### Integration with Existing Scripts

**Uses:**
- `safe_install.sh` - For actual package installation with rollback capability
- `find_duplicates.sh` - Optional pre-check (with `--check-duplicates` flag)
- `health_check.sh` - Optional post-update validation (with `--health-check-after` flag)

**Complements:**
- Run before `export_env.sh` to update then backup
- Alternative to manual `conda update` workflow
- Pairs with `conda_rollback.sh` if updates cause issues

## Design Principles

- **YAGNI:** No complex features like auto-update scheduling or email notifications
- **User control:** Interactive approval for all updates, no fully automated mode
- **Safety first:** Integrate with `safe_install.sh` for rollback capability
- **Graceful degradation:** Work even when external APIs are unavailable
- **Consistency:** Follow existing toolkit patterns (emojis, error handling, structure)
