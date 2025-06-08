# 🛠️ PantryBot Developer Guide

A quick reference for all common development, build, and deployment tasks for PantryBot.

---

## 🚀 Flutter App Development (All Platforms)

### 🔄 Dependency Management
- **Get dependencies:**
  ```bash
  flutter pub get
  ```
- **Upgrade dependencies:**
  ```bash
  flutter pub upgrade
  ```

### 🏃 Running the App
- **Run on Android device/emulator:**
  ```bash
  flutter run
  ```
- **Run on Windows:**
  ```bash
  flutter run -d windows --release
  ```
- **List connected devices:**
  ```bash
  flutter devices
  ```

### 📦 Building for Release
- **Build Android APK (release):**
  ```bash
  flutter build apk --release
  # Output: build/app/outputs/flutter-apk/app-release.apk
  ```
- **Build Android App Bundle (Play Store):**
  ```bash
  flutter build appbundle --release
  # Output: build/app/outputs/bundle/release/app-release.aab
  ```

### 🧹 Cleaning & Analyzing
- **Clean build artifacts:**
  ```bash
  flutter clean
  ```
- **Analyze code for issues:**
  ```bash
  flutter analyze
  ```
- **Format code:**
  ```bash
  flutter format .
  ```

### 🔥 Hot Reload/Restart
- **Hot reload (while running):** Press `r` in terminal
- **Hot restart:** Press `R` in terminal

---

## 🖥️ Windows Development

### 💻 Windows-Specific Commands
- **Run on Windows (debug):**
  ```cmd
  flutter run -d windows
  ```
- **Build Windows app:**
  ```cmd
  flutter build windows --release
  # Output: build/windows/x64/runner/Release/pantrybot.exe
  ```
- **Install APK on connected Android device:**
  ```cmd
  flutter install --release
  ```

### 🔧 Windows Troubleshooting
- **Java/Android issues:**
  - Ensure JAVA_HOME points to JDK 17 (not JDK 21)
  - Check Android Studio SDK is properly installed
  - Run `flutter doctor` to verify setup
- **Gradle issues:**
  ```cmd
  cd android
  gradlew clean
  cd ..
  flutter clean
  flutter pub get
  ```
- **Windows build issues:**
  - Ensure Visual Studio 2022 or Build Tools are installed
  - Check CMake is available in PATH
- **PowerShell vs Command Prompt:**
  - Use `&` instead of `&&` for command chaining in PowerShell
  - Or use Command Prompt for bash-like syntax

### 📱 Android Export (Windows)
1. **Enable Developer Mode on Android:**
   - Settings > About Phone > Tap "Build Number" 7 times
   - Settings > System > Developer Options > Enable "USB Debugging"

2. **Connect device and build:**
   ```cmd
   flutter devices
   flutter build apk --release
   ```

3. **Install APK:**
   ```cmd
   # Method 1: Direct install via Flutter
   flutter install --release
   
   # Method 2: Copy APK file
   # APK location: build\app\outputs\flutter-apk\app-release.apk
   # Transfer to phone and install manually
   ```

---

## 🍏 Mac Development

### 💻 Mac-Specific Commands
- **Run on iOS simulator:**
  ```bash
  flutter run -d ios
  ```
- **Build iOS app:**
  ```bash
  flutter build ios --release
  ```
- **Open iOS project in Xcode:**
  ```bash
  open ios/Runner.xcworkspace
  ```

### 🔧 Mac Troubleshooting
- **CocoaPods Issues:**
  ```bash
  # Install rbenv for Ruby version management
  brew install rbenv
  
  # Install and use Ruby 3.1.0
  rbenv install 3.1.0
  rbenv global 3.1.0
  
  # Add rbenv to your shell
  echo 'eval "$(rbenv init -)"' >> ~/.zshrc
  source ~/.zshrc
  
  # Install CocoaPods
  gem install cocoapods
  
  # Run pod install in iOS directory
  cd ios && pod install
  ```

- **SDK Version Issues:**
  ```bash
  # Check current Xcode version and SDK
  xcode-select -p
  xcrun --show-sdk-version
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -version
  
  # If wrong version, update Xcode to 16+ via Mac App Store
  # Then ensure command line tools point to correct Xcode:
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  
  # After updating, clean and rebuild
  flutter clean
  flutter pub get
  cd ios && pod install
  ```

### 🍏 iOS Export (Mac Only)
1. **Version Management**
   - Use `bump_version.sh` script to update version numbers:
     ```bash
     ./bump_version.sh <version_name> <build_number>
     # Example: ./bump_version.sh 1.3.2 9
     ```

