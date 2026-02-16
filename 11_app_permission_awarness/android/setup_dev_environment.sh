#!/bin/bash

# ============================================================================
# Android Permission App - Development Environment Auto-Setup
# ============================================================================
# This script automatically installs all dependencies and sets up the
# development environment for this Android project on a new PC.
#
# Usage: ./setup_dev_environment.sh [OPTIONS]
#
# Options:
#   --skip-sdk         Skip Android SDK installation (use existing)
#   --skip-icons       Skip icon generation
#   --skip-build       Skip building the APK
#   --skip-python      Skip Python dependencies
#   --force-sdk        Force re-download of Android SDK even if exists
#   --yes, -y          Skip all prompts and use defaults
#   --help, -h         Show this help message
#
# Examples:
#   ./setup_dev_environment.sh                    # Full setup with prompts
#   ./setup_dev_environment.sh --yes              # Full setup without prompts
#   ./setup_dev_environment.sh --skip-sdk         # Skip SDK setup (use existing)
#   ./setup_dev_environment.sh --skip-build       # Only install deps, don't build
# ============================================================================

set -e  # Exit on any error

# ============================================================================
# Configuration
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Project paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Android SDK configuration
ANDROID_SDK_DIR="$HOME/.android-sdk"
ANDROID_SDK_CMDLINE_TOOLS="$ANDROID_SDK_DIR/cmdline-tools"
ANDROID_SDK_LATEST="$ANDROID_SDK_CMDLINE_TOOLS/latest"

# SDK versions to install
SDK_PLATFORM_VERSION="34"
SDK_BUILD_TOOLS_VERSION="34.0.0"
SDK_CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# Java version
JAVA_VERSION_REQUIRED="17"

# Python requirements
PYTHON_VERSION_REQUIRED="3.8"

# Default options
SKIP_SDK=false
SKIP_ICONS=false
SKIP_BUILD=false
SKIP_PYTHON=false
FORCE_SDK=false
AUTO_YES=false

# ============================================================================
# Utility Functions
# ============================================================================

print_banner() {
    echo -e "${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        📱 Android Permission App - Dev Environment Setup       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    echo -e "${BOLD}${BLUE}━━━ Step $1: $2 ━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        print_info "Detected OS: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_info "Detected OS: macOS"
        SDK_CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
        print_info "Detected OS: Windows"
        SDK_CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    else
        OS="unknown"
        print_warning "Unknown OS: $OSTYPE, will try Linux commands"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prompt user for confirmation
confirm() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
            return 1
        fi
    else
        read -p "$prompt [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    return 0
}

# ============================================================================
# System Checks
# ============================================================================

check_system_requirements() {
    print_step "1" "Checking System Requirements"
    echo ""
    
    # Check OS
    detect_os
    
    # Check for required commands
    local missing_cmds=""
    
    if ! command_exists curl; then
        missing_cmds="$missing_cmds curl"
    fi
    
    if ! command_exists wget; then
        missing_cmds="$missing_cmds wget"
    fi
    
    if ! command_exists unzip; then
        missing_cmds="$missing_cmds unzip"
    fi
    
    if [ -n "$missing_cmds" ]; then
        print_warning "Missing basic tools:$missing_cmds"
        if confirm "Install these tools?" "y"; then
            install_system_tools
        else
            print_error "Cannot proceed without these tools."
            exit 1
        fi
    else
        print_success "All basic tools available"
    fi
    
    echo ""
}

install_system_tools() {
    print_info "Installing basic system tools..."
    
    if [ "$OS" = "linux" ]; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y curl wget unzip
        elif command_exists dnf; then
            sudo dnf install -y curl wget unzip
        elif command_exists yum; then
            sudo yum install -y curl wget unzip
        elif command_exists pacman; then
            sudo pacman -S curl wget unzip
        fi
    elif [ "$OS" = "macos" ]; then
        # macOS usually has these, but ensure homebrew is available
        if ! command_exists brew; then
            print_warning "Homebrew not found. Please install manually from https://brew.sh"
        fi
    fi
    
    print_success "System tools installed"
}

# ============================================================================
# Java Setup
# ============================================================================

