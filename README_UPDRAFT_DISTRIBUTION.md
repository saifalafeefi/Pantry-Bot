# 📱 App Distribution with Updraft

Quick guide for wireless app distribution without App Store or Play Store.

## 🎯 Overview

**Updraft** supports both iOS and Android wireless distribution:
- **iOS**: No App Store submission, no TestFlight limits
- **Android**: Direct APK distribution, no Play Store needed
- **Cross-platform**: Same dashboard for both platforms

### Prerequisites
- **iOS**: Apple Developer Account ($99/year), Xcode
- **Android**: Android Studio or Flutter build tools
- **Both**: Updraft account: https://getupdraft.com

## 🚀 iOS Build Process

### 1. Prepare Build
```bash
# Switch to iOS distribution branch
git checkout ios-distribution
./sync-from-main.sh

# Update version and dependencies  
cd pantrybot && ./bump_version.sh 1.5.0 26
cd ios && pod install
```

### 2. Archive & Export
```bash
# Open Xcode project
open ios/Runner.xcworkspace

# In Xcode: Product → Archive → Distribute App
# Choose: Custom → Release Testing
# ✅ Include manifest for over-the-air installation
```

### 3. Upload to Updraft
1. Drag & drop `Runner.ipa` to Updraft dashboard
2. Enable "App is public" setting
3. Share link with users

## 🤖 Android Build Process

### 1. Build APK
```bash
# Stay on main branch for Android
git checkout main

# Build release APK
cd pantrybot
flutter build apk --release
```

### 2. Upload to Updraft
1. Go to Updraft dashboard → **Builds** tab
2. Drag & drop `app-release.apk` file
3. Enable "App is public" setting

## 📱 Installation

**iOS**: Open link in Safari browser  
**Android**: Download APK and install (enable "Unknown sources")

## 🔧 Troubleshooting

**iOS signing errors**: Clean Build Folder in Xcode  
**Android build issues**: Run `flutter clean && flutter pub get`  
**Can't install**: Ensure "App is public" is checked in Updraft  
**Updates not working**: Increment build number in `pubspec.yaml`

## 📈 Auto-Updates

The app can include Updraft SDK for automatic update notifications:
- **iOS**: Native SDK integration (ios-distribution branch)
- **Android**: Flutter SDK integration (planned)

## 🌟 Benefits

✅ **No store approval** required  
✅ **Instant distribution** to users  
✅ **No expiration limits**  
✅ **Cross-platform** dashboard  
✅ **Family sharing** without accounts 