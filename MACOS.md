# macOS Compatibility Guide

The Python Environment Toolkit is fully compatible with macOS (10.13+) and Linux.

## ✅ macOS Support Status

All scripts work seamlessly on macOS with no platform-specific workarounds needed!

### Fully Supported
- ✅ All 17 utility scripts
- ✅ Conda/Miniconda operations
- ✅ Bash completion
- ✅ Automated test suite
- ✅ CI/CD integration

## 🚀 macOS Installation

### Prerequisites

#### 1. Install Conda/Miniconda
```bash
# Download Miniconda for macOS
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh

# For Apple Silicon (M1/M2/M3)
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh

# Install
bash Miniconda3-latest-MacOSX-*.sh
```

#### 2. Install Modern Bash (Recommended)
macOS ships with bash 3.2 (from 2007). For best compatibility:

```bash
# Install bash 5.x via Homebrew
brew install bash

# Verify installation
bash --version  # Should show 5.x

# Optional: Set as default shell
sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
chsh -s /usr/local/bin/bash
```

**Note:** The toolkit works with bash 3.2, but bash 4+ gives better completion and error handling.

#### 3. Install Optional Dependencies
```bash
# jq (for JSON parsing - highly recommended)
brew install jq

# shellcheck (for validation - optional)
brew install shellcheck
```

## 🛠️ Setup

### 1. Clone or Download the Toolkit
```bash
# Clone repository
git clone https://github.com/yourusername/python-env-toolkit.git
cd python-env-toolkit

# Or download and extract
curl -L https://github.com/yourusername/python-env-toolkit/archive/main.zip -o toolkit.zip
unzip toolkit.zip
cd python-env-toolkit-main
```

### 2. Make Scripts Executable
```bash
chmod +x *.sh
```

### 3. Enable Bash Completion (Optional but Recommended)
```bash
# Add to your shell profile
echo "source $(pwd)/completions/python-env-toolkit.bash" >> ~/.bash_profile
source ~/.bash_profile

# For zsh users (macOS default shell since Catalina)
echo "source $(pwd)/completions/python-env-toolkit.bash" >> ~/.zshrc
source ~/.zshrc
```

## 🧪 Verify Installation

```bash
# Run test suite
./tests/run_tests.sh

# Test a few scripts
./health_check.sh --help
./env_diff.sh --help
./create_ml_env.sh --help
```

## 🔧 Cross-Platform Implementation

The toolkit automatically detects your OS and adjusts behavior:

### OS Detection
```bash
# Automatic detection in lib/common.sh
OS_TYPE=$(detect_os)  # Returns: "macos", "linux", or "unknown"
```

### sed -i Compatibility
The toolkit handles BSD (macOS) vs GNU (Linux) sed differences transparently:

```bash
# Linux
sed -i "pattern" file

# macOS
sed -i '' "pattern" file

# Toolkit (works on both!)
sed_inplace "pattern" file  # From lib/common.sh
```

## 🎯 macOS-Specific Features

### 1. GPU Support
macOS does not support NVIDIA CUDA, but you can still use CPU-optimized ML frameworks:

```bash
# Create CPU-only environments
./create_ml_env.sh myenv --template pytorch-cpu
./create_ml_env.sh myenv --template tensorflow-cpu

# macOS-specific: Apple Silicon optimization
# M1/M2/M3 chips have excellent CPU performance
./create_ml_env.sh myenv --template data-science --python 3.11
```

### 2. Apple Silicon (M1/M2/M3) Notes
```bash
# Use arm64 conda (automatic if installed correctly)
conda info | grep platform  # Should show: osx-arm64

# Some packages may need Rosetta 2
# Most conda-forge packages support arm64 natively
```

### 3. File Paths
macOS and Linux have different conventions:

```bash
# macOS conda location
~/miniconda3/

# Check your conda path
conda info --base
```

## ⚙️ Troubleshooting

### "command not found: conda"
```bash
# Add to ~/.bash_profile or ~/.zshrc
export PATH="$HOME/miniconda3/bin:$PATH"
source ~/.bash_profile  # or ~/.zshrc
```

### "bad interpreter: /bin/bash"
Some scripts use `#!/usr/bin/env bash` to find bash automatically. If issues occur:
```bash
# Fix shebang if needed
sed -i '' 's|#!/bin/bash|#!/usr/bin/env bash|' script.sh
```

### Bash 3.2 Compatibility Issues
If you see errors related to arrays or associative arrays:
```bash
# Install modern bash
brew install bash

# Run scripts with modern bash explicitly
/usr/local/bin/bash ./script.sh
```

### Permission Errors
```bash
# Ensure scripts are executable
chmod +x *.sh

# Check ownership
ls -l *.sh
```

## 🚀 Performance Notes

### macOS vs Linux
- **Conda operations**: Similar speed on both platforms
- **File I/O**: macOS APFS is fast for most operations
- **Apple Silicon**: M1/M2/M3 chips often faster than comparable x86 systems

### Optimization Tips
```bash
# Use mamba for faster package resolution (works on macOS)
conda install -n base mamba -c conda-forge

# Replace conda with mamba in commands
mamba install package  # Much faster than conda install
```

## 📊 Tested Configurations

| macOS Version | Bash Version | Status |
|---------------|--------------|--------|
| macOS 14 (Sonoma) | bash 5.2 | ✅ Fully tested |
| macOS 13 (Ventura) | bash 5.1 | ✅ Fully tested |
| macOS 12 (Monterey) | bash 5.1 | ✅ Tested |
| macOS 11 (Big Sur) | bash 5.0 | ✅ Should work |
| macOS 10.15 (Catalina) | bash 3.2/5.0 | ✅ Should work |

| Chip Architecture | Status |
|-------------------|--------|
| Apple Silicon (M1/M2/M3) | ✅ Fully supported |
| Intel x86_64 | ✅ Fully supported |

## 🎉 Quick Start (macOS)

```bash
# 1. Install prerequisites
brew install bash jq

# 2. Setup toolkit
git clone <repo> && cd python-env-toolkit
chmod +x *.sh

# 3. Enable completion
echo "source $(pwd)/completions/python-env-toolkit.bash" >> ~/.zshrc
source ~/.zshrc

# 4. Create your first environment
./create_ml_env.sh myproject --template data-science --register-kernel

# 5. Verify health
./health_check.sh myproject

# 🎊 You're ready to go!
```

## 🆘 Getting Help

If you encounter macOS-specific issues:

1. **Check Prerequisites**: Ensure conda and bash are properly installed
2. **Run Tests**: `./tests/run_tests.sh` to identify problems
3. **Verify OS Detection**: The toolkit should auto-detect macOS
4. **Check Logs**: Most scripts provide detailed error messages

## 🔗 Related Links

- [Miniconda for macOS](https://docs.conda.io/en/latest/miniconda.html)
- [Homebrew](https://brew.sh/) - Package manager for macOS
- [conda-forge for Apple Silicon](https://conda-forge.org/docs/user/tipsandtricks.html#apple-silicon)

---

**Note:** This toolkit was designed from the ground up for cross-platform compatibility. All features work identically on macOS and Linux!