2. **Xcode Requirements**
   - **Preferred:** Xcode 16+ with iOS 18 SDK for latest TestFlight features
   - **Minimum:** Xcode 15.2+ with iOS 17.2 SDK for basic TestFlight submissions
   - **macOS Compatibility:**
     - 2017 Intel Macs: Maximum Xcode 15.4 (requires macOS Sonoma upgrade)
     - macOS Ventura: Maximum Xcode 15.2 via [Apple Developer Downloads](https://developer.apple.com/downloads)
     - macOS Sonoma: Maximum Xcode 15.4 via Mac App Store
     - macOS Sequoia: Xcode 16+ via Mac App Store

3. **Build & Archive in Xcode:**
   - Open: `open ios/Runner.xcworkspace`
   - Select "Any iOS Device (arm64)" as build target
   - Product > Archive
   - Distribute App > App Store Connect > Upload

4. **TestFlight Management:**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Navigate to TestFlight section
   - Add testers or create new TestFlight group

---

## 🖥️ Backend (Raspberry Pi)

### 🐧 Linux Commands (Raspberry Pi)
- **Start API server:**
  ```bash
  python3 api.py
  ```
- **Start Pi UI:**
  ```bash
  python3 pantrybot.py
  ```
- **Install Python dependencies:**
  ```bash
  pip3 install flask flask-cors tkcalendar
  ```
- **Run API in background:**
  ```bash
  nohup python3 api.py &
  ```
- **Check running processes:**
  ```bash
  ps aux | grep api.py
  ```
- **Kill API process:**
  ```bash
  kill <process_id>
  ```

---

## 🗄️ Database

### 📊 Database Management (All Platforms)
- **Database file:** `pantrybot.db` (project root)

**Windows backup:**
```cmd
copy pantrybot.db backup\pantrybot_%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%.db
```

**Mac/Linux backup:**
```bash
cp pantrybot.db backup/pantrybot_$(date +%Y%m%d).db
```

---

## ⚙️ Configuration

- **API URL in app:** Edit `lib/main.dart` (`baseUrl` variable)
- **API server port:** Edit `config.py`
- **App name/version:** Edit `pubspec.yaml`

---

## 🐛 Common Troubleshooting

### 🔧 General Issues (All Platforms)
- **Device not detected:**
  ```bash
  flutter devices
  # Check USB debugging, try reconnecting
  ```
- **API not reachable:**
  - Check Pi IP address and server status
  - Verify firewall settings
  - Test with: `curl https://pantrybot.anonstorage.org:8443/grocery/items`

- **Build errors:**
  ```bash
  flutter clean
  flutter pub get
  flutter build apk --release
  ```

### 🖥️ Windows-Specific Issues
- **Java Version Conflicts:**
  - Use JDK 17 (not JDK 21)
  - Set JAVA_HOME environment variable
  - Add Java to PATH

- **Gradle Build Failures:**
  ```cmd
  # Clear Gradle cache
  rmdir /s /q "%USERPROFILE%\.gradle"
  flutter clean
  flutter pub get
  ```

- **Missing Visual Studio Tools:**
  - Install Visual Studio 2022 Community (free)
  - Or install Build Tools for Visual Studio 2022
  - Ensure "Desktop development with C++" workload is installed

### 🍏 Mac-Specific Issues
- **iOS build issues:**
  - Alternative: Use `flutter build ios --release` to bypass CocoaPods
  - Ensure latest Xcode version is installed
  - Check signing certificates in Xcode

---

## 📱 Quick Commands Reference

### 🚀 Most Used Windows Commands
```cmd
# Development cycle
flutter pub get
flutter run -d windows
flutter build apk --release

# Android testing
flutter devices
flutter install --release

# Debugging
flutter clean
flutter doctor
```

### 🚀 Most Used Mac Commands
```bash
# Development cycle
flutter pub get
flutter run -d ios
flutter build ios --release

# iOS deployment
open ios/Runner.xcworkspace
# Then archive in Xcode

# Debugging
flutter clean
flutter doctor
```

---

## 📝 Useful Links

- [Flutter Docs](https://flutter.dev/docs)
- [Android Studio Download](https://developer.android.com/studio)
- [Visual Studio 2022 Community](https://visualstudio.microsoft.com/vs/community/)
- [Dart Packages](https://pub.dev/)
- [Flutter Windows Setup](https://docs.flutter.dev/get-started/install/windows)
- [Flutter macOS Setup](https://docs.flutter.dev/get-started/install/macos)

---

*Keep this file handy for all your PantryBot development needs!* 