check_java() {
    print_step "2" "Checking Java Installation"
    echo ""
    
    if command_exists java; then
        local java_version
        java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        print_success "Java found (version: $java_version)"
        
        if [ "$java_version" -ge "$JAVA_VERSION_REQUIRED" ]; then
            print_success "Java version is compatible (required: $JAVA_VERSION_REQUIRED+)"
        else
            print_warning "Java version is older than recommended"
            if confirm "Install Java $JAVA_VERSION_REQUIRED?" "y"; then
                install_java
            fi
        fi
    else
        print_warning "Java not found"
        if confirm "Install Java $JAVA_VERSION_REQUIRED?" "y"; then
            install_java
        else
            print_error "Java is required for Android development"
            exit 1
        fi
    fi
    
    # Set JAVA_HOME if not set
    if [ -z "$JAVA_HOME" ]; then
        local java_path
        java_path=$(which java)
        if [ -n "$java_path" ]; then
            JAVA_HOME=$(dirname $(dirname $(readlink -f "$java_path")))
            export JAVA_HOME
            print_info "Set JAVA_HOME to: $JAVA_HOME"
        fi
    fi
    
    echo ""
}

install_java() {
    print_info "Installing Java $JAVA_VERSION_REQUIRED..."
    
    if [ "$OS" = "linux" ]; then
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y openjdk-17-jdk
        elif command_exists dnf; then
            sudo dnf install -y java-17-openjdk-devel
        elif command_exists yum; then
            sudo yum install -y java-17-openjdk-devel
        elif command_exists pacman; then
            sudo pacman -S jdk17-openjdk
        fi
    elif [ "$OS" = "macos" ]; then
        if command_exists brew; then
            brew install openjdk@17
            sudo ln -sf $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk || true
        else
            print_error "Please install Java manually from https://adoptium.net"
            exit 1
        fi
    fi
    
    # Update alternatives
    if command_exists update-alternatives; then
        sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
    fi
    
    print_success "Java $JAVA_VERSION_REQUIRED installed"
}

# ============================================================================
# Python Setup
# ============================================================================

check_python() {
    if [ "$SKIP_PYTHON" = true ]; then
        print_info "Skipping Python check (--skip-python)"
        return 0
    fi
    
    print_step "3" "Checking Python Installation"
    echo ""
    
    if command_exists python3; then
        local python_version
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        print_success "Python 3 found (version: $python_version)"
        
        local major minor
        major=$(echo "$python_version" | cut -d'.' -f1)
        minor=$(echo "$python_version" | cut -d'.' -f2)
        
        if [ "$major" -ge 3 ] && [ "$minor" -ge 8 ]; then
            print_success "Python version is compatible (required: $PYTHON_VERSION_REQUIRED+)"
        else
            print_warning "Python version is older than recommended"
        fi
    else
        print_warning "Python 3 not found"
        if confirm "Install Python 3?" "y"; then
            install_python
        else
            print_warning "Skipping Python installation (icon generation may fail)"
        fi
    fi
    
    echo ""
}

install_python() {
    print_info "Installing Python 3..."
    
    if [ "$OS" = "linux" ]; then
        if command_exists apt-get; then
            sudo apt-get install -y python3 python3-pip
        elif command_exists dnf; then
            sudo dnf install -y python3 python3-pip
        elif command_exists yum; then
            sudo yum install -y python3 python3-pip
        elif command_exists pacman; then
            sudo pacman -S python python-pip
        fi
    elif [ "$OS" = "macos" ]; then
        if command_exists brew; then
            brew install python@3.11
        fi
    fi
    
    print_success "Python 3 installed"
}

install_python_dependencies() {
    if [ "$SKIP_PYTHON" = true ]; then
        print_info "Skipping Python dependencies (--skip-python)"
        return 0
    fi
    
    print_info "Installing Python dependencies from requirements.txt..."
    
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        if command_exists pip3; then
            pip3 install -r "$PROJECT_DIR/requirements.txt"
            print_success "Python dependencies installed"
        elif command_exists pip; then
            pip install -r "$PROJECT_DIR/requirements.txt"
            print_success "Python dependencies installed"
        else
            print_warning "pip not found, cannot install Python dependencies"
        fi
    else
        print_warning "requirements.txt not found"
    fi
}

# ============================================================================
# Android SDK Setup
# ============================================================================

