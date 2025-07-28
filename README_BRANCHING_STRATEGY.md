# 🌳 Git Branching Strategy for Pantry Bot

## 📋 Overview

This repository uses a **dual-branch strategy** to separate Flutter app development from iOS distribution workflows:

- **`main`**: Flutter app development + general documentation
- **`ios-distribution`**: iOS builds, archives, and Updraft distribution

## 🎯 Branch Purposes

### `main` Branch
**Purpose**: Primary Flutter app development

**Contains**:
- ✅ **Flutter app source code** (lib/, pubspec.yaml, assets/)
- ✅ **Android project** files
- ✅ **iOS project** files (base configuration)
- ✅ **General documentation** (README, DEVELOPER_README)
- ✅ **Updraft distribution guide** (README_UPDRAFT_DISTRIBUTION.md)
- ✅ **Branching strategy docs** (this file)

**What's NOT here**:
- ❌ **iOS build artifacts** (.ipa files, .xcarchive)
- ❌ **Xcode DerivedData** or build outputs
- ❌ **iOS-specific distribution scripts**

### `ios-distribution` Branch
**Purpose**: iOS app building and wireless distribution

**Contains**:
- ✅ **All main branch content** (synced automatically)
- ✅ **iOS build artifacts** (archives, IPAs, exports)
- ✅ **iOS distribution scripts** (sync-from-main.sh)
- ✅ **iOS-specific documentation** (README_IOS_BRANCH.md)
- ✅ **Version history tracking** (ios-builds/version-history.md)
- ✅ **Updraft upload artifacts**

---

## 🔄 Workflow

### Daily Flutter Development (Main Branch)
```bash
# Work on Flutter app features
git checkout main
# Make changes to lib/, pubspec.yaml, etc.
git add . && git commit -m "Add new feature"
git push origin main
```

### iOS Building & Distribution (iOS Branch)
```bash
# Switch to iOS branch and sync latest changes
git checkout ios-distribution
./sync-from-main.sh

# Build and distribute iOS app
cd pantrybot
flutter build ios --release
open ios/Runner.xcworkspace
# Archive in Xcode → Export → Upload to Updraft
```

### Key Principle: **Develop on Main, Build on iOS**

---

## 🔄 Automatic Synchronization

The **`sync-from-main.sh`** script handles synchronization:

### What It Does:
1. **Fetches latest** from main branch
2. **Merges changes** into ios-distribution branch
3. **Preserves iOS build artifacts** and configuration
4. **Auto-commits** with timestamp
5. **Maintains branch separation**

### When to Sync:
- ✅ **Before building** new iOS versions
- ✅ **After Flutter updates** on main
- ✅ **When app features change**

### How It Works:
```bash
# Automatic sync preserves:
ios-builds/          # Build artifacts
.gitignore-ios       # iOS-specific ignore rules
README_IOS_BRANCH.md # iOS documentation
sync-from-main.sh    # This script itself

# While pulling in:
pantrybot/lib/       # Updated Flutter code
pantrybot/pubspec.yaml # Version changes
README_UPDRAFT_DISTRIBUTION.md # Documentation updates
```

---

## 📁 File Organization

### Main Branch Structure:
```
main/
├── pantrybot/                    # Flutter app
│   ├── lib/                     # Dart source code
│   ├── pubspec.yaml            # Dependencies & version
│   ├── ios/                    # iOS project (base)
│   └── android/                # Android project
├── README.md                   # General project docs
├── README_UPDRAFT_DISTRIBUTION.md # Updraft guide
└── README_BRANCHING_STRATEGY.md   # This file
```

### iOS Distribution Branch Structure:
```
ios-distribution/
├── pantrybot/                    # Flutter app (synced)
├── ios-builds/                   # iOS build artifacts
│   ├── archives/                # .xcarchive files
│   ├── ipa-exports/            # .ipa files
│   ├── releases/               # Versioned releases
│   └── version-history.md      # Build tracking
├── .gitignore-ios              # iOS-specific rules
├── sync-from-main.sh           # Sync script
└── README_IOS_BRANCH.md        # iOS workflow docs
```

