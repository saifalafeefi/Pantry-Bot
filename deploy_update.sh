#!/bin/bash

# PantryBot Update Deployment Script
# Usage: ./deploy_update.sh <version>

set -e

VERSION=$1
SERVER_USER=${2:-smiley}
SERVER_DOMAIN=${3:-pantrybot.anonstorage.org}

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.4.2"
    exit 1
fi

echo "🚀 Starting deployment for version $VERSION..."

# Update version in pubspec.yaml
echo "📝 Updating pubspec.yaml version..."
cd pantrybot
sed -i "s/version: .*/version: $VERSION+$(date +%s)/" pubspec.yaml

# Update version in api.py
echo "📝 Updating api.py version..."
cd ..
sed -i "s/APP_VERSION = .*/APP_VERSION = \"$VERSION\"/" api.py

# Build the APK
echo "🔨 Building APK..."
cd pantrybot
flutter clean
flutter pub get
flutter build apk --release

# Copy APK to releases folder
echo "📦 Copying APK to releases folder..."
cd ..
cp pantrybot/build/app/outputs/flutter-apk/app-release.apk "releases/pantrybot_v$VERSION.apk"

# Deploy to server if requested
if [ -n "$DEPLOY_TO_SERVER" ]; then
    echo "🚁 Deploying to server $SERVER_USER@$SERVER_DOMAIN..."
    
    # Upload api.py to server
    scp api.py "$SERVER_USER@$SERVER_DOMAIN:/tmp/"
    
    # Move api.py and restart service
    ssh "$SERVER_USER@$SERVER_DOMAIN" "sudo cp /tmp/api.py /home/$SERVER_USER/pantrybot/ && sudo systemctl restart pantrybot-api"
    
    echo "✅ Deployed to server successfully!"
else
    echo "⚠️  Server deployment skipped. Set DEPLOY_TO_SERVER=1 to deploy automatically."
fi

echo "✅ Deployment complete!"
echo "📱 APK location: releases/pantrybot_v$VERSION.apk"
echo "🔗 Update URL: https://$SERVER_DOMAIN:8443/apk"
echo "📋 Version: $VERSION"

# Show QR code for easy sharing (if qrencode is installed)
if command -v qrencode &> /dev/null; then
    echo "📱 QR Code for APK download:"
    qrencode -t ANSI "https://$SERVER_DOMAIN:8443/apk"
fi

echo "🎉 Ready for OTA updates!" 