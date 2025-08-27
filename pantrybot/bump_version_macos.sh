#!/bin/bash

# Check if version numbers are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: ./bump_version.sh <version_name> <build_number>"
    echo "Example: ./bump_version.sh 1.0.1 2"
    exit 1
fi

VERSION_NAME=$1
BUILD_NUMBER=$2

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PUBSPEC_PATH="$SCRIPT_DIR/pubspec.yaml"

# Update version in pubspec.yaml
sed -i '' "s/^version: .*/version: $VERSION_NAME+$BUILD_NUMBER/" "$PUBSPEC_PATH"

# Clean and get packages
flutter clean
flutter pub get

echo "✅ Version successfully updated to $VERSION_NAME ($BUILD_NUMBER)"
echo "✅ You can now open Xcode and archive!"