---

## 🎯 Benefits of This Strategy

### ✅ **Clean Separation**
- **Main branch**: Clean, focused on Flutter development
- **iOS branch**: Contains build artifacts without cluttering main

### ✅ **Automatic Synchronization**
- **No manual merging** of Flutter changes
- **Preserves iOS work** while staying updated
- **Conflict-free** synchronization process

### ✅ **Organized Development**
- **Clear workflow**: Develop on main, build on iOS
- **Version tracking**: iOS builds tracked separately
- **Documentation**: Branch-specific guides

### ✅ **GitHub Benefits**
- **Main branch**: Clean for code reviews and collaboration
- **iOS branch**: Full build history and distribution tracking
- **No binary pollution**: Build artifacts stay on iOS branch

---

## 🚀 Quick Start Guide

### First Time Setup (Already Done!):
```bash
# Branches are already created and configured
git clone https://github.com/saifalafeefi/Pantry-Bot.git
cd Pantry-Bot
```

### Daily Development Workflow:
```bash
# 1. Develop Flutter features
git checkout main
# Edit lib/ files, add features, fix bugs
git add . && git commit -m "Your changes"
git push origin main

# 2. When ready to build iOS version
git checkout ios-distribution
./sync-from-main.sh  # Gets your latest changes

# 3. Build iOS (follow README_IOS_BRANCH.md)
cd pantrybot && flutter build ios --release
open ios/Runner.xcworkspace
# Archive → Export → Upload to Updraft
```

### Emergency: Fix iOS-Only Issue:
```bash
# If iOS branch needs urgent fix that main doesn't need
git checkout ios-distribution
# Make iOS-specific changes
git add . && git commit -m "iOS-specific fix"
git push origin ios-distribution
# Fix stays on iOS branch only
```

---

## 🔧 Troubleshooting

### Sync Conflicts:
```bash
# If sync-from-main.sh encounters conflicts:
./sync-from-main.sh  # Will show conflict files
# Manually resolve conflicts in your editor
git add .
git commit -m "Resolve sync conflicts"
```

### Lost iOS Builds:
```bash
# iOS builds are preserved automatically, but if lost:
git checkout ios-distribution
ls ios-builds/  # Check if artifacts exist
# If missing, rebuild from scratch
```

### Switch Back to Main:
```bash
git checkout main
# You're back to clean Flutter development
# No iOS build artifacts here
```

---

## 📊 Branch Status

### Current State:
- ✅ **Main Branch**: Clean, contains Updraft documentation
- ✅ **iOS Branch**: Active with v1.5.0 (build 18) working via Updraft
- ✅ **Sync Script**: Tested and working
- ✅ **Documentation**: Complete and up-to-date

### GitHub Integration:
- ✅ **Both branches** pushed to GitHub
- ✅ **Independent development** possible
- ✅ **Clean commit history** on both branches
- ✅ **No binary bloat** on main branch

---

## 💡 Pro Tips

### Best Practices:
1. **Always develop** on main branch
2. **Switch to iOS** only for building/distribution
3. **Run sync script** before every iOS build
4. **Commit iOS builds** with descriptive messages
5. **Keep main branch clean** of build artifacts

### Git Commands:
```bash
# See which branch you're on
git branch

# Quick switch to iOS for building
git checkout ios-distribution && ./sync-from-main.sh

# Quick switch back to main for development  
git checkout main

# See what changed during sync
git log --oneline -5
```

### Version Management:
- **Update versions** on main branch in `pubspec.yaml`
- **Sync pulls version changes** to iOS branch automatically
- **iOS builds** use the synced version numbers
- **Track iOS builds** in `ios-builds/version-history.md`

---

**This branching strategy gives you the best of both worlds: clean Flutter development on main, and organized iOS distribution on ios-distribution!** 🎉

**Created**: July 28, 2025  
**Status**: Active and Working 