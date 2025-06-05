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
1. Open project in Xcode: `open ios/Runner.xcworkspace`
2. Connect your iPhone (enable Developer Mode)
3. Select your device and click "Run" or archive for App Store
4. Or use:
   ```bash
   flutter run -d ios
   flutter build ios --release
   ```

---

## 📝 Useful Links
- [Flutter Docs](https://flutter.dev/docs)
- [Android Studio Download](https://developer.android.com/studio)
- [Dart Packages](https://pub.dev/)
- [Flutter iOS Setup](https://docs.flutter.dev/get-started/install/macos)

---

*Keep this file handy for all your PantryBot development needs!* 