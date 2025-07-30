# 📱 iOS Distribution Branch

This branch handles iOS builds and Updraft distribution while staying synced with main Flutter app.

## 🎯 Purpose

- ✅ iOS build artifacts (archives, IPAs)
- ✅ Distribution workflows
- ✅ Syncs Flutter app from main branch

## 🔄 Workflow

### 1. Sync from Main (Always First!)
```bash
git checkout ios-distribution
./sync-from-main.sh
```

### 2. Build iOS
```bash
cd pantrybot
flutter clean && flutter pub get
cd ios && pod install
open Runner.xcworkspace
```

### 3. Archive & Export
1. **Xcode**: Select "Any iOS Device" → **Product** → **Archive**
2. **Organizer**: **Distribute App** → **Custom** → **Release Testing**
3. **Include manifest** ✅ → **Export**

### 4. Upload to Updraft
1. Drag `.ipa` file to Updraft Builds tab
2. Enable "App is public" setting
3. Share link with family

## 📁 Directory Structure

```
ios-distribution/
├── ios-builds/          # Build artifacts
├── pantrybot/           # Flutter app (synced)
├── sync-from-main.sh    # Sync script
└── README_IOS_BRANCH.md # This file
```

## 🔧 Quick Fixes

**Sync conflicts**: Resolve manually, then `git add . && git commit`  
**Build errors**: Clean Build Folder in Xcode  
**Missing builds**: Check `ios-builds/` directory

## 💡 Best Practices

- Always sync before building
- Develop on main, build on iOS branch
- Keep build artifacts organized by version

**Current Status**: v1.5.0 (build 25+), Updraft working 