# 🌳 Git Branching Strategy

**Dual-branch setup**: Separate Flutter development from iOS builds.

## 📋 Branches

### `main` Branch
- ✅ Flutter app development
- ✅ General documentation
- ❌ No iOS build artifacts

### `ios-distribution` Branch  
- ✅ All main content (auto-synced)
- ✅ iOS build artifacts (.ipa, .xcarchive)
- ✅ iOS distribution workflows

## 🔄 Workflow

### Daily Development
```bash
# Work on Flutter app
git checkout main
# Make changes, commit, push

# Build iOS when ready
git checkout ios-distribution
./sync-from-main.sh
# Follow iOS build process
```

### Key Principle
**Develop on `main`, Build on `ios-distribution`**

## 🔄 Synchronization

The `sync-from-main.sh` script:
- Fetches latest from main
- Merges into ios-distribution
- Preserves iOS build artifacts
- Auto-commits with timestamp

**Run before every iOS build!**

## 📁 Structure

### Main Branch
```
main/
├── pantrybot/          # Flutter app
├── README.md           # General docs
└── README_*.md         # Documentation
```

### iOS Branch
```
ios-distribution/
├── pantrybot/          # Flutter app (synced)
├── ios-builds/         # Build artifacts
├── sync-from-main.sh   # Sync script
└── README_IOS_BRANCH.md
```

## ✅ Benefits

- **Clean separation**: Development vs builds
- **Auto-sync**: No manual merging needed
- **Organized**: Build artifacts isolated
- **GitHub friendly**: Clean main branch

## 🚀 Quick Commands

```bash
# Switch to iOS for building
git checkout ios-distribution && ./sync-from-main.sh

# Switch back to main for development
git checkout main

# See current branch
git branch
```

**Created**: July 2025 | **Status**: Active and Working 