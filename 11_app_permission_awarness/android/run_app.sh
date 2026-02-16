#!/bin/bash

# Android Permission App - Automated Runner with WiFi Data Server
# This script can:
# 1. Install the APK, start monitoring, and open the app (default mode)
# 2. Act as a server to receive data from Android app (--server mode)

echo "=================================="
echo "Android Permission App Runner"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Server configuration
PORT=8080
DATA_DIR="/tmp/permission_data"

# Show help message
show_help() {
    echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --server [PORT]   Start as HTTP server to receive data from Android app"
    echo "  --help, -h        Show this help message"
    echo "  (no args)         Run in default mode: install APK and monitor permissions"
    echo ""
    echo "Examples:"
    echo "  $0                           # Default: install APK and monitor"
    echo "  $0 --server                  # Start server on port 8080"
    echo "  $0 --server 9000             # Start server on port 9000"
    echo ""
}

# Parse command line arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

if [[ "$1" == "--server" ]]; then
    if [[ -n "$2" ]]; then
        PORT="$2"
    fi
    # Start server mode
    echo -e "${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          📡 WiFi Data Server Mode                     ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Listening on port $PORT for incoming permission data...${NC}"
    echo -e "${CYAN}Android app should send data to this laptop's IP:$PORT${NC}"
    echo ""
    echo -e "${YELLOW}Instructions:${NC}"
    echo "1. Note this laptop's IP address"
    echo "2. On Android app, enter this IP in 'Server IP' field"
    echo "3. Tap 'Start Permission Requests' on Android"
    echo "4. Data will appear here in real-time with proper table format"
    echo ""
    
    # Create data directory
    mkdir -p "$DATA_DIR"
    
    # Create Python HTTP server script with beautiful table formatting
    cat > /tmp/server_script.py << 'PYTHON_SCRIPT'
import http.server
import socketserver
import json
import os
from datetime import datetime
import urllib.parse
import re

PORT = int(os.environ.get('PORT', 8080))
DATA_DIR = os.environ.get('DATA_DIR', '/tmp/permission_data')

class PermissionHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress default logging
    
    def do_GET(self):
        if self.path == '/test':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/data':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                
                # Extract data
                device_ip = data.get('device_ip', 'Unknown')
                permission = data.get('permission', 'Unknown')
                granted = data.get('granted', False)
                timestamp = data.get('timestamp', datetime.now().isoformat())
                raw_data = data.get('data', '')
                
                # Print beautiful header
                print("")
                print(f"{'━' * 80}")
                print(f"  📱 DEVICE: {device_ip}")
                print(f"  🔐 PERMISSION: {permission}")
                print(f"  ✅ STATUS: {'GRANTED' if granted else 'DENIED'}")
                print(f"  🕐 TIME: {timestamp}")
                print(f"{'━' * 80}")
                
                # Print RAW JSON data
                print(f"\n📄 RAW JSON DATA RECEIVED:")
                print(json.dumps(data, indent=2))
                print("")
                
                # Parse and display data in table format (only if granted)
                if raw_data and granted:
                    if "CONTACTS" in raw_data:
                        print_table_data("CONTACTS", raw_data)
                    elif "CALL LOG" in raw_data:
                        print_table_data("CALL LOG", raw_data)
                    elif "SMS" in raw_data:
                        print_table_data("SMS MESSAGES", raw_data)
                    elif "LOCATION" in raw_data:
                        print_table_data("LOCATION", raw_data)
                    elif "CAMERA" in raw_data:
                        print_table_data("CAMERA", raw_data)
                    elif "MICROPHONE" in raw_data:
                        print_table_data("MICROPHONE", raw_data)
                
                print(f"{GREEN}💾 Saved to: {DATA_DIR}/permission_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json{NC}")
                print(f"{CYAN}{'─' * 80}{NC}\n")
                
                # Save to file
                timestamp_file = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f"{DATA_DIR}/permission_{timestamp_file}.json"
                with open(filename, 'w') as f:
                    json.dump(data, f, indent=2)
                
                # Send success response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {"status": "success", "permission": permission}
                self.wfile.write(json.dumps(response).encode())
                
            except json.JSONDecodeError as e:
                print(f"{RED}❌ Error parsing JSON: {e}{NC}")
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'{"error": "Invalid JSON"}')
        else:
            self.send_response(404)
            self.end_headers()

def strip_ansi(text):
    """Remove ANSI escape codes for accurate length calculation"""
    return re.sub(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])', '', text)

def pad_line(line, width=76):
    """Pad line to specified width, accounting for ANSI codes"""
    stripped = strip_ansi(line)
    padding = ' ' * (width - len(stripped))
    return f"{line}{padding}"

