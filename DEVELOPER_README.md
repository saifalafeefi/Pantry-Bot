# 🛠️ PantryBot Developer Guide

A quick reference for all common development, build, and deployment tasks for PantryBot.

---

## 🚀 Flutter App Development

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
- **Run on iOS simulator/device:**
  ```bash
  flutter run -d ios
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
- **Build iOS app (release):**
  ```bash
  flutter build ios --release
  # Open ios/Runner.xcworkspace in Xcode to archive and sign
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

## 🖥️ Backend (Raspberry Pi)

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

---

## 🗄️ Database
- **Database file:** `pantrybot.db` (project root)
- **Backup database:**
  ```bash
  cp pantrybot.db backup/pantrybot_$(date +%Y%m%d).db
  ```

---

## ⚙️ Configuration
- **API URL in app:** Edit `lib/main.dart` (`baseUrl` variable)
- **API server port:** Edit `config.py`

---

## 🐛 Troubleshooting
- **Device not detected:**
  - Run `flutter devices`, check USB debugging, try reconnecting
- **API not reachable:**
  - Check Pi IP, firewall, and server status
- **Build errors:**
  - Run `flutter clean` then `flutter pub get`
- **iOS build issues:**
  - Open `ios/Runner.xcworkspace` in Xcode, check signing
- **SDK Version Issues:**
  - If you get "SDK version issue. This app was built with the iOS X.X SDK" error:
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
    
    # Then archive again in Xcode
    ```
  - **Required:** Xcode 16+ with iOS 18 SDK for App Store Connect uploads
  - **macOS Compatibility:**
    - **Xcode 16+:** Requires macOS Sequoia 15.3+ (not supported on 2017 Intel Macs)
    - **Xcode 15.4:** Requires macOS Sonoma 14.x (maximum for older Intel Macs)
    - **Xcode 15.2:** Works on macOS Ventura 13.5+ (includes iOS 17.2 SDK)
    - Check your hardware compatibility before upgrading macOS
- **CocoaPods Issues:**
  - If you get "CocoaPods not installed or not in valid state" or Ruby version conflicts:
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
  - Alternative: Use `flutter build ios --release` to bypass CocoaPods issues

---

## 📱 Exporting to Android
1. Connect your Android device (enable Developer Mode & USB Debugging)
2. Run:
   ```bash
   flutter run
   # or to build APK:
   flutter build apk --release
   # Find APK at: build/app/outputs/flutter-apk/app-release.apk
   ```
3. Transfer APK to your phone and install

## 🍏 Exporting to iOS
1. **Version Management**
   - Use `bump_version.sh` script to update version numbers:
     ```bash
     ./bump_version.sh <version_name> <build_number>
     # Example: ./bump_version.sh 1.3.2 9
     ```
   - Version format: `version_name+build_number` (e.g., 1.3.2+9)
   - Build number must be unique and increasing for each submission
   - Version name follows semantic versioning (MAJOR.MINOR.PATCH)

2. **Xcode Requirements**
   - **Preferred:** Xcode 16+ with iOS 18 SDK for latest TestFlight features
   - **Minimum:** Xcode 15.2+ with iOS 17.2 SDK for basic TestFlight submissions
   - **macOS Compatibility Check:**
     - 2017 Intel Macs: Maximum Xcode 15.4 (requires macOS Sonoma upgrade)
     - macOS Ventura: Maximum Xcode 15.2 via [Apple Developer Downloads](https://developer.apple.com/downloads)
     - macOS Sonoma: Maximum Xcode 15.4 via Mac App Store
     - macOS Sequoia: Xcode 16+ via Mac App Store

3. **Xcode Setup**
   - Open project in Xcode: `open ios/Runner.xcworkspace`
   - Select "Runner" project in navigator
   - Go to "Signing & Capabilities"
   - Ensure Apple Developer account is selected
   - Verify Bundle Identifier matches TestFlight configuration
   - Check "Automatically manage signing"

4. **Build & Archive**
   - Select "Any iOS Device (arm64)" as build target
   - Go to Product > Archive
   - Wait for archiving process to complete

5. **Upload to TestFlight**
   - In Organizer window, click "Distribute App"
   - Select "App Store Connect"
   - Choose "Upload" option
   - Select "Automatically manage signing"
   - Review and upload
   - Wait for processing (15-30 minutes)

6. **TestFlight Management**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Navigate to TestFlight
   - Add testers or create new TestFlight group
   - Note: TestFlight builds expire after 90 days

---

## 📝 Useful Links
- [Flutter Docs](https://flutter.dev/docs)
- [Android Studio Download](https://developer.android.com/studio)
- [Dart Packages](https://pub.dev/)
- [Flutter iOS Setup](https://docs.flutter.dev/get-started/install/macos)

---

*Keep this file handy for all your PantryBot development needs!* 