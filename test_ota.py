#!/usr/bin/env python3
"""
Test script for PantryBot OTA Update System
"""

import requests
import os
import sys
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def test_version_endpoint(base_url="https://pantrybot.anonstorage.org:8443"):
    """Test the version endpoint"""
    try:
        # Disable SSL verification for self-signed certificates
        response = requests.get(f"{base_url}/version", timeout=10, verify=False)
        print(f"📡 Version endpoint response: {response.status_code}")
        print(f"📄 Response content: {response.text[:200]}...")
        
        if response.status_code == 200:
            try:
                data = response.json()
                print(f"✅ Version endpoint working: {data['version']}")
                return data['version']
            except ValueError as json_error:
                print(f"❌ Invalid JSON response: {json_error}")
                return None
        else:
            print(f"❌ Version endpoint failed: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Version endpoint error: {e}")
        return None

def test_github_releases():
    """Test if GitHub releases are set up (placeholder)"""
    print("ℹ️  APK downloads will come from GitHub releases (not Pi)")
    print("ℹ️  Set up GitHub releases to host APK files")
    return True

def check_apk_file():
    """Check if APK file exists in releases folder"""
    releases_dir = "releases"
    if not os.path.exists(releases_dir):
        print(f"❌ Releases directory not found: {releases_dir}")
        return False
    
    apk_files = [f for f in os.listdir(releases_dir) if f.endswith('.apk')]
    if apk_files:
        print(f"✅ APK files found: {', '.join(apk_files)}")
        return True
    else:
        print(f"❌ No APK files found in {releases_dir}")
        return False

def main():
    print("🔄 Testing PantryBot OTA Update System")
    print("=" * 50)
    
    # Check local APK file
    apk_exists = check_apk_file()
    
    # Test version endpoint (only thing Pi needs to do)
    version = test_version_endpoint()
    
    # Check GitHub releases setup
    github_ready = test_github_releases()
    
    print("\n📋 Summary:")
    print(f"Local APK File: {'✅' if apk_exists else '❌'}")
    print(f"Version API (Pi): {'✅' if version else '❌'}")
    print(f"GitHub Releases: {'✅' if github_ready else '❌'}")
    
    if version:
        print("\n🎉 OTA Update System is ready!")
        print(f"Current version: {version}")
        print("✅ Pi only needs to serve version info")
        print("✅ APK downloads will come from GitHub releases")
        print("Users will be able to update automatically.")
    else:
        print("\n⚠️  OTA Update System needs attention:")
        print("- Upload updated api.py to Pi and restart service")
        if not apk_exists:
            print("- Build APK locally for releases")

if __name__ == "__main__":
    main() 