def print_table_data(title, raw_data):
    """Print data in a beautiful table format"""
    print(f"\n  {BOLD}{MAGENTA}╔{'═' * 76}╗{NC}")
    header = pad_line(f"{BOLD}{CYAN}{title}{NC}")
    print(f"  {BOLD}{MAGENTA}║{NC} {header} {BOLD}{MAGENTA}║{NC}")
    print(f"  {BOLD}{MAGENTA}╠{'═' * 76}╣{NC}")
    
    lines = raw_data.split('\\n')
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        if line.startswith('===') or line.startswith('---') or line.startswith('Total'):
            padded = pad_line(f"{YELLOW}{line}{NC}")
            print(f"  {BOLD}{MAGENTA}║{NC} {padded} {BOLD}{MAGENTA}║{NC}")
        elif line.startswith('[') and ']' in line:
            padded = pad_line(f"{GREEN}{line}{NC}")
            print(f"  {BOLD}{MAGENTA}║{NC} {padded} {BOLD}{MAGENTA}║{NC}")
        elif 'INCOMING' in line or 'OUTGOING' in line or 'MISSED' in line:
            status_color = GREEN if 'INCOMING' in line or 'OUTGOING' in line else RED
            padded = pad_line(f"{status_color}{line}{NC}")
            print(f"  {BOLD}{MAGENTA}║{NC} {padded} {BOLD}{MAGENTA}║{NC}")
        elif 'RECEIVED' in line or 'SENT' in line:
            status_color = GREEN if 'RECEIVED' in line else CYAN
            padded = pad_line(f"{status_color}{line}{NC}")
            print(f"  {BOLD}{MAGENTA}║{NC} {padded} {BOLD}{MAGENTA}║{NC}")
        else:
            padded = pad_line(line)
            print(f"  {BOLD}{MAGENTA}║{NC} {padded} {BOLD}{MAGENTA}║{NC}")
    
    print(f"  {BOLD}{MAGENTA}╚{'═' * 76}╝{NC}")
    print("")

# Colors for terminal output
BOLD = '\033[1m'
GREEN = '\033[0;32m'
CYAN = '\033[0;36m'
YELLOW = '\033[1;33m'
MAGENTA = '\033[0;35m'
RED = '\033[0;31m'
NC = '\033[0m'

# Allow port reuse
socketserver.TCPServer.allow_reuse_address = True

with socketserver.TCPServer(("", PORT), PermissionHandler) as httpd:
    print(f"{GREEN}✅ Server started on http://0.0.0.0:{PORT}{NC}")
    print(f"{CYAN}📁 Data saved to: {DATA_DIR}{NC}")
    print("")
    print(f"{YELLOW}Waiting for data from Android app...{NC}")
    print(f"{YELLOW}(Press Ctrl+C to stop){NC}")
    print("")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print(f"\n{GREEN}🛑 Server stopped{NC}")
PYTHON_SCRIPT
    
    # Start the server
    PORT=$PORT DATA_DIR=$DATA_DIR python3 /tmp/server_script.py
    exit 0
fi

# ==================== DEFAULT MODE (Install APK and monitor) ====================

# Check if APK exists
APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
    echo -e "${YELLOW}APK not found. Building...${NC}"
    ./gradlew assembleDebug
    if [ ! -f "$APK_PATH" ]; then
        echo -e "${YELLOW}Build failed. Please check errors above.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ APK found: $APK_PATH${NC}"
echo ""

# Step 1: Check device connection
echo -e "${BLUE}Step 1: Checking device connection...${NC}"
adb devices
echo ""

# Check if device is connected
DEVICE_COUNT=$(adb devices | grep -c "device$")
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No device found! Please connect your Android device with USB debugging enabled.${NC}"
    echo ""
    echo "Instructions:"
    echo "1. Go to Settings > About Phone > Tap Build Number 7 times"
    echo "2. Go to Settings > Developer Options > Enable USB Debugging"
    echo "3. Connect device via USB and accept the debugging prompt"
    echo ""
    read -p "Press Enter after connecting device..."
    adb devices
fi

# Step 2: Install APK
echo -e "${BLUE}Step 2: Installing APK...${NC}"
adb install -r "$APK_PATH"
echo ""

# Step 3: Monitor permissions
echo -e "${BLUE}Step 3: Starting permission monitoring...${NC}"
echo -e "${YELLOW}Please grant all permissions when prompted on your device.${NC}"
echo ""

