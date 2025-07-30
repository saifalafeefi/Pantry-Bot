# 🌳 Git Branching Strategy

**Dual-branch setup**: Separate platforms while sharing core Flutter app.

## 📋 Branches

### `main` Branch
- ✅ Flutter app development  
- ✅ **Android builds** and distribution
- ✅ **General Updraft documentation**
- ✅ Cross-platform features
- ❌ No iOS build artifacts

### `ios-distribution` Branch  
- ✅ All main content (auto-synced)
- ✅ **iOS builds** and Updraft distribution
- ✅ iOS-specific workflows and documentation
- ✅ iOS build artifacts (.ipa, .xcarchive)

## 🔄 Workflow

### Android Development & Distribution
```bash
# Work and build on main branch
git checkout main

# Develop Flutter features
# Make changes, commit, push

# Build Android APK
cd pantrybot && flutter build apk --release
# Upload APK to Updraft dashboard
```

### iOS Development & Distribution
```bash
# Switch to iOS branch and sync latest
git checkout ios-distribution
./sync-from-main.sh

# Build iOS
cd pantrybot && flutter build ios --release
open ios/Runner.xcworkspace
# Archive → Export → Upload to Updraft
```

### Key Principle
**Android on `main`, iOS on `ios-distribution`**

## 🔄 Synchronization

The `sync-from-main.sh` script (on ios-distribution):
- Fetches latest Flutter app from main
- Merges into ios-distribution  
- Preserves iOS build artifacts
- Auto-commits with timestamp

**Run before every iOS build!**

## 📁 Structure

### Main Branch
```
main/
├── pantrybot/                        # Flutter app
├── README.md                         # General docs
├── README_UPDRAFT_DISTRIBUTION.md    # Cross-platform guide
├── README_BRANCHING_STRATEGY.md      # This file
└── releases/                         # Android APKs
```

### iOS Branch
```
ios-distribution/
├── pantrybot/                        # Flutter app (synced)
├── ios-builds/                       # iOS build artifacts  
├── sync-from-main.sh                 # Sync script
├── README_IOS_BRANCH.md              # iOS workflow
└── ExportOptions.plist               # Xcode config
```

## ✅ Benefits

- **Platform separation**: Android on main, iOS on dedicated branch
- **Auto-sync**: iOS gets latest Flutter app automatically  
- **Clean organization**: Build artifacts isolated per platform
- **Cross-platform docs**: Updraft guide supports both platforms
- **Efficient workflow**: Work where it makes sense

## 🚀 Quick Commands

```bash
# Android development (main branch)
git checkout main
flutter build apk --release

# iOS development (ios-distribution branch)  
git checkout ios-distribution && ./sync-from-main.sh
open pantrybot/ios/Runner.xcworkspace

# See current branch
git branch
```

## 🎯 Platform Workflows

**For Android**: Stay on main, build APKs, upload to Updraft  
**For iOS**: Switch to ios-distribution, sync, build IPAs, upload to Updraft  
**For Flutter development**: Work on main, sync to iOS automatically

**Created**: July 2025 | **Status**: Active - Cross-platform Updraft Ready 