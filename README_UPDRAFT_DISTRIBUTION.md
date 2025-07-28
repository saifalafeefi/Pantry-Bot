# 📱 iOS App Distribution with Updraft - Complete Guide

## 🎯 Overview

**Updraft** is a wireless iOS app distribution service that allows you to share your Flutter iOS apps with family and testers **without going through the App Store or TestFlight**. No cables, no App Store approval, no 90-day expiration limits!

### ✅ Why Updraft Over TestFlight?
- **No App Store submission required**
- **No 90-day build expiration**
- **No "Removed from Sale" issues** 
- **Wireless installation via Safari**
- **No account requirements for testers** (when configured properly)
- **Instant distribution** - no review process

---

## 🛠️ Prerequisites

Before starting, ensure you have:
- ✅ **Apple Developer Account** (paid $99/year program)
- ✅ **Xcode** installed with your team configured
- ✅ **Flutter project** ready to build
- ✅ **Development/Distribution certificates** in Keychain

---

## 🚀 Step 1: Set Up Updraft Account

### 1.1 Create Account
1. **Go to**: https://getupdraft.com
2. **Click "Get Started"** or **"Sign Up"**
3. **Use GitHub account** (recommended) or email signup
4. **Verify your email** if required

### 1.2 Create New Project
1. **Click "Add new App"** or **"Create Project"**
2. **Enter project details**:
   - **Project Title**: `Saif's Pantry Bot` (or your app name)
   - **Description**: Brief description of your app
3. **Click "Create"**

---

## 🔨 Step 2: Prepare Your Flutter iOS Build

### 2.1 Clean and Prepare
```bash
cd your-flutter-project
flutter clean
flutter pub get
```

### 2.2 Build iOS Release
```bash
flutter build ios --release
```

**Important**: If you get code signing errors, continue to Xcode archive method below.

---

## 📦 Step 3: Create iOS Archive in Xcode

### 3.1 Open Xcode Workspace
```bash
open ios/Runner.xcworkspace
```

### 3.2 Configure Build Settings
1. **Select "Runner" target** (top left)
2. **Choose "Any iOS Device (arm64)"** from device dropdown
3. **Verify Signing & Capabilities**:
   - ✅ **Automatically manage signing**: ON
   - ✅ **Team**: Your Apple Developer team
   - ✅ **Bundle Identifier**: Correct (e.g., `com.saifalafeefi.pantrybot`)

### 3.3 Create Archive
1. **Product** → **Archive**
2. **Wait for build to complete** (usually 2-5 minutes)
3. **Xcode Organizer will open automatically**

---

## 📤 Step 4: Export for Distribution

### 4.1 In Xcode Organizer
1. **Select your latest archive**
2. **Click "Distribute App"**
3. **Choose "Custom"** → **Next**

### 4.2 Select Distribution Method
1. **Choose "Release Testing"** → **Next**
   - ⚠️ **NOT "App Store Connect"**
   - ⚠️ **NOT "Development"** (unless Release Testing fails)

### 4.3 Configure Distribution Options
1. **App Thinning**: Select **"None"**
2. **Additional Options**:
   - ✅ **Strip Swift symbols** (already checked - good!)
   - ✅ **Include manifest for over-the-air installation** ← **CRITICAL!**
3. **Click "Next"**

### 4.4 Manifest Information
**Leave all URLs as default examples** - Updraft will replace these:
- **Name**: `Runner` (or your app name)
- **App URL**: `https://www.example.com/apps/foo.ipa` (leave as-is)
- **Display Image URL**: `https://www.example.com/image.57x57.png` (leave as-is)
- **Full Size Image URL**: `https://www.example.com/image.512x512.png` (leave as-is)

**Click "Next"**

### 4.5 Re-signing Options
1. **Keep "Automatically manage signing"** selected
2. **Click "Next"**

### 4.6 Export Location
1. **Choose save location** (Desktop recommended)
2. **Click "Export"**
3. **Wait for export to complete**

---

## 📁 Step 5: Locate Your IPA File

After export, you'll get a folder named something like:
`Runner 2025-07-28 19-32-05`

**Inside this folder, find**:
- ✅ **`Runner.ipa`** ← **This is what you need!**
- `DistributionSummary.plist`
- `ExportOptions.plist`
- `Packaging.log`
- `manifest.plist`

---

## ⬆️ Step 6: Upload to Updraft

### 6.1 Go to Updraft Dashboard
1. **Navigate to your Updraft project**
2. **Click on "Builds" tab** in left sidebar
3. **Click "Upload new build"**

### 6.2 Upload IPA
1. **Drag and drop** `Runner.ipa` onto the upload area
   - **OR click "Browse"** and select the file
2. **Wait for upload to complete** (usually 30-60 seconds)
3. **Updraft will process and create distribution link**

---

## ⚙️ Step 7: Configure Public Access (CRITICAL!)

