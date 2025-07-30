# 📱 iOS App Distribution with Updraft

Quick guide for wireless iOS app distribution without App Store or TestFlight.

## 🎯 Quick Setup

### Prerequisites
- Apple Developer Account ($99/year)
- Xcode with valid signing certificates
- Updraft account: https://getupdraft.com

## 🚀 Build Process

### 1. Prepare Build
```bash
# Update version (change numbers as needed)
cd pantrybot && ./bump_version.sh 1.5.0 26

# Sync dependencies
cd ios && pod install
```

### 2. Archive in Xcode
```bash
# Open project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device (arm64)"
# 2. Product → Archive
# 3. Wait for completion
```

### 3. Export for Distribution
**In Xcode Organizer:**
1. Select latest archive → **Distribute App**
2. **Custom** → **Release Testing** → **Next**
3. **✅ Include manifest for over-the-air installation**
4. Leave URLs as default → **Export**

### 4. Upload to Updraft
1. Go to Updraft dashboard → **Builds** tab
2. **Drag & drop** the `Runner.ipa` file
3. **Enable "App is public"** in Application Overview settings

### 5. Share with Family
Copy the public link and send to family:
```
Install the app: [Updraft link]
Open in Safari on your iPhone/iPad
```

## 🔧 Quick Fixes

**Code signing errors**: Clean Build Folder in Xcode  
**Family can't install**: Ensure "App is public" is checked  
**No .ipa file**: Check export folder contents  
**Update not working**: Increment build number in `pubspec.yaml`

## 📱 Auto-Updates (Updraft SDK)

The app includes Updraft SDK for automatic update notifications. When you upload a new build, users get prompted to update automatically.

**That's it!** No App Store submission, no 90-day expiration, wireless installation via Safari. 