setup_android_sdk() {
    if [ "$SKIP_SDK" = true ]; then
        print_info "Skipping Android SDK setup (--skip-sdk)"
        return 0
    fi
    
    print_step "4" "Setting Up Android SDK"
    echo ""
    
    # Check if SDK is already installed
    if [ -d "$ANDROID_SDK_LATEST" ] && [ "$FORCE_SDK" = false ]; then
        print_success "Android SDK already installed at: $ANDROID_SDK_DIR"
    else
        # Download and install Android SDK command line tools
        print_info "Downloading Android SDK command line tools..."
        
        # Create SDK directory
        mkdir -p "$ANDROID_SDK_DIR"
        cd "$ANDROID_SDK_DIR"
        
        # Download command line tools
        local sdk_zip="cmdline-tools.zip"
        echo -e "${CYAN}Downloading from: $SDK_CMDLINE_TOOLS_URL${NC}"
        
        if command_exists curl; then
            curl -L -o "$sdk_zip" "$SDK_CMDLINE_TOOLS_URL"
        elif command_exists wget; then
            wget -O "$sdk_zip" "$SDK_CMDLINE_TOOLS_URL"
        fi
        
        if [ -f "$sdk_zip" ]; then
            print_success "Downloaded command line tools"
            
            # Extract
            print_info "Extracting..."
            unzip -q "$sdk_zip"
            
            # Create latest directory structure
            mkdir -p "$ANDROID_SDK_CMDLINE_TOOLS"
            mv cmdline-tools "$ANDROID_SDK_CMDLINE_TOOLS/latest"
            
            # Clean up zip
            rm "$sdk_zip"
            
            print_success "Android SDK command line tools installed"
        else
            print_error "Failed to download Android SDK command line tools"
            exit 1
        fi
    fi
    
    # Set environment variables
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    # Accept licenses and install SDK components
    print_info "Accepting Android SDK licenses..."
    yes | sdkmanager --licenses >/dev/null 2>&1 || true
    
    print_info "Installing Android SDK components..."
    print_info "  - Platform: Android $SDK_PLATFORM_VERSION"
    print_info "  - Build Tools: $SDK_BUILD_TOOLS_VERSION"
    print_info "  - Platform Tools"
    
    sdkmanager "platforms;android-$SDK_PLATFORM_VERSION" \
               "build-tools;$SDK_BUILD_TOOLS_VERSION" \
               "platform-tools"
    
    print_success "Android SDK components installed"
    
    # Return to project directory
    cd "$PROJECT_DIR"
    
    echo ""
}

configure_local_properties() {
    print_step "5" "Configuring Project Settings"
    echo ""
    
    # Set ANDROID_HOME in local.properties
    local android_sdk_path="$ANDROID_SDK_DIR"
    
    if [ -n "$ANDROID_HOME" ]; then
        android_sdk_path="$ANDROID_HOME"
    fi
    
    # Check if local.properties exists and has correct SDK path
    if [ -f "$PROJECT_DIR/local.properties" ]; then
        local current_sdk_path
        current_sdk_path=$(grep "^sdk.dir=" "$PROJECT_DIR/local.properties" | cut -d'=' -f2- | tr -d '[:space:]')
        
        if [ "$current_sdk_path" != "$android_sdk_path" ]; then
            print_info "Updating SDK path in local.properties"
            sed -i "s|sdk.dir=.*|sdk.dir=$android_sdk_path|" "$PROJECT_DIR/local.properties"
        else
            print_success "SDK path already configured correctly"
        fi
    else
        print_info "Creating local.properties with SDK path"
        echo "sdk.dir=$android_sdk_path" > "$PROJECT_DIR/local.properties"
    fi
    
    # Make gradlew executable
    if [ -f "$PROJECT_DIR/gradlew" ]; then
        chmod +x "$PROJECT_DIR/gradlew"
        print_success "Made gradlew executable"
    fi
    
    echo ""
}

# ============================================================================
# Icon Generation
# ============================================================================

generate_icons() {
    if [ "$SKIP_ICONS" = true ]; then
        print_info "Skipping icon generation (--skip-icons)"
        return 0
    fi
    
    print_step "6" "Generating App Icons"
    echo ""
    
    # Check if icons already exist
    local icon_count
    icon_count=$(find "$PROJECT_DIR/app/src/main/res" -name "ic_launcher.png" 2>/dev/null | wc -l)
    
    if [ "$icon_count" -ge 5 ]; then
        print_success "App icons already exist ($icon_count icon files found)"
        return 0
    fi
    
    # Check Python and Pillow
    if ! command_exists python3; then
        print_warning "Python not found, skipping icon generation"
        return 0
    fi
    
    print_info "Generating launcher icons..."
    cd "$PROJECT_DIR"
    python3 generate_icons.py
    
    if [ $? -eq 0 ]; then
        print_success "App icons generated successfully"
    else
        print_warning "Icon generation failed (this is not critical)"
    fi
    
    echo ""
}

# ============================================================================
# Build APK
# ============================================================================