### 7.1 Enable Public Access
1. **Go to "Application Overview"** tab
2. **Scroll down to "SDK Settings"** section
3. **Find "App is public ?" checkbox**
4. **✅ CHECK this box** to enable anonymous downloads

**Important**: 
- ✅ **Checked** = Family can install without Updraft accounts
- ❌ **Unchecked** = Family needs to create Updraft accounts (annoying!)

### 7.2 Save Settings
**Settings should auto-save**, but verify the checkbox stays checked.

---

## 🎯 Step 8: Share with Your Family

### 8.1 Get Distribution Link
1. **Go to "Builds" tab**
2. **Click on your uploaded build**
3. **Copy the "Public Link"** (e.g., `https://app.getupdraft.com/getapp/6ba7059b128646c39e92f71eb225dd5f`)

### 8.2 Share Installation Instructions

**Send this to your family**:

```
📱 Install Saif's Pantry Bot:

1. Open this link in Safari on your iPhone/iPad:
   https://app.getupdraft.com/getapp/YOUR_LINK_HERE

2. Tap "Install App"

3. If prompted, go to Settings > General > VPN & Device Management
   and trust the developer profile

4. Done! The app will appear on your home screen.

Note: Use Safari browser - other browsers may not work for installation.
```

### 8.3 QR Code Option
**Updraft also provides a QR code** - family can scan it with their camera app for quick installation.

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### ❌ "Upload new build" button not working
**Solution**: Try directly dragging the .ipa file onto the Updraft page instead.

#### ❌ Code signing errors during archive
**Solutions**:
1. **Clean Xcode**: Product → Clean Build Folder
2. **Check certificates**: Open Keychain → look for valid Apple Distribution certificate
3. **Regenerate profiles**: Xcode → Preferences → Accounts → Download Manual Profiles

#### ❌ Family gets "Could not install" error
**Solutions**:
1. **Verify "App is public" is checked** in Updraft settings
2. **Ensure using Safari browser** for installation (not Chrome/Firefox)
3. **Check device storage** - ensure enough space for installation
4. **Trust developer profile** in Settings after first install attempt

#### ❌ Build exports but no .ipa file found
**Check export folder contents** - the .ipa might be nested in a subfolder.

#### ❌ "No profiles for app ID" error
**Solutions**:
1. **Try "Development" instead of "Release Testing"** in export options
2. **Verify bundle ID matches** your Apple Developer configuration
3. **Regenerate provisioning profiles** in Apple Developer portal

### Build Update Process

**When you want to upload a new version**:
1. **Update version** in `pubspec.yaml` (e.g., `1.5.0+19`)
2. **Repeat Steps 2-6** (build → archive → export → upload)
3. **Family gets notification** if auto-update is enabled
4. **OR share new link** for manual updates

---

## 💡 Pro Tips

### Updraft Best Practices
- ✅ **Enable auto-update notifications** for seamless updates
- ✅ **Use meaningful version numbers** for tracking
- ✅ **Add release notes** to each build for clarity
- ✅ **Test installation** on your own device first

### Version Management
```yaml
# In pubspec.yaml - increment build number for each upload
version: 1.5.0+19  # 1.5.0 = version, 19 = build number
```

### Family Onboarding
**First-time setup for family**:
1. **Install first app** via Updraft link
2. **Trust developer profile** in iOS Settings
3. **All future updates** install seamlessly

---

## 🎉 Success Indicators

**You know it's working when**:
- ✅ Family can **install without creating accounts**
- ✅ App **installs via Safari link**
- ✅ **No TestFlight errors or limitations**
- ✅ **Updates deploy instantly**
- ✅ **No 90-day expiration worries**

---

## 🆚 Updraft vs TestFlight Comparison

| Feature | TestFlight | Updraft |
|---------|------------|---------|
| **App Store approval** | Required | Not required |
| **Build expiration** | 90 days | No expiration |
| **Family account setup** | Apple ID required | Optional |
| **Distribution speed** | Hours/days | Instant |
| **Installation method** | TestFlight app | Safari browser |
| **Update notifications** | Built-in | Configurable |
| **Privacy/control** | Apple controls | You control |

---

## 🔗 Helpful Links

- **Updraft Website**: https://getupdraft.com
- **Apple Developer Portal**: https://developer.apple.com
- **Xcode Documentation**: https://developer.apple.com/xcode/
- **Flutter iOS Deployment**: https://flutter.dev/docs/deployment/ios

---

## 📝 Notes

**Created**: July 28, 2025  
**Last Updated**: July 28, 2025  
**Flutter Version**: 3.24.x  
**Xcode Version**: 16.x  

**This guide successfully resolved**:
- TestFlight "Could not install" errors
- App Store "Removed from Sale" blocking issues
- Complex App Store submission requirements
- Family account setup friction

**Happy wireless app distribution!** 🚀📱 