# Android Permission App - Terminal Guide

## Overview
This guide will help you:
1. Install and run the APK on your Android device
2. See permission data in real-time terminal output

## Prerequisites
- Android device with USB debugging enabled
- USB cable to connect device to computer
- ADB (Android Debug Bridge) installed on your computer

## Step 1: Enable USB Debugging on Android Device
1. Go to **Settings** > **About Phone**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings** > **Developer Options**
4. Enable **USB Debugging**
5. Enable **Install via USB** (optional but recommended)

## Step 2: Connect Device and Install APK

### Check device connection:
```bash
adb devices
```

### Install the APK:
```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

### If you need to reinstall (overwrite):
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Step 3: View Permission Data in Terminal

### Method 1: Real-time Logcat
Open a terminal and run:
```bash
adb logcat -s PERMISSION_APP
```

### Method 2: Filter specific permission data
```bash
adb logcat | grep PERMISSION_APP
```

### Method 3: View all app logs
```bash
adb logcat -d | grep PERMISSION_APP
```

## Step 4: Run the App
1. On your Android device, open the **Permission App**
2. Tap **"Request All Permissions"** button
3. Grant all requested permissions when prompted
4. The app will display permission data on screen AND log it to terminal

## Expected Permission Data in Terminal
When you grant permissions, you'll see logs like:
```
I/PERMISSION_APP: === Permission App Started ===
D/PERMISSION_APP: Permission already granted: android.permission.READ_CONTACTS
I/PERMISSION_APP: Requesting 8 permissions
D/PERMISSION_APP: All permissions granted!
D/PERMISSION_APP: Contacts: 42 contacts found
D/PERMISSION_APP: Call Log: 15 entries found
D/PERMISSION_APP: SMS: 23 messages found
D/PERMISSION_APP: Location: 3 providers available
```

## Available Permissions in App
- READ_CONTACTS
- READ_CALL_LOG
- READ_SMS
- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION
- READ_EXTERNAL_STORAGE
- CAMERA
- RECORD_AUDIO

## Troubleshooting

### Device not detected?
```bash
# Restart ADB server
adb kill-server
adb start-server
adb devices
```

### Permission denied?
- Make sure USB debugging is enabled
- Accept the USB debugging prompt on your device
- Try different USB cable or port

### APK installation failed?
```bash
# Uninstall previous version first
adb uninstall com.permissionapp
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Quick Commands Summary
```bash
# 1. Check device
adb devices

# 2. Install APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# 3. Start monitoring in new terminal
adb logcat -s PERMISSION_APP

# 4. Open app on device (from computer)
adb shell am start -n com.permissionapp/.MainActivity
```

## Build APK Again (if needed)
If you modify the code and need to rebuild:
```bash
./gradlew assembleDebug
```

