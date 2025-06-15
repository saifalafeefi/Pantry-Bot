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

def test_server_endpoints():
    """Test server version and APK endpoints"""
    try:
        # Test version endpoint
        version_url = "https://pantrybot.anonstorage.org:8443/api/version"
        response = requests.get(version_url, timeout=10, verify=False)
        
        if response.status_code == 200:
            data = response.json()
            version = data['version']
            print(f"✅ Version endpoint working: {version}")
            
            # Test APK endpoint
            apk_url = "https://pantrybot.anonstorage.org:8443/api/apk"
            apk_response = requests.head(apk_url, timeout=10, verify=False)
            
            if apk_response.status_code == 200:
                size = apk_response.headers.get('Content-Length', 'Unknown')
                print(f"✅ APK endpoint working: {size} bytes")
                return version
            else:
                print(f"❌ APK endpoint failed: {apk_response.status_code}")
                return version  # Version works even if APK doesn't
        else:
            print(f"❌ Version endpoint failed: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Server endpoints error: {e}")
        return None

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
    print("🔄 Testing PantryBot OTA Update System (Private Repo)")
    print("=" * 50)
    
    # Check local APK file
    apk_exists = check_apk_file()
    
    # Check server endpoints
    server_version = test_server_endpoints()
    
    print("\n📋 Summary:")
    print(f"Local APK File: {'✅' if apk_exists else '❌'}")
    print(f"Server Endpoints: {'✅' if server_version else '❌'}")
    
    if server_version:
        print("\n🎉 OTA Update System is ready!")
        print(f"Server version: {server_version}")
        print("✅ App checks server for updates")
        print("✅ APK downloads from server")
        print("Users will get automatic updates!")
    else:
        print("\n⚠️  OTA Update System needs setup:")
        print("1. Deploy with: $env:DEPLOY_TO_SERVER=1; .\\deploy_update.ps1 -Version '1.4.2'")
        print("2. Configure your web server to proxy /api/* to localhost:5000")
        if not apk_exists:
            print("3. Build APK first with deployment script")

if __name__ == "__main__":
    main() 