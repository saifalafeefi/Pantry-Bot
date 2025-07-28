# 📱 iOS Distribution Branch

This branch is dedicated to **iOS app building and distribution** using **Updraft**. It stays synchronized with the main Flutter app while maintaining iOS-specific build artifacts.

## 🎯 Branch Purpose

### What's Here:
- ✅ **iOS build artifacts** (archives, IPAs, export configs)
- ✅ **Xcode project configurations** 
- ✅ **Distribution scripts and workflows**
- ✅ **iOS-specific documentation**
- ✅ **Updraft upload history**

### What's Synced from Main:
- ✅ **Flutter app source code** (lib/, pubspec.yaml, etc.)
- ✅ **App assets** (images, fonts, etc.)
- ✅ **Android project** (for completeness)
- ✅ **General documentation**

---

## 🔄 Workflow: Syncing from Main

### When to Sync:
- ✅ **After Flutter app updates** on main branch
- ✅ **Before creating new iOS builds**
- ✅ **When new features are added** to the app

### How to Sync:
```bash
# 1. Switch to iOS distribution branch
git checkout ios-distribution

# 2. Run the sync script
./sync-from-main.sh

# 3. Verify sync completed successfully
git status
```

### What the Sync Does:
1. **Fetches latest changes** from main branch
2. **Merges Flutter app updates** into iOS branch  
3. **Preserves iOS build artifacts** and configurations
4. **Maintains iOS-specific files** (builds, exports, etc.)
5. **Auto-commits** the sync with timestamp

---

## 📦 iOS Build Process

### 1. Sync First (Always!)
```bash
./sync-from-main.sh
```

### 2. Build Flutter iOS
```bash
cd pantrybot
flutter clean
flutter pub get
flutter build ios --release
```

### 3. Archive in Xcode
1. **Open Xcode**: `open ios/Runner.xcworkspace`
2. **Select "Any iOS Device (arm64)"**
3. **Product → Archive**
4. **Wait for completion**

### 4. Export for Updraft
1. **In Xcode Organizer**: Select archive
2. **Distribute App → Custom → Release Testing**
3. **Include manifest for over-the-air installation** ✅
4. **Export to**: `ios-builds/ipa-exports/`

### 5. Save Build Artifacts
```bash
# Copy IPA to releases folder with version
cp ios-builds/ipa-exports/Runner.ipa ios-builds/releases/pantrybot-v1.5.0-b18.ipa

# Archive the .xcarchive (optional)
cp -r pantrybot/build/ios/archive/Runner.xcarchive ios-builds/archives/
```

### 6. Upload to Updraft
1. **Go to Updraft dashboard**
2. **Drag & drop IPA** to Builds section
3. **Verify "App is public" checked**
4. **Share link** with family

---

## 📁 Directory Structure

```
ios-distribution/
├── ios-builds/                    # iOS-specific build artifacts
│   ├── archives/                  # Xcode .xcarchive files
│   ├── ipa-exports/              # Exported .ipa files
│   ├── releases/                 # Versioned release builds
│   └── version-history.md        # Build history tracking
├── pantrybot/                    # Flutter app (synced from main)
├── .gitignore-ios               # iOS-specific gitignore
├── sync-from-main.sh           # Sync script from main branch
└── README_IOS_BRANCH.md        # This file
```

---

## 🔧 Troubleshooting

### Sync Issues

#### ❌ Merge conflicts during sync
```bash
# Resolve conflicts manually, then:
git add .
git commit -m "Resolve sync conflicts"
```

#### ❌ iOS builds missing after sync
```bash
# Builds are preserved automatically, but if lost:
# Check ios-builds/ directory
ls -la ios-builds/
```

### Build Issues

#### ❌ Code signing errors
1. **Check certificates** in Keychain
2. **Clean Xcode**: Product → Clean Build Folder
3. **Verify team settings** in Xcode

#### ❌ Archive not showing in Organizer
1. **Check archive location**: `pantrybot/build/ios/archive/`
2. **Look in**: `~/Library/Developer/Xcode/Archives/`

---

## 📊 Version Tracking

### Current Build Status
- **Latest Build**: v1.5.0 (build 18)
- **Last Sync**: From main branch commit 5322bff
- **Updraft Status**: Active and working
- **Distribution**: Working wirelessly via Safari

### Build History
Builds are tracked in `ios-builds/version-history.md` with:
- ✅ **Version numbers**
- ✅ **Build dates**
- ✅ **Updraft upload status**
- ✅ **Changes included**

---

## 🚀 Quick Commands

### Daily iOS Development:
```bash
# Sync and build new version
./sync-from-main.sh
cd pantrybot && flutter build ios --release
open ios/Runner.xcworkspace
```

### Release New Build:
```bash
# After Xcode archive and export
cp ios-builds/ipa-exports/Runner.ipa ios-builds/releases/pantrybot-v$(cat pantrybot/pubspec.yaml | grep version | cut -d' ' -f2).ipa
```

### Switch Back to Main:
```bash
git checkout main
# Main branch has Updraft documentation but no build artifacts
```

---

## 💡 Pro Tips

### Efficient Workflow:
1. **Develop Flutter app** on main branch
2. **Switch to iOS branch** only for builds
3. **Always sync before building**
4. **Keep build artifacts** organized by version

### Git Best Practices:
- ✅ **Sync regularly** to avoid conflicts
- ✅ **Commit builds** with descriptive messages
- ✅ **Tag releases** for easy tracking
- ✅ **Keep branches clean** and organized

### Updraft Integration:
- ✅ **Test builds** on your device first
- ✅ **Update version numbers** before each build
- ✅ **Share QR codes** for easy family installation
- ✅ **Enable auto-updates** in Updraft settings

---

**Happy iOS Development!** 📱✨ 