build_apk() {
    if [ "$SKIP_BUILD" = true ]; then
        print_info "Skipping APK build (--skip-build)"
        return 0
    fi
    
    print_step "7" "Building APK"
    echo ""
    
    # Ensure Gradle wrapper is available
    if [ ! -f "$PROJECT_DIR/gradlew" ]; then
        print_error "gradlew not found!"
        exit 1
    fi
    
    # Build the APK
    print_info "Building debug APK..."
    cd "$PROJECT_DIR"
    
    ./gradlew assembleDebug --no-daemon
    
    if [ $? -eq 0 ]; then
        local apk_path="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"
        if [ -f "$apk_path" ]; then
            local apk_size
            apk_size=$(du -h "$apk_path" | cut -f1)
            print_success "APK built successfully!"
            print_info "APK location: $apk_path"
            print_info "APK size: $apk_size"
        else
            print_warning "Build completed but APK not found at expected location"
        fi
    else
        print_error "APK build failed!"
        exit 1
    fi
    
    echo ""
}

# ============================================================================
# Run Tests
# ============================================================================

run_tests() {
    print_step "8" "Running Tests"
    echo ""
    
    print_info "Running unit tests..."
    cd "$PROJECT_DIR"
    ./gradlew test --no-daemon
    
    if [ $? -eq 0 ]; then
        print_success "All tests passed!"
    else
        print_warning "Some tests failed (this may be expected)"
    fi
    
    echo ""
}

# ============================================================================
# Final Summary
# ============================================================================

show_summary() {
    print_step "9" "Setup Complete!"
    echo ""
    
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                    ✅ Setup Complete!                          ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}Installed/Configured:${NC}"
    echo "  • Java JDK $JAVA_VERSION_REQUIRED"
    echo "  • Android SDK with platform $SDK_PLATFORM_VERSION"
    echo "  • Gradle wrapper"
    echo ""
    
    echo -e "${CYAN}Environment Variables (add to ~/.bashrc or ~/.zshrc):${NC}"
    echo -e "  ${YELLOW}export ANDROID_HOME=\"$ANDROID_SDK_DIR\"${NC}"
    echo -e "  ${YELLOW}export ANDROID_SDK_ROOT=\"$ANDROID_SDK_DIR\"${NC}"
    echo -e "  ${YELLOW}export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH\"${NC}"
    echo ""
    
    if [ -n "$JAVA_HOME" ]; then
        echo -e "${CYAN}Java:${NC}"
        echo -e "  ${YELLOW}export JAVA_HOME=\"$JAVA_HOME\"${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}Quick Commands:${NC}"
    echo "  Build APK:      ${YELLOW}./gradlew assembleDebug${NC}"
    echo "  Install to dev: ${YELLOW}./gradlew installDebug${NC}"
    echo "  Run app runner: ${YELLOW}./run_app.sh${NC}"
    echo ""
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Connect your Android device via USB"
    echo "  2. Enable USB debugging in Developer Options"
    echo "  3. Run: ${YELLOW}./run_app.sh${NC} or ${YELLOW}./gradlew installDebug${NC}"
    echo ""
}

# ============================================================================
# Help Function
# ============================================================================

show_help() {
    echo -e "${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        Android Permission App - Dev Environment Setup          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  --skip-sdk       Skip Android SDK installation (use existing)"
    echo "  --skip-icons     Skip app icon generation"
    echo "  --skip-build     Skip building the APK"
    echo "  --skip-python    Skip Python and pip dependencies"
    echo "  --force-sdk      Force re-download Android SDK"
    echo "  --yes, -y        Skip all prompts and use defaults"
    echo "  --help, -h       Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0                    # Full setup with prompts"
    echo "  $0 --yes              # Full setup without prompts"
    echo "  $0 --skip-sdk         # Skip SDK, use existing installation"
    echo "  $0 --skip-build       # Only install deps, don't build"
    echo ""
}

# ============================================================================
# Parse Arguments
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-sdk)
                SKIP_SDK=true
                shift
                ;;
            --skip-icons)
                SKIP_ICONS=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-python)
                SKIP_PYTHON=true
                shift
                ;;
            --force-sdk)
                FORCE_SDK=true
                shift
                ;;
            --yes|-y)
                AUTO_YES=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show banner
    print_banner
    
    # Run setup steps
    check_system_requirements
    check_java
    check_python
    setup_android_sdk
    configure_local_properties
    install_python_dependencies
    generate_icons
    build_apk
    
    # Show summary
    show_summary
}

# Run main function
main "$@"