# Clear logcat buffer for fresh start
adb logcat -c

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}         PERMISSION DATA MONITORING         ${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""

# Function to parse and format permission data
parse_permission_log() {
    while IFS= read -r line; do
        # Extract the log message
        if [[ "$line" == *"PERMISSION_APP"* ]]; then
            # Remove timestamp and tag prefix
            message=$(echo "$line" | sed 's/.*PERMISSION_APP: //')
            
            # Detect and format different types of messages
            
            # Permission request
            if [[ "$message" == Requesting\ permission\ * ]]; then
                echo -e "\n${CYAN}⟳ $message${NC}"
                echo -e "${CYAN}──────────────────────────────────────────────${NC}"
            
            # Permission granted
            elif [[ "$message" == *"GRANTED"* ]]; then
                perm_name=$(echo "$message" | sed 's/: GRANTED.*//')
                echo -e "   ${GREEN}✓ $perm_name: GRANTED${NC}"
            
            # Permission denied
            elif [[ "$message" == *"DENIED"* ]]; then
                perm_name=$(echo "$message" | sed 's/: DENIED.*//')
                echo -e "   ${RED}✗ $perm_name: DENIED${NC}"
            
            # Data section header
            elif [[ "$message" == "=== "*" DATA ==="* ]]; then
                section_name=$(echo "$message" | sed 's/=== //; s/ DATA ===//')
                echo -e "\n${BOLD}${YELLOW}┌──────────────────────────────────────────────┐${NC}"
                echo -e "${BOLD}${YELLOW}│ ${CYAN}📂 $section_name DATA${NC}                          ${BOLD}${YELLOW}│${NC}"
                echo -e "${BOLD}${YELLOW}└──────────────────────────────────────────────┘${NC}"
            
            # Total count (contacts, calls, messages)
            elif [[ "$message" == Total\ contacts:* ]] || \
                 [[ "$message" == Total\ call\ log* ]] || \
                 [[ "$message" == Total\ SMS* ]] || \
                 [[ "$message" == Available\ location* ]] || \
                 [[ "$message" == Camera\ available:* ]] || \
                 [[ "$message" == Microphone\ available:* ]]; then
                echo -e "\n${GREEN}└─ $message${NC}"
            
            # Individual data items
            elif [[ "$message" == Contact\ * ]] || \
                 [[ "$message" == Call\ * ]] || \
                 [[ "$message" == SMS\ * ]] || \
                 [[ "$message" == Provider:* ]] || \
                 [[ "$message" == "  Last known location"* ]] || \
                 [[ "$message" == "  Last known location:"* ]] || \
                 [[ "$message" == "  Accuracy:"* ]] || \
                 [[ "$message" == "  Provider:"* ]] || \
                 [[ "$message" == GPS\ enabled:* ]] || \
                 [[ "$message" == Network\ enabled:* ]] || \
                 [[ "$message" == Front\ camera:* ]] || \
                 [[ "$message" == Back\ camera:* ]] || \
                 [[ "$message" == Microphone\ ready:* ]] || \
                 [[ "$message" == ...\ and\ * ]]; then
                echo -e "   $message"
            
            # Progress messages
            elif [[ "$message" == "Requesting "*" permissions sequentially" ]]; then
                echo -e "\n${YELLOW}→ $message${NC}"
            elif [[ "$message" == "Permission already granted: "* ]]; then
                perm=$(echo "$message" | sed 's/Permission already granted: //')
                echo -e "   ${GREEN}✓ $perm (already granted)${NC}"
            
            # Section completion
            elif [[ "$message" == "... and "*" more contacts"* ]] || \
                 [[ "$message" == "... and "*" more calls"* ]] || \
                 [[ "$message" == "... and "*" more messages"* ]]; then
                echo -e "   $message"
            
            # Final results
            elif [[ "$message" == "=== Final Results ==="* ]] || \
                 [[ "$message" == "All permission requests completed"* ]]; then
                echo -e "\n${GREEN}✓ $message${NC}"
            
            # Summary
            elif [[ "$message" == "=== All Permissions Processed ==="* ]]; then
                echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════${NC}"
                echo -e "${BOLD}${GREEN}        ALL PERMISSIONS PROCESSED!${NC}"
                echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${NC}"
            
            # Default - show raw message
            else
                echo "$message"
            fi
        fi
    done
}

# Function to show permission status table
show_permission_table() {
    local status=$1
    local perm_name=$2
    
    if [[ "$status" == "GRANTED" ]]; then
        printf "   ${GREEN}│ %-25s │ GRANTED ✓${NC}\n" "$perm_name"
    else
        printf "   ${RED}│ %-25s │ DENIED ✗${NC}\n" "$perm_name"
    fi
}

# Start monitoring in background
echo -e "${BOLD}Waiting for app to start...${NC}"
echo ""
adb logcat -s PERMISSION_APP | parse_permission_log &
LOG_PID=$!

# Give it a moment to start
sleep 2

# Step 4: Open the app
echo -e "${BLUE}Step 4: Opening app on device...${NC}"
adb shell am start -n com.permissionapp/.MainActivity
echo ""

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}   📱 App opened on device!${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Tap the 'Start Permission Requests' button on your device"
echo "2. Grant or deny each permission as prompted"
echo "3. Watch the formatted permission data appear below"
echo ""
echo -e "${CYAN}Press Ctrl+C to stop monitoring at any time.${NC}"
echo ""

# Keep script running until user presses Ctrl+C
wait $LOG_PID 2>/dev/null

