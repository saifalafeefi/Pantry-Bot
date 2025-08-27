#!/bin/bash

# iOS Distribution Branch Sync Script
# Syncs Flutter app changes from main branch while preserving iOS build artifacts

set -e  # Exit on any error

echo "🔄 Syncing Flutter app changes from main branch..."

# Check if we're on ios-distribution branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "ios-distribution" ]; then
    echo "❌ Error: Must be on ios-distribution branch to sync"
    echo "Current branch: $CURRENT_BRANCH"
    exit 1
fi

# Save current iOS build artifacts
echo "📦 Backing up iOS build artifacts..."
if [ -d "ios-builds" ]; then
    cp -r ios-builds ios-builds-backup
    echo "✅ iOS builds backed up"
fi

# Fetch latest from origin
echo "🌐 Fetching latest changes from origin..."
git fetch origin

# Check if already up to date with main
MAIN_HEAD=$(git rev-parse origin/main)
if git merge-base --is-ancestor $MAIN_HEAD HEAD; then
    echo "✅ Already up to date with main branch!"
    exit 0
fi

# Squash merge changes from main branch
echo "🔀 Squash merging changes from main branch..."
git merge origin/main --squash

# Restore iOS build artifacts if they were overwritten
if [ -d "ios-builds-backup" ]; then
    echo "🔄 Restoring iOS build artifacts..."
    cp -r ios-builds-backup/* ios-builds/ 2>/dev/null || true
    rm -rf ios-builds-backup
    echo "✅ iOS builds restored"
fi

# Add any new iOS-specific changes
echo "📝 Staging iOS-specific changes..."
git add ios-builds/ .gitignore-ios sync-from-main.sh 2>/dev/null || true

# Commit the squashed changes
echo "💾 Committing squashed sync from main..."
git commit -m "Squashed commit: Sync from main branch - $(date '+%Y-%m-%d %H:%M:%S')

- Squash merged latest Flutter app changes from main
- Preserved iOS build artifacts and configuration  
- Maintained iOS distribution workflow"
echo "✅ Squashed sync completed"

echo ""
echo "🎉 iOS distribution branch successfully synced with main!"
echo "📱 Ready for iOS builds and Updraft distribution"
echo ""
echo "Next steps:"
echo "  1. Build iOS app: flutter build ios --release"
echo "  2. Archive in Xcode: Product → Archive"
echo "  3. Export IPA for Updraft"
echo "  4. Upload to Updraft dashboard" 