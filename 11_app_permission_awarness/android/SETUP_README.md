# Development Environment Setup Guide

This document describes how to set up the development environment for the Android Permission App on a new PC.

## Quick Start (Automated Setup)

The easiest way to set up your development environment is to use the automated setup script:

```bash
# Make the script executable (if not already)
chmod +x setup_dev_environment.sh

# Run the full setup (includes Java, Android SDK, Python, icons, and build)
./setup_dev_environment.sh

# Or run with default answers (no prompts)
./setup_dev_environment.sh --yes
```

## Manual Setup (Step by Step)

If you prefer to set up manually or already have some dependencies installed:

### 1. Install Java JDK 17

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

**macOS:**
```bash
brew install openjdk@17
export JAVA_HOME=$(brew --prefix)/opt/openjdk@17
```

**Windows:**
Download from https://adoptium.net and install.

### 2. Install Android SDK

```bash
# Create SDK directory
mkdir -p $HOME/.android-sdk/cmdline-tools
cd $HOME/.android-sdk/cmdline-tools

# Download command line tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest
rm commandlinetools-linux-11076708_latest.zip

# Add to PATH
export ANDROID_HOME=$HOME/.android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# Accept licenses and install SDK components
yes | sdkmanager --licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0" "platform-tools"
```

### 3. Configure Project

```bash
# Set SDK path
echo "sdk.dir=$HOME/.android-sdk" > local.properties

# Make gradlew executable
chmod +x gradlew
```

### 4. Install Python Dependencies

```bash
pip3 install -r requirements.txt
```

### 5. Generate App Icons

```bash
python3 generate_icons.py
```

### 6. Build the APK

```bash
./gradlew assembleDebug
```

## Setup Script Options

The `setup_dev_environment.sh` script supports these options:

| Option | Description |
|--------|-------------|
| `--skip-sdk` | Skip Android SDK installation (use existing) |
| `--skip-icons` | Skip app icon generation |
| `--skip-build` | Skip building the APK |
| `--skip-python` | Skip Python and pip dependencies |
| `--force-sdk` | Force re-download Android SDK |
| `--yes, -y` | Skip all prompts and use defaults |
| `--help, -h` | Show help message |

### Usage Examples

```bash
# Full setup with prompts
./setup_dev_environment.sh

# Full setup without prompts
./setup_dev_environment.sh --yes

# Use existing SDK, skip icon generation
./setup_dev_environment.sh --skip-sdk --skip-icons

# Only install dependencies, don't build
./setup_dev_environment.sh --skip-build

# Force re-download Android SDK
./setup_dev_environment.sh --force-sdk
```

## What Gets Installed

The setup script automatically installs/configures:

1. **Java JDK 17** - Required for building Android apps
2. **Android SDK** - Includes:
   - Command line tools
   - Platform API 34
   - Build tools 34.0.0
   - Platform tools (ADB)
3. **Python 3** - If not present
4. **Python dependencies** - Pillow for icon generation
5. **App icons** - Generated in all required densities
6. **Gradle wrapper** - Made executable
7. **local.properties** - Configured with correct SDK path
8. **Debug APK** - Built and ready for installation

## Environment Variables

After running the setup script, add these to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
# Android SDK
export ANDROID_HOME="$HOME/.android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Java (adjust path for your system)
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
```

Then reload:
```bash
source ~/.bashrc  # or ~/.zshrc
```

## Verifying the Setup

After setup, verify everything is working:

```bash
# Check Java
java -version

# Check Android SDK
sdkmanager --list | head -20

# Check Gradle
./gradlew --version

# Build the project
./gradlew assembleDebug
```

## Troubleshooting

### "Java not found" error
- Make sure JAVA_HOME is set correctly
- Try: `export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))`

### "ANDROID_HOME is not set" error
- Make sure ANDROID_HOME is exported in your shell profile
- Run: `source ~/.bashrc` or restart your terminal

### "Permission denied" when running gradlew
- Make it executable: `chmod +x gradlew`

### "SDK location not found" error
- Ensure local.properties has the correct sdk.dir path
- Run: `echo "sdk.dir=$HOME/.android-sdk" > local.properties`

### Python/pip not found
- Install Python 3: `sudo apt install python3 python3-pip`
- Or use the setup script with `--yes` flag

### SDK download failures
- Check your internet connection
- Try running with `--force-sdk` to retry
- Manually download from: https://developer.android.com/studio#command-line-tools-only

## Next Steps

After successful setup:

1. **Connect your Android device** via USB
2. **Enable USB debugging** in Developer Options on your device
3. **Install and run the app**:
   ```bash
   ./gradlew installDebug      # Install on connected device
   ./run_app.sh               # Full workflow (install + monitor)
   ```

## Support

If you encounter issues:
1. Check the error messages in the terminal output
2. Ensure all prerequisites are met
3. Try running with `--yes` for default options
4. Check the INSTALL_GUIDE.md for additional information

